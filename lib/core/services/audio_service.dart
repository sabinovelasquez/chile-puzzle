import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static const _muteKey = 'sound_muted';
  static late SharedPreferences _prefs;
  static bool _muted = false;

  static final AudioPlayer _anyPiecePlayer = AudioPlayer();
  static final AudioPlayer _correctPlayer = AudioPlayer();
  static final AudioPlayer _victoryPlayer = AudioPlayer();
  static final AudioPlayer _fireworksPlayer = AudioPlayer();

  static bool get isMuted => _muted;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _muted = _prefs.getBool(_muteKey) ?? false;
  }

  static Future<void> toggleMute() async {
    _muted = !_muted;
    await _prefs.setBool(_muteKey, _muted);
  }

  /// Any piece swap (correct or not)
  static void playAnyPiece() {
    if (_muted) return;
    _anyPiecePlayer.stop();
    _anyPiecePlayer.play(AssetSource('sounds/place-any-piece.wav'));
  }

  /// Correct placement — overlaps at lower volume if already playing
  static void playCorrectPiece() {
    if (_muted) return;
    if (_correctPlayer.state == PlayerState.playing) {
      // Overlap: new player at lower volume
      final overlap = AudioPlayer();
      overlap.setVolume(0.4);
      overlap.play(AssetSource('sounds/place-piece-v2.wav'));
      overlap.onPlayerComplete.listen((_) => overlap.dispose());
    } else {
      _correctPlayer.setVolume(1.0);
      _correctPlayer.play(AssetSource('sounds/place-piece-v2.wav'));
    }
  }

  /// Victory: both sounds play simultaneously
  static void playVictory() {
    if (_muted) return;
    _victoryPlayer.play(AssetSource('sounds/victory.wav'));
    _fireworksPlayer.play(AssetSource('sounds/fireworks.wav'));
  }
}
