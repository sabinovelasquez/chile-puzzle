import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';

class PaginatedLocations {
  final List<LocationModel> data;
  final int total;
  final int page;
  final int pageSize;

  const PaginatedLocations({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => (page + 1) * pageSize < total;
}

class MockBackend {
  static const _prodUrl = 'https://games.sabino.cl/zoominchile';
  static const _devServerIp = '192.168.0.17';

  static String get _baseUrl {
    // Always use production server (local dev server not running)
    return _prodUrl;
  }

  /// Fetch all locations (legacy — used by puzzle screen, profile)
  static Future<List<LocationModel>> fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/locations'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Support both paginated {data:[...]} and legacy array responses
        final List<dynamic> rawData = decoded is List ? decoded : (decoded['data'] ?? []);
        return rawData.map((e) => LocationModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
    return [];
  }

  /// Fetch locations with pagination and filters
  static Future<PaginatedLocations> fetchLocationsPaginated({
    int page = 0,
    int limit = 20,
    String? zone,
    String? query,
    bool? isNew,
    List<String>? ids,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (zone != null && zone.isNotEmpty) params['zone'] = zone;
      if (query != null && query.isNotEmpty) params['q'] = query;
      if (isNew == true) params['new'] = '1';
      if (ids != null && ids.isNotEmpty) params['ids'] = ids.join(',');

      final uri = Uri.parse('$_baseUrl/api/locations').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> rawData = decoded['data'] ?? [];
        return PaginatedLocations(
          data: rawData.map((e) => LocationModel.fromJson(e)).toList(),
          total: decoded['total'] ?? 0,
          page: decoded['page'] ?? page,
          pageSize: decoded['pageSize'] ?? limit,
        );
      }
    } catch (e) {
      debugPrint('Error fetching paginated locations: $e');
    }
    return PaginatedLocations(data: [], total: 0, page: page, pageSize: limit);
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

  /// Submit score to leaderboard
  static Future<Map<String, dynamic>?> submitScore({
    required String initials,
    required int totalPoints,
    required int puzzlesCompleted,
    int timeSeconds = 0,
    int moves = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/leaderboard'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'initials': initials,
          'totalPoints': totalPoints,
          'puzzlesCompleted': puzzlesCompleted,
          'timeSeconds': timeSeconds,
          'moves': moves,
        }),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode == 200) {
        return decoded;
      }
      // Return error info for banned initials etc.
      return {'error': decoded['error'] ?? 'Unknown error'};
    } catch (e) {
      debugPrint('Error submitting score: $e');
    }
    return null;
  }

  /// Fetch leaderboard entries
  static Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/leaderboard?limit=$limit'),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return List<Map<String, dynamic>>.from(decoded['entries'] ?? []);
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
    return [];
  }

  /// Fetch top 25 per-location leaderboard entries plus the qualifying score
  /// (the 25th-place points, or 0 if fewer than 25 entries exist).
  static Future<({List<Map<String, dynamic>> entries, int qualifyingScore})>
      fetchLocationLeaderboard(String locationId, int difficulty) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/leaderboard').replace(
        queryParameters: {
          'locationId': locationId,
          'difficulty': '$difficulty',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return (
          entries: List<Map<String, dynamic>>.from(decoded['entries'] ?? []),
          qualifyingScore: (decoded['qualifyingScore'] as int?) ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Error fetching location leaderboard: $e');
    }
    return (entries: const <Map<String, dynamic>>[], qualifyingScore: 0);
  }

  // --- Progress backup / restore (Nintendo-style short code) ---

  /// Uploads the given progress JSON and returns `(code, expiresAt)` on
  /// success, or null on any failure.
  static Future<({String code, String expiresAt})?> createProgressBackup(
    Map<String, dynamic> progressJson,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/progress/backup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'progress': progressJson}),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return (
          code: decoded['code'] as String,
          expiresAt: decoded['expiresAt'] as String,
        );
      }
      debugPrint('createProgressBackup failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error creating progress backup: $e');
    }
    return null;
  }

  /// Fetches a backup by code. Returns the raw progress JSON map, or null if
  /// not found / expired / network error.
  static Future<Map<String, dynamic>?> fetchProgressBackup(String code) async {
    try {
      final normalized = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final response = await http.get(
        Uri.parse('$_baseUrl/api/progress/restore/$normalized'),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['progress'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching progress backup: $e');
    }
    return null;
  }

  /// Emails a previously-created backup code to the given address.
  /// Returns true on success.
  static Future<bool> emailProgressBackup({
    required String code,
    required String email,
    required String lang,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/progress/backup/email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': code, 'email': email, 'lang': lang}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error emailing backup code: $e');
    }
    return false;
  }

  /// Submit a per-location result. Returns {rank} or {error} on failure.
  static Future<Map<String, dynamic>?> submitLocationScore({
    required String initials,
    required String locationId,
    required int difficulty,
    required int points,
    int timeSeconds = 0,
    int moves = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/leaderboard'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'initials': initials,
          'locationId': locationId,
          'difficulty': difficulty,
          'points': points,
          'timeSeconds': timeSeconds,
          'moves': moves,
        }),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode == 200) return decoded;
      return {'error': decoded['error'] ?? 'Unknown error'};
    } catch (e) {
      debugPrint('Error submitting location score: $e');
    }
    return null;
  }
}
