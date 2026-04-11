import 'package:flutter/foundation.dart';

class LocationModel {
  final String id;
  final Map<String, String> name;
  final String region;
  final double latitude;
  final double longitude;
  final String image;
  final String thumbnail;
  final Map<String, String> tip;
  /// Optional per-difficulty tip overrides. Keyed by difficulty (4/5/6).
  /// When an override is missing or empty, callers should fall back to [tip].
  final Map<int, Map<String, String>> tipsByDifficulty;
  /// Optional per-difficulty pre-rendered image URLs, keyed by difficulty (3/4/5/6).
  /// When present, the image IS the crop — callers should skip [getCropForDifficulty]
  /// math and render the whole image directly. Empty for legacy locations.
  final Map<int, String> imagesByDifficulty;
  final List<int> difficultyLevels;
  final int requiredPoints;
  // Crop region for hardest difficulty (normalized 0-1). Easy shows full image.
  final double cropX;
  final double cropY;
  final double cropW;
  final double cropH;
  /// Per-difficulty flags for whether the girl_cat silhouette is overlaid on
  /// the completed-puzzle photo view and inside the completion drawer's tip
  /// card. Keyed by difficulty (3/4/5/6). Admin-controlled.
  final Map<int, bool> silhouetteByDifficulty;

  const LocationModel({
    required this.id,
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.image,
    required this.thumbnail,
    required this.tip,
    this.tipsByDifficulty = const {},
    this.imagesByDifficulty = const {},
    required this.difficultyLevels,
    this.requiredPoints = 0,
    this.cropX = 0.15,
    this.cropY = 0.15,
    this.cropW = 0.7,
    this.cropH = 0.7,
    this.silhouetteByDifficulty = const {},
  });

  /// Whether the girl_cat silhouette should appear for [difficulty].
  bool showsSilhouetteAt(int difficulty) =>
      silhouetteByDifficulty[difficulty] == true;

  /// Returns the best image URL for [difficulty]:
  /// the pre-rendered per-difficulty crop when the backend provided one,
  /// otherwise the single [image] (legacy path).
  String getImageForDifficulty(int difficulty) {
    return imagesByDifficulty[difficulty] ?? image;
  }

  /// True when [getImageForDifficulty] returns a pre-cropped image, so callers
  /// should render it as-is without applying [getCropForDifficulty] math.
  bool hasPreRenderedCrop(int difficulty) =>
      imagesByDifficulty.containsKey(difficulty);

  /// Returns the crop rect for a given difficulty, interpolated between
  /// full image (easiest) and the admin-defined focus crop (hardest).
  List<double> getCropForDifficulty(int difficulty) {
    if (difficultyLevels.length <= 1) return [0, 0, 1, 1];
    final sorted = List<int>.from(difficultyLevels)..sort();
    final minD = sorted.first;
    final maxD = sorted.last;
    if (minD == maxD) return [0, 0, 1, 1];
    // t=0 for easiest (full image), t=1 for hardest (tight crop)
    final t = (difficulty - minD) / (maxD - minD);
    return [
      cropX * t,
      cropY * t,
      1 - (1 - cropW) * t,
      1 - (1 - cropH) * t,
    ];
  }

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    final crop = json['crop'] as Map<String, dynamic>?;
    final rawTips = json['tipsByDifficulty'] as Map?;
    final parsedTips = <int, Map<String, String>>{};
    if (rawTips != null) {
      rawTips.forEach((k, v) {
        final diff = int.tryParse(k.toString());
        if (diff != null && v is Map) {
          parsedTips[diff] = Map<String, String>.from(v);
        }
      });
    }
    final rawImages = json['imagesByDifficulty'] as Map?;
    final parsedImages = <int, String>{};
    if (rawImages != null) {
      rawImages.forEach((k, v) {
        final diff = int.tryParse(k.toString());
        if (diff != null && v is String && v.isNotEmpty) {
          parsedImages[diff] = _fixUrl(v);
        }
      });
    }
    final rawSil = json['silhouetteByDifficulty'] as Map?;
    final parsedSil = <int, bool>{};
    if (rawSil != null) {
      rawSil.forEach((k, v) {
        final diff = int.tryParse(k.toString());
        if (diff != null && v is bool) parsedSil[diff] = v;
      });
    }
    return LocationModel(
      id: json['id'] as String,
      name: Map<String, String>.from(json['name'] as Map),
      region: json['region'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      image: _fixUrl(json['image'] as String),
      thumbnail: _fixUrl(json['thumbnail'] as String),
      tip: Map<String, String>.from(json['tip'] as Map),
      tipsByDifficulty: parsedTips,
      imagesByDifficulty: parsedImages,
      difficultyLevels: List<int>.from(json['difficulty'] as List),
      requiredPoints: (json['requiredPoints'] as int?) ?? 0,
      cropX: (crop?['x'] as num?)?.toDouble() ?? 0.15,
      cropY: (crop?['y'] as num?)?.toDouble() ?? 0.15,
      cropW: (crop?['w'] as num?)?.toDouble() ?? 0.7,
      cropH: (crop?['h'] as num?)?.toDouble() ?? 0.7,
      silhouetteByDifficulty: parsedSil,
    );
  }

  String getLocalizedName(String langCode) {
    return name[langCode] ?? name['en'] ?? 'Unknown Location';
  }

  String getLocalizedTip(String langCode) {
    return tip[langCode] ?? tip['en'] ?? '';
  }

  /// Returns the tip for a specific difficulty, falling back to the base tip
  /// when no per-difficulty override is set.
  String getLocalizedTipForDifficulty(String langCode, int difficulty) {
    final override = tipsByDifficulty[difficulty];
    if (override != null) {
      final text = override[langCode] ?? override['en'];
      if (text != null && text.isNotEmpty) return text;
    }
    return getLocalizedTip(langCode);
  }

  static const _prodUrl = 'https://games.sabino.cl/zoominchile';
  static const _devServerIp = '192.168.0.17';

  static String _fixUrl(String url) {
    if (url.startsWith('/zoominchile/uploads/')) {
      return 'https://games.sabino.cl$url';
    }
    if (url.startsWith('/uploads/')) {
      final String base;
      if (!kDebugMode) {
        base = _prodUrl;
      } else if (kIsWeb) {
        base = 'http://127.0.0.1:3000';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        base = 'http://$_devServerIp:3000';
      } else {
        base = 'http://127.0.0.1:3000';
      }
      return '$base$url';
    }
    return url;
  }
}
