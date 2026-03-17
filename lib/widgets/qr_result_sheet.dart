import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

class QrResultSheet extends StatelessWidget {
  const QrResultSheet({
    super.key,
    required this.content,
    required this.type,
  });

  final String content;
  final String type;

  static Future<void> show(
    BuildContext context, {
    required String content,
    required String type,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrResultSheet(content: content, type: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(iconForScanType(type), size: 16, color: kPrimary),
                const SizedBox(width: 8),
                Text(
                  _typeLabel(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                color: kOnBackground,
                height: 1.5,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _ActionChip(
                  icon: Icons.copy_outlined,
                  label: 'Copy',
                  onTap: () => _copy(context),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => _share(context),
                ),
                if (type == 'url') ...[
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.open_in_new_outlined,
                    label: 'Open',
                    onTap: () => _openUrl(context),
                    primary: true,
                  ),
                ],
              ],
            ),
          ],
        ).animate().slideY(begin: 0.1, duration: kAnimNormal).fadeIn(),
      ),
    );
  }

  String _typeLabel() => switch (type) {
        'url' => 'URL',
        'email' => 'EMAIL',
        'phone' => 'PHONE',
        _ => 'TEXT',
      };

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _share(BuildContext context) async {
    await Share.share(content);
  }

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(content);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL')),
        );
      }
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? kPrimary : kBackground,
          borderRadius: BorderRadius.circular(kChipRadius),
          border: primary ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: primary ? kOnPrimary : kOnBackground,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary ? kOnPrimary : kOnBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
