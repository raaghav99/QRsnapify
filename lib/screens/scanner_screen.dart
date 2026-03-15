import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/history_provider.dart';
import '../theme.dart';
import '../widgets/qr_result_sheet.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  MobileScannerController? _controller;
  bool _hasPermission = true;
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    } catch (_) {
      setState(() => _hasPermission = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_controller != null)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () {
                _controller?.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
        ],
      ),
      body: _hasPermission ? _buildScanner() : _buildPermissionDenied(),
    );
  }

  Widget _buildScanner() {
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimary),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
          errorBuilder: (context, error, _) {
            if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _hasPermission = false);
              });
            }
            return _buildPermissionDenied();
          },
        ),
        _ScanOverlay(),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: const Center(
            child: Text(
              'Align QR code within the frame',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera access required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant camera permission in Settings to scan QR codes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: FilledButton.styleFrom(backgroundColor: kPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _scanned = true;
    _controller?.stop();

    final content = barcode.rawValue!;
    await ref.read(historyProvider.notifier).add(content);

    if (!mounted) return;
    await QrResultSheet.show(
      context,
      content: content,
      type: _detectType(content),
    );

    if (mounted) {
      setState(() => _scanned = false);
      _controller?.start();
    }
  }

  String _detectType(String content) {
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return 'url';
    } else if (content.startsWith('mailto:') ||
        RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(content)) {
      return 'email';
    } else if (content.startsWith('tel:') ||
        RegExp(r'^\+?[\d\s\-()]{7,}$').hasMatch(content)) {
      return 'phone';
    }
    return 'text';
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OverlayPainter(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutSize = size.width * 0.65;
    final left = (size.width - cutSize) / 2;
    final top = (size.height - cutSize) / 2;
    final cutRect = Rect.fromLTWH(left, top, cutSize, cutSize);

    final paint = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Corner accents
    final linePaint = Paint()
      ..color = kPrimary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 24.0;
    // Top-left
    canvas.drawLine(Offset(left, top + len), Offset(left, top), linePaint);
    canvas.drawLine(Offset(left, top), Offset(left + len, top), linePaint);
    // Top-right
    canvas.drawLine(Offset(left + cutSize - len, top), Offset(left + cutSize, top), linePaint);
    canvas.drawLine(Offset(left + cutSize, top), Offset(left + cutSize, top + len), linePaint);
    // Bottom-left
    canvas.drawLine(Offset(left, top + cutSize - len), Offset(left, top + cutSize), linePaint);
    canvas.drawLine(Offset(left, top + cutSize), Offset(left + len, top + cutSize), linePaint);
    // Bottom-right
    canvas.drawLine(Offset(left + cutSize - len, top + cutSize), Offset(left + cutSize, top + cutSize), linePaint);
    canvas.drawLine(Offset(left + cutSize, top + cutSize - len), Offset(left + cutSize, top + cutSize), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
