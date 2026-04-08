import 'dart:convert';

class PuzzleResult {
  final String locationId;
  final int difficulty;
  final int points;
  final int timeSecs;
  final int moves;
  final DateTime completedAt;

  const PuzzleResult({
    required this.locationId,
    required this.difficulty,
    required this.points,
    required this.timeSecs,
    required this.moves,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'difficulty': difficulty,
        'points': points,
        'timeSecs': timeSecs,
        'moves': moves,
        'completedAt': completedAt.toIso8601String(),
      };

  factory PuzzleResult.fromJson(Map<String, dynamic> json) => PuzzleResult(
        locationId: json['locationId'] as String,
        difficulty: json['difficulty'] as int,
        points: json['points'] as int,
        timeSecs: json['timeSecs'] as int,
        moves: json['moves'] as int,
        completedAt: DateTime.parse(json['completedAt'] as String),
      );
}

class PlayerProgress {
  int totalPoints;
  Map<String, PuzzleResult> completedPuzzles; // key: "locationId_difficulty"
  List<String> earnedTrophyIds;
  List<String> favoriteLocationIds;

  PlayerProgress({
    this.totalPoints = 0,
    Map<String, PuzzleResult>? completedPuzzles,
    List<String>? earnedTrophyIds,
    List<String>? favoriteLocationIds,
  })  : completedPuzzles = completedPuzzles ?? {},
        earnedTrophyIds = earnedTrophyIds ?? [],
        favoriteLocationIds = favoriteLocationIds ?? [];

  String toJsonString() => jsonEncode({
        'totalPoints': totalPoints,
        'completedPuzzles': completedPuzzles.map((k, v) => MapEntry(k, v.toJson())),
        'earnedTrophyIds': earnedTrophyIds,
        'favoriteLocationIds': favoriteLocationIds,
      });

  factory PlayerProgress.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final puzzles = (map['completedPuzzles'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, PuzzleResult.fromJson(v)),
        ) ??
        {};
    return PlayerProgress(
      totalPoints: map['totalPoints'] as int? ?? 0,
      completedPuzzles: puzzles,
      earnedTrophyIds: List<String>.from(map['earnedTrophyIds'] ?? []),
      favoriteLocationIds: List<String>.from(map['favoriteLocationIds'] ?? []),
    );
  }

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
