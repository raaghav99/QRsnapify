import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/app_bottom_nav.dart';
import 'scan/scan_screen.dart';
import 'scan/scan_controller.dart';
import 'generate/generate_screen.dart';
import 'history/history_screen.dart';

final tabIndexProvider = StateProvider<int>((_) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ScanScreen(),
          GenerateScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onTap: (i) {
          final prev = ref.read(tabIndexProvider);
          ref.read(tabIndexProvider.notifier).state = i;

          final scanCtrl = ref.read(scanControllerProvider.notifier);
          if (i == 0 && prev != 0) {
            // Switching TO scan tab — resume camera
            scanCtrl.startCamera();
          } else if (i != 0 && prev == 0) {
            // Switching AWAY from scan tab — stop camera
            scanCtrl.stopCamera();
          }
        },
      ),
    );
  }
}
