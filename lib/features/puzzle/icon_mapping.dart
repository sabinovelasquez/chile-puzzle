import 'package:flutter/material.dart';

const _iconMap = <String, IconData>{
  'emoji_events': Icons.emoji_events,
  'star': Icons.star,
  'bolt': Icons.bolt,
  'military_tech': Icons.military_tech,
  'workspace_premium': Icons.workspace_premium,
  'landscape': Icons.landscape,
  'location_city': Icons.location_city,
  'public': Icons.public,
  'explore': Icons.explore,
  'terrain': Icons.terrain,
  'park': Icons.park,
  'water': Icons.water,
  'diamond': Icons.diamond,
  'local_fire_department': Icons.local_fire_department,
  'timer': Icons.timer,
  'speed': Icons.speed,
  'verified': Icons.verified,
  'shield': Icons.shield,
  'favorite': Icons.favorite,
  'flag': Icons.flag,
};

IconData mapIcon(String name) => _iconMap[name] ?? Icons.star;
