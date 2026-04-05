class ZoneModel {
  final String id;
  final Map<String, String> name;
  final int order;
  final String icon;

  const ZoneModel({
    required this.id,
    required this.name,
    required this.order,
    required this.icon,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] as String,
      name: Map<String, String>.from(json['name'] as Map),
      order: json['order'] as int,
      icon: json['icon'] as String? ?? 'landscape',
    );
  }

  String getLocalizedName(String langCode) =>
      name[langCode] ?? name['en'] ?? id;
}
