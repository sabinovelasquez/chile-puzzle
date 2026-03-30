import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

class AuthService {
  static Future<void> signIn() async {
    try {
      await GameAuth.signIn();
      if (kDebugMode) {
        print("Successfully signed into Game Services");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to sign in: $e");
      }
    }
  }

  static Future<bool> isSignedIn() async {
    try {
      return await GameAuth.isSignedIn;
    } catch (e) {
      return false;
    }
  }
}
