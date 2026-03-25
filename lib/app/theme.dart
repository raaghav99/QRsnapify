import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  // ── Light ──────────────────────────────────────────────────────────────────
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);

  // ── Dark ───────────────────────────────────────────────────────────────────
  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const textPrimaryDark = Color(0xFFF1F1F1);
  static const textSecondaryDark = Color(0xFF9CA3AF);

  // ── Always the same ────────────────────────────────────────────────────────
  static const primary = Color(0xFF3D5AFE);
  static const primaryDark = Color(0xFF0031CA);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const scanOverlay = Color(0xCC000000);

  // ── Context-aware helpers ──────────────────────────────────────────────────
  static Color bgColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? backgroundDark : background;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : surface;

  static Color textColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimary;

  static Color textSubColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondary;
}

abstract class AppRadius {
  static const card = 16.0;
  static const button = 12.0;
  static const chip = 8.0;
  static final cardRadius = BorderRadius.circular(card);
  static final buttonRadius = BorderRadius.circular(button);
  static final chipRadius = BorderRadius.circular(chip);
}

abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

abstract class AppShadows {
  static const card = BoxShadow(
    blurRadius: 12,
    color: Color(0x0F000000),
    offset: Offset(0, 2),
  );
}

abstract class AppTextStyles {
  static TextStyle heading(BuildContext context) => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textColor(context),
      );

  static TextStyle subheading(BuildContext context) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textColor(context),
      );

  static TextStyle body(BuildContext context) => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textColor(context),
      );

  static TextStyle caption(BuildContext context) => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSubColor(context),
      );

  static TextStyle button(BuildContext context) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );
}

ThemeData appTheme([Color primaryColor = AppColors.primary]) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: AppColors.surface,
      primary: primaryColor,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
        elevation: 0,
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      color: AppColors.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: primaryColor.withValues(alpha: 0.12),
      elevation: 0,
    ),
  );
}

ThemeData appDarkTheme([Color primaryColor = AppColors.primary]) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      surface: AppColors.surfaceDark,
      primary: primaryColor,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
        elevation: 0,
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      color: AppColors.surfaceDark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      indicatorColor: primaryColor.withValues(alpha: 0.18),
      elevation: 0,
    ),
  );
}
