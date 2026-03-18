import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';

class WindPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0, driven by AnimationController
  final Brightness brightness;

  WindPainter({required this.progress, required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final layers = [
      (opacity: 0.08, freq: 1.0, phase: 0.0, amp: 50.0),
      (opacity: 0.12, freq: 1.3, phase: 1.3, amp: 40.0),
      (opacity: 0.06, freq: 0.8, phase: 2.6, amp: 60.0),
    ];

    for (final layer in layers) {
      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: layer.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final yOffset = size.height * 0.5 +
          math.sin(progress * math.pi * 2 + layer.phase) * layer.amp * 0.3;

      for (var x = 0.0; x <= size.width; x += 2.0) {
        final normalX = x / size.width;
        final y = yOffset +
            math.sin(normalX * math.pi * 2 * layer.freq +
                    progress * math.pi * 2 +
                    layer.phase) *
                layer.amp;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WindPainter old) => old.progress != progress;
}
