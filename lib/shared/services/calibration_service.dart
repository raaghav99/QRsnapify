import 'package:shared_preferences/shared_preferences.dart';

class CalibrationService {
  static const _key = 'finger_button_height';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<double> getButtonHeight() async {
    return (await _p).getDouble(_key) ?? 52.0;
  }

  Future<void> saveButtonHeight(double height) async {
    await (await _p).setDouble(_key, height);
  }

  Future<bool> isCalibrated() async {
    return (await _p).containsKey(_key);
  }

  double mapRadiusToHeight(double radiusMajor) {
    if (radiusMajor < 20) return 48.0;
    if (radiusMajor <= 35) return 56.0;
    return 64.0;
  }
}
