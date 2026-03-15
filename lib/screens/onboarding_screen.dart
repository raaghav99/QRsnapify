import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/adaptive_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  double _age = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.qr_code_scanner_outlined,
                size: 56,
                color: kPrimary,
              ).animate().scale(duration: kAnimNormal),
              const SizedBox(height: 24),
              const Text(
                'Welcome to\nQRSnap',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: kOnBackground,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: kAnimNormal),
              const SizedBox(height: 12),
              const Text(
                'One quick question to make the app comfortable for you.',
                style: TextStyle(
                  fontSize: 16,
                  color: kSubtitle,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: kAnimNormal),
              const Spacer(flex: 1),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(kCardRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How old are you?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kOnBackground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'We use this to adjust text size for comfort.',
                      style: TextStyle(
                        fontSize: 13,
                        color: kSubtitle,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        '${_age.round()}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    Slider(
                      value: _age,
                      min: 13,
                      max: 90,
                      divisions: 77,
                      activeColor: kPrimary,
                      onChanged: (v) => setState(() => _age = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('13', style: TextStyle(color: kSubtitle, fontSize: 12)),
                        const Text('90', style: TextStyle(color: kSubtitle, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: kAnimNormal),
              const Spacer(flex: 2),
              AdaptiveButton(
                label: 'Get Started',
                icon: Icons.arrow_forward_outlined,
                onPressed: _proceed,
              ).animate().fadeIn(delay: 400.ms, duration: kAnimNormal),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: kSubtitle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _proceed() {
    ref.read(userAgeProvider.notifier).setAge(_age.round());
    ref.read(onboardingDoneProvider.notifier).markDone();
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _skip() {
    ref.read(onboardingDoneProvider.notifier).markDone();
    Navigator.pushReplacementNamed(context, '/home');
  }
}
