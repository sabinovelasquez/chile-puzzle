import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static const _muteKey = 'sound_muted';
  static late SharedPreferences _prefs;
  static bool _muted = false;
  static late SoLoud _soloud;
  static AudioSource? _pieceSound;
  static AudioSource? _victorySound;

  static bool get isMuted => _muted;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _muted = _prefs.getBool(_muteKey) ?? false;
    _soloud = SoLoud.instance;
    await _soloud.init();
    // Preload sounds into memory
    final pieceData = await rootBundle.load('assets/sounds/place-piece-v3.wav');
    _pieceSound = await _soloud.loadMem(
      'place-piece-v3.wav',
      pieceData.buffer.asUint8List(),
    );
    final victoryData = await rootBundle.load('assets/sounds/victory.wav');
    _victorySound = await _soloud.loadMem(
      'victory.wav',
      victoryData.buffer.asUint8List(),
    );
  }

  static Future<void> toggleMute() async {
    _muted = !_muted;
    await _prefs.setBool(_muteKey, _muted);
  }

  /// Piece placed (any swap)
  static void playPiecePlaced() {
    if (_muted || _pieceSound == null) return;
    _soloud.play(_pieceSound!, volume: 0.5);
  }

  /// Puzzle completed
  static void playVictory() {
    if (_muted || _victorySound == null) return;
    _soloud.play(_victorySound!);
  }
}
