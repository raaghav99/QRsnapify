import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';

// Default color presets shown as quick-picks in the wheel dialog
const List<Color> kPresetColors = [
  Color(0xFF3D5AFE), // Default Blue
  Color(0xFFFF6F00), // Amber
  Color(0xFF00897B), // Forest
  Color(0xFF7B1FA2), // Violet
  Color(0xFF1A237E), // Midnight
  Color(0xFFE53935), // Ruby
  Color(0xFFE91E63), // Pink
  Color(0xFF00ACC1), // Cyan
  Color(0xFF43A047), // Green
  Color(0xFFFF7043), // Deep Orange
];

const _kDefaultColor = Color(0xFF3D5AFE);

class ThemeSettings {
  final bool weeklyColorsEnabled;
  final Color selectedColor;
  // weekday (1=Mon…7=Sun) → ARGB int; null means not set
  final Map<int, int> weeklyMap;

  const ThemeSettings({
    this.weeklyColorsEnabled = false,
    this.selectedColor = _kDefaultColor,
    this.weeklyMap = const {},
  });

  Color get effectiveColor {
    if (weeklyColorsEnabled) {
      final argb = weeklyMap[DateTime.now().weekday];
      if (argb != null) return Color(argb);
    }
    return selectedColor;
  }
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _keyWeekly = 'theme_weekly_enabled';
  static const _keyColor  = 'theme_color';

  @override
  ThemeSettings build() {
    // Load synchronously from pre-loaded prefs — no theme flash
    final prefs = ref.read(sharedPrefsProvider);
    final map = <int, int>{};
    for (var d = 1; d <= 7; d++) {
      final v = prefs.getInt('theme_day_$d');
      if (v != null) map[d] = v;
    }
    return ThemeSettings(
      weeklyColorsEnabled: prefs.getBool(_keyWeekly) ?? false,
      selectedColor: Color(prefs.getInt(_keyColor) ?? _kDefaultColor.toARGB32()),
      weeklyMap: map,
    );
  }

  Future<void> toggleWeeklyColors() async {
    state = ThemeSettings(
      weeklyColorsEnabled: !state.weeklyColorsEnabled,
      selectedColor: state.selectedColor,
      weeklyMap: state.weeklyMap,
    );
    (await SharedPreferences.getInstance()).setBool(_keyWeekly, state.weeklyColorsEnabled);
  }

  Future<void> selectColor(Color color) async {
    state = ThemeSettings(
      weeklyColorsEnabled: state.weeklyColorsEnabled,
      selectedColor: color,
      weeklyMap: state.weeklyMap,
    );
    (await SharedPreferences.getInstance()).setInt(_keyColor, color.toARGB32());
  }

  Future<void> setDayColor(int weekday, Color? color) async {
    final map = Map<int, int>.from(state.weeklyMap);
    if (color == null) {
      map.remove(weekday);
    } else {
      map[weekday] = color.toARGB32();
    }
    state = ThemeSettings(
      weeklyColorsEnabled: state.weeklyColorsEnabled,
      selectedColor: state.selectedColor,
      weeklyMap: map,
    );
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      prefs.remove('theme_day_$weekday');
    } else {
      prefs.setInt('theme_day_$weekday', color.toARGB32());
    }
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
  () => ThemeSettingsNotifier(),
);
