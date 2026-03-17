import 'package:shared_preferences/shared_preferences.dart';

class AgeScaleService {
  static const _key = 'user_age';

  Future<int?> getUserAge() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(_key);
    return val;
  }

  Future<void> saveUserAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, age);
  }

  double getScaleFactor(int? age) {
    if (age == null) return 1.0;
    if (age < 18) return 0.85;
    if (age <= 35) return 1.0;
    if (age <= 50) return 1.15;
    return 1.3;
  }
}
