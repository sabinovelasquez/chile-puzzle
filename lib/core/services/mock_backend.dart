import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chile_puzzle/core/models/location_model.dart';

class MockBackend {
  static Future<List<LocationModel>> fetchLocations() async {
    try {
      String baseUrl = 'http://127.0.0.1:3000';
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        baseUrl = 'http://10.0.2.2:3000';
      }
      
      final response = await http.get(Uri.parse('$baseUrl/api/locations'));
      
      if (response.statusCode == 200) {
         final decoded = json.decode(response.body);
         // Support both format permutations {data: []} or raw Array
         final List<dynamic> rawData = decoded is List ? decoded : decoded['data'];
         return rawData.map((e) => LocationModel.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error fetching from admin server: $e');
    }
    
    // Return empty fallback instead of crash
    return [];
  }
}
