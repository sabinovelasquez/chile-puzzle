class ScoringConfig {
  final Map<int, int> basePoints;
  final int timeBonusThresholdSecs;
  final int timeBonusPoints;
  final int moveEfficiencyBonusPercent;

  const ScoringConfig({
    required this.basePoints,
    required this.timeBonusThresholdSecs,
    required this.timeBonusPoints,
    required this.moveEfficiencyBonusPercent,
  });

  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    final bp = json['basePoints'] as Map<String, dynamic>? ?? {};
    return ScoringConfig(
      basePoints: bp.map((k, v) => MapEntry(int.parse(k), v as int)),
      timeBonusThresholdSecs: json['timeBonusThresholdSecs'] as int? ?? 60,
      timeBonusPoints: json['timeBonusPoints'] as int? ?? 50,
      moveEfficiencyBonusPercent: json['moveEfficiencyBonusPercent'] as int? ?? 20,
    );
  }

  int calculate(int difficulty, int timeSecs, int moves, int totalPieces) {
    int points = basePoints[difficulty] ?? 50;
    int timeBonus = timeSecs < timeBonusThresholdSecs ? timeBonusPoints : 0;
    int efficiencyBonus = moves < (totalPieces * 1.5).ceil()
        ? (points * moveEfficiencyBonusPercent / 100).round()
        : 0;
    return points + timeBonus + efficiencyBonus;
  }
}
