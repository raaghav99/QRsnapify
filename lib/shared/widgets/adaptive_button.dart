import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';

class AdaptiveButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final IconData? icon;

  const AdaptiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = ref.watch(buttonHeightProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
          minimumSize: Size(double.infinity, height),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: AppTextStyles.button(context)),
                ],
              ),
      ),
    );
  }
}
