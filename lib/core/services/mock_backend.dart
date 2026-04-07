import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';

class MockBackend {
  static const _prodUrl = 'https://games.sabino.cl/zoominchile';
  static const _devServerIp = '192.168.0.17';

  static String get _baseUrl {
    // Always use production server (local dev server not running)
    return _prodUrl;
  }

  static Future<List<LocationModel>> fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/locations'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> rawData = decoded is List ? decoded : decoded['data'];
        return rawData.map((e) => LocationModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
    return [];
  }

  static Future<GameConfig> fetchGameConfig() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/config'));
      if (response.statusCode == 200) {
        return GameConfig.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching game config: $e');
    }
    return GameConfig.fromJson({});
  }
}
