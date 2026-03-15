import 'package:flutter/material.dart';

// ── Colour palette ────────────────────────────────────────────────────────────
const kBackground = Color(0xFFFAFAFA);
const kPrimary = Color(0xFF3D5AFE);
const kPrimaryLight = Color(0xFF8187FF);
const kSurface = Color(0xFFFFFFFF);
const kError = Color(0xFFB00020);
const kOnPrimary = Color(0xFFFFFFFF);
const kOnBackground = Color(0xFF1C1C1E);
const kSubtitle = Color(0xFF6B6B6B);

// ── Shape ─────────────────────────────────────────────────────────────────────
const kCardRadius = 16.0;
const kButtonRadius = 14.0;
const kChipRadius = 32.0;

// ── Sizing ────────────────────────────────────────────────────────────────────
const kDefaultButtonHeight = 52.0;
const kMinButtonHeight = 44.0;
const kMaxButtonHeight = 72.0;

// ── Animation durations ───────────────────────────────────────────────────────
const kAnimFast = Duration(milliseconds: 200);
const kAnimNormal = Duration(milliseconds: 300);

// ── Theme ─────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      brightness: Brightness.light,
      surface: kSurface,
      primary: kPrimary,
      onPrimary: kOnPrimary,
      error: kError,
    ),
    scaffoldBackgroundColor: kBackground,
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
      ),
      color: kSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: kOnBackground,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: kOnBackground,
        letterSpacing: -0.3,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: kOnPrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(kButtonRadius)),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kButtonRadius),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kButtonRadius),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kButtonRadius),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
