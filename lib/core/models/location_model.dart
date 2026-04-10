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
  final List<int> difficultyLevels;
  final int requiredPoints;
  // Crop region for hardest difficulty (normalized 0-1). Easy shows full image.
  final double cropX;
  final double cropY;
  final double cropW;
  final double cropH;

  const LocationModel({
    required this.id,
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.image,
    required this.thumbnail,
    required this.tip,
    required this.difficultyLevels,
    this.requiredPoints = 0,
    this.cropX = 0.15,
    this.cropY = 0.15,
    this.cropW = 0.7,
    this.cropH = 0.7,
  });

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
    return LocationModel(
      id: json['id'] as String,
      name: Map<String, String>.from(json['name'] as Map),
      region: json['region'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      image: _fixUrl(json['image'] as String),
      thumbnail: _fixUrl(json['thumbnail'] as String),
      tip: Map<String, String>.from(json['tip'] as Map),
      difficultyLevels: List<int>.from(json['difficulty'] as List),
      requiredPoints: (json['requiredPoints'] as int?) ?? 0,
      cropX: (crop?['x'] as num?)?.toDouble() ?? 0.15,
      cropY: (crop?['y'] as num?)?.toDouble() ?? 0.15,
      cropW: (crop?['w'] as num?)?.toDouble() ?? 0.7,
      cropH: (crop?['h'] as num?)?.toDouble() ?? 0.7,
    );
  }

  String getLocalizedName(String langCode) {
    return name[langCode] ?? name['en'] ?? 'Unknown Location';
  }

  String getLocalizedTip(String langCode) {
    return tip[langCode] ?? tip['en'] ?? '';
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
