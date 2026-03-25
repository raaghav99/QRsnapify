import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../app/theme.dart';
import '../../shared/widgets/adaptive_button.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final state = ref.read(onboardingControllerProvider);
    if (state.currentPage < 2) {
      controller.nextPage();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      controller.completeOnboarding();
    }
  }

  void _skip() {
    ref.read(onboardingControllerProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _skip,
                  child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onNext: _goToNextPage),
                  _AgePage(onNext: _goToNextPage),
                  _ReadyPage(onNext: _goToNextPage),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 3,
                effect: ExpandingDotsEffect(
                  activeDotColor: Theme.of(context).colorScheme.primary,
                  dotColor: AppColors.textSecondary.withValues(alpha: 0.3),
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.qr_code_2_rounded, size: 56, color: Colors.white),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const Gap(AppSpacing.xxl),
          Text('QRSnap', style: AppTextStyles.heading(context).copyWith(fontSize: 32))
              .animate().fadeIn(delay: 200.ms),
          const Gap(AppSpacing.md),
          Text(
            'Does one thing.\nHas no ads. Forever free.',
            style: AppTextStyles.subheading(context).copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          const Gap(AppSpacing.xxl * 2),
          AdaptiveButton(label: 'Get Started', onPressed: onNext)
              .animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),
        ],
      ),
    );
  }
}

class _AgePage extends ConsumerWidget {
  final VoidCallback onNext;
  const _AgePage({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAge = ref.watch(onboardingControllerProvider).selectedAge;

    const ageRanges = [
      ('Under 18', 15),
      ('18 - 35', 25),
      ('36 - 50', 43),
      ('50+', 55),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('How old are you?', style: AppTextStyles.heading(context)),
          const Gap(AppSpacing.md),
          Text(
            "We'll make QRSnap comfortable for your eyes.",
            style: AppTextStyles.body(context).copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const Gap(AppSpacing.xxl),
          ...ageRanges.map((range) {
            final isSelected = selectedAge == range.$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: InkWell(
                onTap: () => ref.read(onboardingControllerProvider.notifier).setAge(range.$2),
                borderRadius: AppRadius.cardRadius,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primary : AppColors.cardColor(context),
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.textSubColor(context).withValues(alpha: 0.2),
                    ),
                    boxShadow: const [AppShadows.card],
                  ),
                  child: Row(
                    children: [
                      Text(
                        range.$1,
                        style: AppTextStyles.body(context).copyWith(
                          color: isSelected ? Colors.white : AppColors.textColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Gap(AppSpacing.xxl),
          AdaptiveButton(
            label: selectedAge != null ? 'Continue' : 'Skip for now',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  final VoidCallback onNext;
  const _ReadyPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.touch_app_rounded, size: 52, color: AppColors.success),
          ).animate().scale(duration: 400.ms),
          const Gap(AppSpacing.xxl),
          Text("You're all set!", style: AppTextStyles.heading(context)),
          const Gap(AppSpacing.md),
          Text(
            "Your first tap will calibrate button size for your finger. The app learns how you tap.",
            style: AppTextStyles.body(context).copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(AppSpacing.xxl * 2),
          AdaptiveButton(label: 'Start Scanning', onPressed: onNext),
        ],
      ),
    );
  }
}
