import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/history_provider.dart';
import '../theme.dart';
import '../widgets/adaptive_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QRSnap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'History',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const _HeroCard().animate().fadeIn(duration: kAnimNormal),
              const SizedBox(height: 24),
              const Text(
                'Quick actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kSubtitle,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              AdaptiveButton(
                label: 'Scan QR Code',
                icon: Icons.qr_code_scanner_outlined,
                onPressed: () => Navigator.pushNamed(context, '/scanner'),
              ).animate().fadeIn(delay: 100.ms, duration: kAnimNormal),
              const SizedBox(height: 10),
              AdaptiveButton(
                label: 'Generate QR Code',
                icon: Icons.add_box_outlined,
                onPressed: () => Navigator.pushNamed(context, '/generator'),
              ).animate().fadeIn(delay: 150.ms, duration: kAnimNormal),
              const SizedBox(height: 28),
              if (history.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent scans',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kSubtitle,
                        letterSpacing: 0.3,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/history'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: history.length.clamp(0, 5),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = history[i];
                      return _HistoryTile(
                        content: item.content,
                        type: item.type,
                        time: item.scannedAt,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimary, kPrimaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.qr_code_2_outlined, color: Colors.white70, size: 36),
          SizedBox(height: 12),
          Text(
            'Open. Scan. Done.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'No account. No ads. Just QR.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    super.key,
    required this.content,
    required this.type,
    required this.time,
  });

  final String content;
  final String type;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      'url' => Icons.link_outlined,
      'email' => Icons.email_outlined,
      'phone' => Icons.phone_outlined,
      _ => Icons.text_fields_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: kOnBackground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
