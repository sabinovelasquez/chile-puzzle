import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chile_puzzle/core/models/player_progress.dart';
import 'package:chile_puzzle/core/models/scoring_config.dart';
import 'package:chile_puzzle/core/models/trophy_model.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/core/services/settings_service.dart';

class CompletionResult {
  final int basePoints;
  final int timeBonus;
  final int efficiencyBonus;
  final int helpPenalty;
  final int totalPoints;
  final List<TrophyModel> newTrophies;
  final bool isNewBest;
  final int previousBest;
  final int difficulty;

  const CompletionResult({
    required this.basePoints,
    required this.timeBonus,
    required this.efficiencyBonus,
    required this.helpPenalty,
    required this.totalPoints,
    required this.newTrophies,
    required this.isNewBest,
    required this.previousBest,
    required this.difficulty,
  });
}

class GameProgressService {
  static const _key = 'player_progress';
  static late SharedPreferences _prefs;
  static late PlayerProgress _progress;

  static PlayerProgress get progress => _progress;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getString(_key);
    _progress = stored != null
        ? PlayerProgress.fromJsonString(stored)
        : PlayerProgress();
  }

  static Future<void> reset() async {
    _progress = PlayerProgress();
    await _save();
  }

  /// Replaces the current progress with the given JSON payload (from a
  /// server-side backup). Throws FormatException on invalid JSON.
  static Future<void> replaceProgressFromJson(Map<String, dynamic> json) async {
    _progress = PlayerProgress.fromJson(json);
    await _save();
  }

  /// Current progress as a JSON map, ready for `createBackup`.
  static Map<String, dynamic> progressAsJson() => _progress.toJson();

  static Future<void> _save() async {
    await _prefs.setString(_key, _progress.toJsonString());
  }

  static Future<CompletionResult> recordCompletion({
    required String locationId,
    required int difficulty,
    required int timeSecs,
    required int moves,
    required int totalPieces,
    required ScoringConfig scoring,
    required List<TrophyModel> allTrophies,
    required List<LocationModel> allLocations,
    bool lockInPlace = false,
    bool multiSelect = false,
    bool referenceEnabled = false,
  }) async {
    final base = scoring.basePoints[difficulty] ?? 50;
    final timeBonus = timeSecs < scoring.timeBonusThresholdSecs ? scoring.timeBonusPoints : 0;
    final efficiencyBonus = moves < (totalPieces * 1.5).ceil()
        ? (base * scoring.moveEfficiencyBonusPercent / 100).round()
        : 0;

    int helpPenalty = 0;
    // Reference photo is the most "OP" hint — seeing the target while playing
    // is a much bigger advantage than locking or group-drag, so it's costliest.
    if (referenceEnabled) helpPenalty += 25;
    if (lockInPlace) helpPenalty += 15;
    if (multiSelect) helpPenalty += 20;
    final total = (base + timeBonus + efficiencyBonus - helpPenalty).clamp(0, 999999);

    final key = '${locationId}_$difficulty';
    final existing = _progress.completedPuzzles[key];
    final previousBest = existing?.points ?? 0;
    final isFirstCompletion = existing == null;
    final isNewBest = !isFirstCompletion && total > previousBest;

    if (helpPenalty == 0 && isFirstCompletion) {
      _progress.noHelpCompleted++;
    }

    if (isFirstCompletion || total > previousBest) {
      _progress.completedPuzzles[key] = PuzzleResult(
        locationId: locationId,
        difficulty: difficulty,
        points: total,
        timeSecs: timeSecs,
        moves: moves,
        completedAt: DateTime.now(),
      );
    }

    // Delta-only accumulation: first completion adds `total`, replays only add
    // (total - previousBest) when improving. Prevents score inflation on replay.
    final delta = isFirstCompletion ? total : (total - previousBest).clamp(0, 999999);
    _progress.totalPoints += delta;

    final newTrophies = checkNewTrophies(allTrophies, allLocations);

    await _save();

    // Silent auto-submit to global leaderboard — only if the player has
    // stored initials AND explicitly opted in via Settings. Fire-and-forget:
    // never block UI on this, never surface errors.
    final initials = _prefs.getString(_initialsKey);
    if (initials != null &&
        initials.length == 3 &&
        SettingsService.autoSubmitRanking) {
      unawaited(MockBackend.submitScore(
        initials: initials,
        totalPoints: _progress.totalPoints,
        puzzlesCompleted: _progress.completedCount,
        timeSeconds: timeSecs,
        moves: moves,
      ));
    }

    return CompletionResult(
      basePoints: base,
      timeBonus: timeBonus,
      efficiencyBonus: efficiencyBonus,
      helpPenalty: helpPenalty,
      totalPoints: total,
      newTrophies: newTrophies,
      isNewBest: isNewBest,
      previousBest: previousBest,
      difficulty: difficulty,
    );
  }

  static int? getBestPoints(String locationId, int difficulty) {
    return _progress.completedPuzzles['${locationId}_$difficulty']?.points;
  }

  static List<TrophyModel> checkNewTrophies(
    List<TrophyModel> allTrophies,
    List<LocationModel> allLocations,
  ) {
    final newlyEarned = <TrophyModel>[];

    for (final trophy in allTrophies) {
      if (_progress.earnedTrophyIds.contains(trophy.id)) continue;

      bool earned = false;
      final cond = trophy.condition;
      final metric = cond['metric'] as String?;

      switch (metric) {
        case 'totalCompleted':
          earned = _progress.completedCount >= (cond['threshold'] as int);
          break;
        case 'totalPoints':
          earned = _progress.totalPoints >= (cond['threshold'] as int);
          break;
        case 'fastestTime':
          final fastest = _progress.fastestTime;
          earned = fastest != null && fastest <= (cond['threshold'] as int);
          break;
        case 'zoneAllCompleted':
          final zoneId = cond['zoneId'] as String;
          final zoneLocIds = allLocations
              .where((l) => l.region == zoneId)
              .map((l) => l.id)
              .toSet();
          if (zoneLocIds.isNotEmpty) {
            earned = zoneLocIds.every((id) => _progress.isLocationCompleted(id));
          }
          break;
        case 'noHelpCompleted':
          earned = _progress.noHelpCompleted >= (cond['threshold'] as int);
          break;
      }

      if (earned) {
        _progress.earnedTrophyIds.add(trophy.id);
        newlyEarned.add(trophy);
      }
    }

    return newlyEarned;
  }

  static bool isLocationUnlocked(LocationModel loc) {
    return _progress.totalPoints >= loc.requiredPoints;
  }

  static int getPointsToUnlock(LocationModel loc) {
    return (loc.requiredPoints - _progress.totalPoints).clamp(0, 999999);
  }

  static int get totalPoints => _progress.totalPoints;
  static int get completedCount => _progress.completedCount;

  // --- Favorites ---
  static bool isFavorite(String locationId) =>
      _progress.favoriteLocationIds.contains(locationId);

  static Future<void> toggleFavorite(String locationId) async {
    if (_progress.favoriteLocationIds.contains(locationId)) {
      _progress.favoriteLocationIds.remove(locationId);
    } else {
      _progress.favoriteLocationIds.add(locationId);
    }
    await _save();
  }

  static List<String> get favoriteLocationIds => _progress.favoriteLocationIds;

  // --- Leaderboard initials (separate from progress, survives reset) ---
  static const _initialsKey = 'leaderboard_initials';

  static String? get leaderboardInitials => _prefs.getString(_initialsKey);

  static Future<void> setLeaderboardInitials(String initials) async {
    await _prefs.setString(_initialsKey, initials);
  }
}
