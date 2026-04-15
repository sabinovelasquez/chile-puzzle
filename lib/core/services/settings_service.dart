import 'package:shared_preferences/shared_preferences.dart';

enum ShimmerMode { shimmer, flash, off }

class SettingsService {
  static late SharedPreferences _prefs;

  static const _shimmerModeKey = 'setting_shimmer_mode';
  static const _hintLockKey = 'hint_lock_last';
  static const _hintMultiKey = 'hint_multi_last';
  static const _hintReferenceKey = 'hint_reference_last';
  static const _autoSubmitRankingKey = 'setting_auto_submit_ranking';

  static ShimmerMode _shimmerMode = ShimmerMode.flash;
  // Last-picked per-session hints — pre-fill the difficulty modal so the
  // player doesn't re-tick the same ayuda icons every launch.
  static bool _hintLock = false;
  static bool _hintMulti = false;
  static bool _hintReference = false;
  // Opt-in: when true, every puzzle completion silently pushes the running
  // total to the global leaderboard (requires stored initials). Default off
  // so players choose explicitly before anything leaves the device.
  static bool _autoSubmitRanking = false;

  static ShimmerMode get shimmerMode => _shimmerMode;
  static bool get lastHintLock => _hintLock;
  static bool get lastHintMulti => _hintMulti;
  static bool get lastHintReference => _hintReference;
  static bool get autoSubmitRanking => _autoSubmitRanking;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs.getString(_shimmerModeKey);
    if (raw != null) {
      _shimmerMode = ShimmerMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => ShimmerMode.flash,
      );
    } else {
      // Migrate legacy `setting_edge_shine` bool: true → shimmer, false → off.
      // New users (no key) default to flash.
      final legacy = _prefs.getBool('setting_edge_shine');
      _shimmerMode = legacy == null
          ? ShimmerMode.flash
          : (legacy ? ShimmerMode.shimmer : ShimmerMode.off);
      await _prefs.setString(_shimmerModeKey, _shimmerMode.name);
    }

    _hintLock = _prefs.getBool(_hintLockKey) ?? false;
    _hintMulti = _prefs.getBool(_hintMultiKey) ?? false;
    _hintReference = _prefs.getBool(_hintReferenceKey) ?? false;
    _autoSubmitRanking = _prefs.getBool(_autoSubmitRankingKey) ?? false;

    // Clean up legacy session-toggle keys (superseded by the difficulty modal).
    await _prefs.remove('setting_edge_shine');
    await _prefs.remove('setting_reference_image');
    await _prefs.remove('setting_lock_in_place');
    await _prefs.remove('setting_multi_select');
  }

  static Future<void> setShimmerMode(ShimmerMode mode) async {
    _shimmerMode = mode;
    await _prefs.setString(_shimmerModeKey, mode.name);
  }

  static Future<void> setAutoSubmitRanking(bool value) async {
    _autoSubmitRanking = value;
    await _prefs.setBool(_autoSubmitRankingKey, value);
  }

  static Future<void> setLastHints({
    required bool lock,
    required bool multi,
    required bool reference,
  }) async {
    _hintLock = lock;
    _hintMulti = multi;
    _hintReference = reference;
    await _prefs.setBool(_hintLockKey, lock);
    await _prefs.setBool(_hintMultiKey, multi);
    await _prefs.setBool(_hintReferenceKey, reference);
  }
}
