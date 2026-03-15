import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/settings_provider.dart';
import 'screens/generator_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/scanner_screen.dart';
import 'theme.dart';

class QRSnapApp extends ConsumerWidget {
  const QRSnapApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final age = ref.watch(userAgeProvider);
    final scales = textScaleForAge(age);

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: scales[0],
      maxScaleFactor: scales[1],
      child: MaterialApp(
        title: 'QRSnap',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        initialRoute: _initialRoute(ref),
        routes: {
          '/': (ctx) => const OnboardingScreen(),
          '/onboarding': (ctx) => const OnboardingScreen(),
          '/home': (ctx) => const HomeScreen(),
          '/scanner': (ctx) => const ScannerScreen(),
          '/generator': (ctx) => const GeneratorScreen(),
          '/history': (ctx) => const HistoryScreen(),
        },
      ),
    );
  }

  String _initialRoute(WidgetRef ref) {
    final onboardingDone = ref.read(onboardingDoneProvider);
    return onboardingDone ? '/home' : '/onboarding';
  }
}
