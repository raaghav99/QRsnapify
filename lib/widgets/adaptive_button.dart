import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme.dart';

/// A FilledButton whose height adapts to the user's calibrated finger size.
/// On the very first tap (before calibration), the pointer contact area is
/// recorded and persisted. Subsequent builds read the stored height.
class AdaptiveButton extends ConsumerWidget {
  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.width = double.infinity,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = ref.watch(buttonHeightProvider);
    final notifier = ref.read(buttonHeightProvider.notifier);

    final buttonStyle = FilledButton.styleFrom(
      minimumSize: Size(width, height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kButtonRadius),
      ),
    );

    return Listener(
      onPointerDown: (event) {
        // event.radiusMajor is the contact radius in logical pixels
        final contactSize = event.radiusMajor;
        if (contactSize > 0) {
          notifier.calibrateFromPointerSize(contactSize);
        }
      },
      child: SizedBox(
        width: width,
        height: height,
        child: icon != null
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: Text(label),
                style: buttonStyle,
              )
            : FilledButton(
                onPressed: onPressed,
                style: buttonStyle,
                child: Text(label),
              ),
      ),
    );
  }
}
