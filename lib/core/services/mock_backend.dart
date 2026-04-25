import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';

class MockBackend {
  static const _prodUrl = 'https://games.sabino.cl/zoominchile';
  static const _devServerIp = '192.168.0.17';

  static const _kCachedLocations = 'cached_locations_v1';
  static const _kCachedConfig = 'cached_config_v1';
  static const _kCachedAt = 'cached_content_at';

  /// True when the most recent fetchLocations/fetchGameConfig call fell back
  /// to the local cache because the network was unreachable. Callers render
  /// an offline banner off this. Reset to false on any successful fetch.
  static bool lastFetchWasOffline = false;

  /// True when the most recent leaderboard fetch (`fetchLeaderboard` /
  /// `fetchLocationLeaderboard`) failed due to network error. Callers use
  /// this to differentiate "no scores yet" from "couldn't load".
  static bool lastLeaderboardWasOffline = false;

  /// ISO-8601 timestamp of the most recent successful sync, or null if we
  /// have never synced on this install.
  static DateTime? lastSyncedAt;

  static String get _baseUrl {
    // Always use production server (local dev server not running)
    return _prodUrl;
  }

  /// Fetch every location in one call. The grid loads them all and filters
  /// client-side, which keeps the order stable as the user scrolls.
  ///
  /// On success: writes the raw JSON to SharedPreferences for offline reuse.
  /// On failure: returns the last cached list if available; else an empty list.
  /// Sets [lastFetchWasOffline] accordingly.
  static Future<List<LocationModel>> fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/locations'));
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachedLocations, response.body);
        await prefs.setString(_kCachedAt, DateTime.now().toIso8601String());
        lastFetchWasOffline = false;
        lastSyncedAt = DateTime.now();
        final decoded = json.decode(response.body);
        final List<dynamic> rawData = decoded is List ? decoded : (decoded['data'] ?? []);
        return rawData.map((e) => LocationModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
    // Network failed — try cache.
    return _loadCachedLocations();
  }

  static Future<GameConfig> fetchGameConfig() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/config'));
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachedConfig, response.body);
        lastFetchWasOffline = false;
        return GameConfig.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching game config: $e');
    }
    // Network failed — try cache.
    return _loadCachedConfig();
  }

  static Future<List<LocationModel>> _loadCachedLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = prefs.getString(_kCachedLocations);
      final ts = prefs.getString(_kCachedAt);
      if (body == null) {
        lastFetchWasOffline = true;
        return const [];
      }
      final decoded = json.decode(body);
      final List<dynamic> rawData = decoded is List ? decoded : (decoded['data'] ?? []);
      lastFetchWasOffline = true;
      lastSyncedAt = ts != null ? DateTime.tryParse(ts) : null;
      return rawData.map((e) => LocationModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Corrupt cached locations, purging: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedLocations);
      lastFetchWasOffline = true;
      return const [];
    }
  }

  static Future<GameConfig> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = prefs.getString(_kCachedConfig);
      if (body == null) {
        lastFetchWasOffline = true;
        return GameConfig.fromJson({});
      }
      lastFetchWasOffline = true;
      return GameConfig.fromJson(json.decode(body));
    } catch (e) {
      debugPrint('Corrupt cached config, purging: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedConfig);
      lastFetchWasOffline = true;
      return GameConfig.fromJson({});
    }
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
        lastLeaderboardWasOffline = false;
        final decoded = json.decode(response.body);
        return List<Map<String, dynamic>>.from(decoded['entries'] ?? []);
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      lastLeaderboardWasOffline = true;
      return [];
    }
    lastLeaderboardWasOffline = false;
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
        lastLeaderboardWasOffline = false;
        final decoded = json.decode(response.body);
        return (
          entries: List<Map<String, dynamic>>.from(decoded['entries'] ?? []),
          qualifyingScore: (decoded['qualifyingScore'] as int?) ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Error fetching location leaderboard: $e');
      lastLeaderboardWasOffline = true;
      return (entries: const <Map<String, dynamic>>[], qualifyingScore: 0);
    }
    lastLeaderboardWasOffline = false;
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
      if (response.statusCode == 200) {
        lastLeaderboardWasOffline = false;
        return decoded;
      }
      return {'error': decoded['error'] ?? 'Unknown error'};
    } catch (e) {
      debugPrint('Error submitting location score: $e');
      lastLeaderboardWasOffline = true;
    }
    return null;
  }
}
