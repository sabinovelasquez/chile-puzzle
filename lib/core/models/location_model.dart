import 'dart:io';

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
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
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
    );
  }

  String getLocalizedName(String langCode) {
    return name[langCode] ?? name['en'] ?? 'Unknown Location';
  }

  String getLocalizedTip(String langCode) {
    return tip[langCode] ?? tip['en'] ?? '';
  }

  static String _fixUrl(String url) {
    if (url.startsWith('/uploads/')) {
       final base = Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://127.0.0.1:3000';
       return '$base$url';
    }
    return url;
  }
}
