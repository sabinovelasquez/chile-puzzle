import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static late SharedPreferences _prefs;

  static const _referenceImageKey = 'setting_reference_image';
  static const _edgeShineKey = 'setting_edge_shine';
  static const _lockInPlaceKey = 'setting_lock_in_place';
  static const _multiSelectKey = 'setting_multi_select';

  static bool _referenceImage = true;
  static bool _edgeShine = true;
  static bool _lockInPlace = true;
  static bool _multiSelect = false;

  static bool get referenceImage => _referenceImage;
  static bool get edgeShine => _edgeShine;
  static bool get lockInPlace => _lockInPlace;
  static bool get multiSelect => _multiSelect;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _referenceImage = _prefs.getBool(_referenceImageKey) ?? true;
    _edgeShine = _prefs.getBool(_edgeShineKey) ?? true;
    _lockInPlace = _prefs.getBool(_lockInPlaceKey) ?? true;
    _multiSelect = _prefs.getBool(_multiSelectKey) ?? false;
  }

  static Future<void> setReferenceImage(bool v) async {
    _referenceImage = v;
    await _prefs.setBool(_referenceImageKey, v);
  }

  static Future<void> setEdgeShine(bool v) async {
    _edgeShine = v;
    await _prefs.setBool(_edgeShineKey, v);
  }

  static Future<void> setLockInPlace(bool v) async {
    _lockInPlace = v;
    await _prefs.setBool(_lockInPlaceKey, v);
  }

  static Future<void> setMultiSelect(bool v) async {
    _multiSelect = v;
    await _prefs.setBool(_multiSelectKey, v);
  }
}
