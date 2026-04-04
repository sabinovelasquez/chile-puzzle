class TrophyModel {
  final String id;
  final Map<String, String> name;
  final Map<String, String> description;
  final String icon;
  final String type;
  final Map<String, dynamic> condition;

  const TrophyModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.condition,
  });

  factory TrophyModel.fromJson(Map<String, dynamic> json) {
    return TrophyModel(
      id: json['id'] as String,
      name: Map<String, String>.from(json['name'] as Map),
      description: Map<String, String>.from(json['description'] as Map),
      icon: json['icon'] as String? ?? 'emoji_events',
      type: json['type'] as String? ?? 'milestone',
      condition: Map<String, dynamic>.from(json['condition'] as Map),
    );
  }

  String getLocalizedName(String langCode) =>
      name[langCode] ?? name['en'] ?? id;

  String getLocalizedDescription(String langCode) =>
      description[langCode] ?? description['en'] ?? '';
}
