import 'dart:convert';

class PuzzleResult {
  final String locationId;
  final int difficulty;
  final int points;
  final int timeSecs;
  final int moves;
  final DateTime completedAt;
  // Flags that gate the "new unlockable" pulsing dot in the completion drawer.
  // Default false on existing saves so prior puzzles still show the badge
  // until the user interacts with each action.
  final bool hasShared;
  final bool photoViewed;
  final bool mapsOpened;

  const PuzzleResult({
    required this.locationId,
    required this.difficulty,
    required this.points,
    required this.timeSecs,
    required this.moves,
    required this.completedAt,
    this.hasShared = false,
    this.photoViewed = false,
    this.mapsOpened = false,
  });

  PuzzleResult copyWith({
    bool? hasShared,
    bool? photoViewed,
    bool? mapsOpened,
  }) =>
      PuzzleResult(
        locationId: locationId,
        difficulty: difficulty,
        points: points,
        timeSecs: timeSecs,
        moves: moves,
        completedAt: completedAt,
        hasShared: hasShared ?? this.hasShared,
        photoViewed: photoViewed ?? this.photoViewed,
        mapsOpened: mapsOpened ?? this.mapsOpened,
      );

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'difficulty': difficulty,
        'points': points,
        'timeSecs': timeSecs,
        'moves': moves,
        'completedAt': completedAt.toIso8601String(),
        'hasShared': hasShared,
        'photoViewed': photoViewed,
        'mapsOpened': mapsOpened,
      };

  factory PuzzleResult.fromJson(Map<String, dynamic> json) => PuzzleResult(
        locationId: json['locationId'] as String,
        difficulty: json['difficulty'] as int,
        points: json['points'] as int,
        timeSecs: json['timeSecs'] as int,
        moves: json['moves'] as int,
        completedAt: DateTime.parse(json['completedAt'] as String),
        hasShared: json['hasShared'] as bool? ?? false,
        photoViewed: json['photoViewed'] as bool? ?? false,
        mapsOpened: json['mapsOpened'] as bool? ?? false,
      );
}

class PlayerProgress {
  int totalPoints;
  Map<String, PuzzleResult> completedPuzzles; // key: "locationId_difficulty"
  List<String> earnedTrophyIds;
  List<String> favoriteLocationIds;
  int noHelpCompleted;
  /// Locations the player has already claimed the +50pts share reward for.
  /// One-shot per location — once it's in here, the reward is closed.
  Set<String> sharedLocationIds;

  PlayerProgress({
    this.totalPoints = 0,
    Map<String, PuzzleResult>? completedPuzzles,
    List<String>? earnedTrophyIds,
    List<String>? favoriteLocationIds,
    this.noHelpCompleted = 0,
    Set<String>? sharedLocationIds,
  })  : completedPuzzles = completedPuzzles ?? {},
        earnedTrophyIds = earnedTrophyIds ?? [],
        favoriteLocationIds = favoriteLocationIds ?? [],
        sharedLocationIds = sharedLocationIds ?? <String>{};

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'completedPuzzles': completedPuzzles.map((k, v) => MapEntry(k, v.toJson())),
        'earnedTrophyIds': earnedTrophyIds,
        'favoriteLocationIds': favoriteLocationIds,
        'noHelpCompleted': noHelpCompleted,
        'sharedLocationIds': sharedLocationIds.toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory PlayerProgress.fromJson(Map<String, dynamic> map) {
    final puzzles = (map['completedPuzzles'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, PuzzleResult.fromJson(v as Map<String, dynamic>)),
        ) ??
        {};
    // Migrate legacy per-puzzle hasShared flags into the new per-location
    // set. Closed-testing builds wrote hasShared on PuzzleResult; the new
    // model tracks one-shot rewards by locationId, so fold any true flag
    // into sharedLocationIds.
    final shared = <String>{
      ...List<String>.from(map['sharedLocationIds'] ?? const <String>[]),
    };
    for (final r in puzzles.values) {
      if (r.hasShared) shared.add(r.locationId);
    }
    return PlayerProgress(
      totalPoints: map['totalPoints'] as int? ?? 0,
      completedPuzzles: puzzles,
      earnedTrophyIds: List<String>.from(map['earnedTrophyIds'] ?? []),
      favoriteLocationIds: List<String>.from(map['favoriteLocationIds'] ?? []),
      noHelpCompleted: map['noHelpCompleted'] as int? ?? 0,
      sharedLocationIds: shared,
    );
  }

  factory PlayerProgress.fromJsonString(String jsonStr) =>
      PlayerProgress.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  int get completedCount => completedPuzzles.length;

  int? get fastestTime {
    if (completedPuzzles.isEmpty) return null;
    return completedPuzzles.values
        .map((r) => r.timeSecs)
        .reduce((a, b) => a < b ? a : b);
  }

  bool isLocationCompleted(String locationId) =>
      completedPuzzles.keys.any((k) => k.startsWith('${locationId}_'));

  Set<String> completedLocationIds() =>
      completedPuzzles.values.map((r) => r.locationId).toSet();
}
