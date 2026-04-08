import 'package:shared_preferences/shared_preferences.dart';
import 'package:chile_puzzle/core/models/player_progress.dart';
import 'package:chile_puzzle/core/models/scoring_config.dart';
import 'package:chile_puzzle/core/models/trophy_model.dart';
import 'package:chile_puzzle/core/models/location_model.dart';

class CompletionResult {
  final int basePoints;
  final int timeBonus;
  final int efficiencyBonus;
  final int totalPoints;
  final List<TrophyModel> newTrophies;

  const CompletionResult({
    required this.basePoints,
    required this.timeBonus,
    required this.efficiencyBonus,
    required this.totalPoints,
    required this.newTrophies,
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
  }) async {
    final base = scoring.basePoints[difficulty] ?? 50;
    final timeBonus = timeSecs < scoring.timeBonusThresholdSecs ? scoring.timeBonusPoints : 0;
    final efficiencyBonus = moves < (totalPieces * 1.5).ceil()
        ? (base * scoring.moveEfficiencyBonusPercent / 100).round()
        : 0;
    final total = base + timeBonus + efficiencyBonus;

    final key = '${locationId}_$difficulty';
    _progress.completedPuzzles[key] = PuzzleResult(
      locationId: locationId,
      difficulty: difficulty,
      points: total,
      timeSecs: timeSecs,
      moves: moves,
      completedAt: DateTime.now(),
    );
    _progress.totalPoints += total;

    final newTrophies = checkNewTrophies(allTrophies, allLocations);

    await _save();

    return CompletionResult(
      basePoints: base,
      timeBonus: timeBonus,
      efficiencyBonus: efficiencyBonus,
      totalPoints: total,
      newTrophies: newTrophies,
    );
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
