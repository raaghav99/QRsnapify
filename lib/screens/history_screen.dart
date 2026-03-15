import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/scan_result.dart';
import '../providers/history_provider.dart';
import '../theme.dart';
import '../widgets/qr_result_sheet.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: history.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = history[i];
                return _HistoryCard(
                  item: item,
                  onDismissed: () =>
                      ref.read(historyProvider.notifier).remove(item),
                  onTap: () => QrResultSheet.show(
                    context,
                    content: item.content,
                    type: item.type,
                  ),
                ).animate().fadeIn(
                      delay: Duration(milliseconds: i * 40),
                      duration: kAnimNormal,
                    );
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined, size: 64, color: kSubtitle),
          SizedBox(height: 16),
          Text(
            'No scans yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kSubtitle,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your scan history will appear here',
            style: TextStyle(fontSize: 14, color: kSubtitle),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All scan history will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kError),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(historyProvider.notifier).clear();
    }
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    super.key,
    required this.item,
    required this.onDismissed,
    required this.onTap,
  });

  final ScanResult item;
  final VoidCallback onDismissed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      'url' => Icons.link_outlined,
      'email' => Icons.email_outlined,
      'phone' => Icons.phone_outlined,
      _ => Icons.text_fields_outlined,
    };

    return Dismissible(
      key: Key(item.key.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kError,
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: kOnBackground,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(item.scannedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: kSubtitle,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kSubtitle, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
