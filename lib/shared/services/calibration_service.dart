import 'package:shared_preferences/shared_preferences.dart';

class CalibrationService {
  static const _key = 'finger_button_height';

  Future<double> getButtonHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_key) ?? 52.0;
  }

  Future<void> saveButtonHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, height);
  }

  Future<bool> isCalibrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  double mapRadiusToHeight(double radiusMajor) {
    if (radiusMajor < 20) return 48.0;
    if (radiusMajor <= 35) return 56.0;
    return 64.0;
  }
}
