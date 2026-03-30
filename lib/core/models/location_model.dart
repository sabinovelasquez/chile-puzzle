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
      image: json['image'] as String,
      thumbnail: json['thumbnail'] as String,
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
}
