import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';

class OnboardingState {
  final int currentPage;
  final int? selectedAge;

  const OnboardingState({this.currentPage = 0, this.selectedAge});

  OnboardingState copyWith({int? currentPage, int? selectedAge, bool clearAge = false}) =>
      OnboardingState(
        currentPage: currentPage ?? this.currentPage,
        selectedAge: clearAge ? null : (selectedAge ?? this.selectedAge),
      );
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this.ref) : super(const OnboardingState());

  final Ref ref;

  void nextPage() => state = state.copyWith(currentPage: state.currentPage + 1);

  void setAge(int age) => state = state.copyWith(selectedAge: age);

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (state.selectedAge != null) {
      final ageService = ref.read(ageScaleServiceProvider);
      await ageService.saveUserAge(state.selectedAge!);
      final scale = ageService.getScaleFactor(state.selectedAge);
      ref.read(textScaleProvider.notifier).state = scale;
    }

    ref.read(onboardingCompleteProvider.notifier).state = true;
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>(
  (ref) => OnboardingController(ref),
);
