import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';

class MockBackend {
  static String get _baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://127.0.0.1:3000';
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
