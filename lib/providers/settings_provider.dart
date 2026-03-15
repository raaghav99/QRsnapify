import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────
const _kButtonHeight = 'finger_button_height';
const _kUserAge = 'user_age';
const _kOnboardingDone = 'onboarding_done';

// ── SharedPreferences provider ────────────────────────────────────────────────
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override this in ProviderScope');
});

// ── Button height ─────────────────────────────────────────────────────────────
final buttonHeightProvider =
    StateNotifierProvider<ButtonHeightNotifier, double>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return ButtonHeightNotifier(prefs);
});

class ButtonHeightNotifier extends StateNotifier<double> {
  ButtonHeightNotifier(this._prefs)
      : super(_prefs.getDouble(_kButtonHeight) ?? kDefaultButtonHeight);

  final SharedPreferences _prefs;

  /// Called with the physical pointer contact size in logical pixels.
  /// Only calibrates once (on first touch after fresh install).
  void calibrateFromPointerSize(double sizePx) {
    if (_prefs.containsKey(_kButtonHeight)) return;
    // Map contact size to a sensible button height range
    final calibrated = (sizePx * 2.2).clamp(kMinButtonHeight, kMaxButtonHeight);
    state = calibrated;
    _prefs.setDouble(_kButtonHeight, calibrated);
  }

  void reset() {
    _prefs.remove(_kButtonHeight);
    state = kDefaultButtonHeight;
  }
}

// ── User age ──────────────────────────────────────────────────────────────────
final userAgeProvider = StateNotifierProvider<UserAgeNotifier, int?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return UserAgeNotifier(prefs);
});

class UserAgeNotifier extends StateNotifier<int?> {
  UserAgeNotifier(this._prefs) : super(_prefs.getInt(_kUserAge));

  final SharedPreferences _prefs;

  void setAge(int age) {
    state = age;
    _prefs.setInt(_kUserAge, age);
  }
}

// ── Onboarding ────────────────────────────────────────────────────────────────
final onboardingDoneProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return OnboardingNotifier(prefs);
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._prefs)
      : super(_prefs.getBool(_kOnboardingDone) ?? false);

  final SharedPreferences _prefs;

  void markDone() {
    state = true;
    _prefs.setBool(_kOnboardingDone, true);
  }
}

// ── Text scale derived from age ───────────────────────────────────────────────
/// Returns [minScale, maxScale] for MediaQuery.withClampedTextScaling
List<double> textScaleForAge(int? age) {
  if (age == null) return [1.0, 1.0];
  if (age < 25) return [0.9, 1.0];
  if (age <= 45) return [1.0, 1.1];
  return [1.1, 1.3];
}
