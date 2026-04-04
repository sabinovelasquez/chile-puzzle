import 'zone_model.dart';
import 'trophy_model.dart';
import 'scoring_config.dart';

class GameConfig {
  final List<ZoneModel> zones;
  final ScoringConfig scoring;
  final List<TrophyModel> trophies;

  const GameConfig({
    required this.zones,
    required this.scoring,
    required this.trophies,
  });

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      zones: (json['zones'] as List?)
              ?.map((z) => ZoneModel.fromJson(z))
              .toList() ??
          [],
      scoring: ScoringConfig.fromJson(json['scoring'] as Map<String, dynamic>? ?? {}),
      trophies: (json['trophies'] as List?)
              ?.map((t) => TrophyModel.fromJson(t))
              .toList() ??
          [],
    );
  }
}
