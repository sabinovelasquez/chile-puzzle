import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static const _muteKey = 'sound_muted';
  static late SharedPreferences _prefs;
  static bool _muted = false;
  static final AudioPlayer _player = AudioPlayer();

  static bool get isMuted => _muted;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _muted = _prefs.getBool(_muteKey) ?? false;
  }

  static Future<void> toggleMute() async {
    _muted = !_muted;
    await _prefs.setBool(_muteKey, _muted);
  }

  static void playPiecePlaced() {
    if (_muted) return;
    _player.play(AssetSource('sounds/place-piece.wav'));
  }

  static void playPuzzleComplete() {
    if (_muted) return;
    _player.play(AssetSource('sounds/puzzle-finished-confetti.mp3'));
  }
}
