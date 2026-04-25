import 'zone_model.dart';
import 'trophy_model.dart';
import 'scoring_config.dart';

/// Admin-configurable text + link the app embeds in [Share.shareXFiles].
/// Defaults preserve the prior hardcoded copy so older admin builds (or
/// offline cache misses) keep working.
class ShareConfig {
  final String textEn;
  final String textEs;
  final String link;

  const ShareConfig({
    required this.textEn,
    required this.textEs,
    required this.link,
  });

  static const ShareConfig fallback = ShareConfig(
    textEn: '{name} — Zoom-In Chile 🧩 Discover it at {link}',
    textEs: '{name} — Zoom-In Chile 🧩 Descúbrelo en {link}',
    link: 'https://play.google.com/store/apps/details?id=cl.depointless.zoominchile',
  );

  factory ShareConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;
    String pick(String key, String fb) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v;
      return fb;
    }
    return ShareConfig(
      textEn: pick('shareTextEn', fallback.textEn),
      textEs: pick('shareTextEs', fallback.textEs),
      link: pick('shareLink', fallback.link),
    );
  }

  String textForLocale(String langCode) => langCode == 'es' ? textEs : textEn;
}

class GameConfig {
  final List<ZoneModel> zones;
  final ScoringConfig scoring;
  final List<TrophyModel> trophies;
  final ShareConfig share;

  const GameConfig({
    required this.zones,
    required this.scoring,
    required this.trophies,
    this.share = ShareConfig.fallback,
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
      share: ShareConfig.fromJson(json['appConfig'] as Map<String, dynamic>?),
    );
  }
}
