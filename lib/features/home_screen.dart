import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/app_bottom_nav.dart';
import 'scan/scan_screen.dart';
import 'generate/generate_screen.dart';
import 'history/history_screen.dart';

final _tabIndexProvider = StateProvider<int>((_) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_tabIndexProvider);

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
        onTap: (i) => ref.read(_tabIndexProvider.notifier).state = i,
      ),
    );
  }
}
