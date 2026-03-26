import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'providers.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home_screen.dart';
import '../features/settings/settings_provider.dart';
import '../shared/services/calibration_service.dart';
import '../shared/services/age_scale_service.dart';

class QRSnapApp extends ConsumerStatefulWidget {
  const QRSnapApp({super.key});

  @override
  ConsumerState<QRSnapApp> createState() => _QRSnapAppState();
}

class _QRSnapAppState extends ConsumerState<QRSnapApp> {
  bool _initialized = false;
  bool _onboardingDone = false;
  bool _calibrated = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    final ageService = AgeScaleService();
    final age = await ageService.getUserAge();
    if (!mounted) return;
    if (age != null) {
      ref.read(textScaleProvider.notifier).state = ageService.getScaleFactor(age);
    }

    final calibService = CalibrationService();
    final buttonH = await calibService.getButtonHeight();
    if (!mounted) return;
    ref.read(buttonHeightProvider.notifier).state = buttonH;
    _calibrated = await calibService.isCalibrated();

    if (mounted) {
      ref.read(onboardingCompleteProvider.notifier).state = _onboardingDone;
      setState(() => _initialized = true);
    }
  }

  void _onPointerDown(PointerDownEvent event) async {
    if (_calibrated) return;
    final radius = event.radiusMajor;
    if (radius <= 0) return;

    final calibService = ref.read(calibrationServiceProvider);
    final height = calibService.mapRadiusToHeight(radius);
    await calibService.saveButtonHeight(height);
    ref.read(buttonHeightProvider.notifier).state = height;
    setState(() => _calibrated = true);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = ref.watch(textScaleProvider);
    final onboardingDone = ref.watch(onboardingCompleteProvider);
    final themeSettings = ref.watch(themeSettingsProvider);

    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Listener(
      onPointerDown: _onPointerDown,
      child: MaterialApp(
        title: 'QRSnapify',
        theme: appTheme(themeSettings.effectiveColor),
        darkTheme: appDarkTheme(themeSettings.effectiveColor),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
        ],
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
        home: onboardingDone ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
