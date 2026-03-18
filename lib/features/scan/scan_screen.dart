import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../models/scan_result.dart';
import '../../shared/widgets/qr_result_sheet.dart';
import 'scan_controller.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  PermissionStatus? _cameraStatus; // null = not yet checked
  bool _isSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(scanControllerProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(scanControllerProvider.notifier);
    if (state == AppLifecycleState.paused) {
      controller.stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      // Always re-check — user may have revoked/granted permission in Settings
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _cameraStatus = status);
    if (status.isGranted) {
      final notifier = ref.read(scanControllerProvider.notifier);
      notifier.initCamera();
      // If camera was already initialized (e.g. resuming), just restart it
      notifier.startCamera();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (mounted) setState(() => _cameraStatus = status);
    if (status.isGranted) {
      ref.read(scanControllerProvider.notifier).initCamera();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isSheetOpen) return; // Guard must be checked before anything else
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final code = barcode!.rawValue!;
    final controller = ref.read(scanControllerProvider.notifier);
    if (!controller.canProcessScan(code)) return;

    // Set flag immediately — before any async work — so concurrent frames are blocked
    _isSheetOpen = true;

    HapticFeedback.mediumImpact();
    final result = ScanResult.create(code);

    // Auto-save every scan to history
    ref.read(historyProvider.notifier).add(result);

    _showResultSheet(result);
  }

  void _showResultSheet(ScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrResultSheet(result: result, autoSaved: true),
    ).whenComplete(() => _isSheetOpen = false);
  }

  Future<void> _pickFromGallery() async {
    if (_isSheetOpen) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final controller =
        ref.read(scanControllerProvider.notifier).cameraController;
    if (controller == null) return;

    try {
      await controller.analyzeImage(image.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in image')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking permission — show loading, not permission UI
    if (_cameraStatus == null) {
      return const _CameraLoadingView();
    }

    if (!_cameraStatus!.isGranted) {
      return _PermissionView(onRequest: _requestPermission);
    }

    final scanState = ref.watch(scanControllerProvider);
    final cameraController =
        ref.read(scanControllerProvider.notifier).cameraController;

    if (!scanState.isCameraReady || cameraController == null) {
      return const _CameraLoadingView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          _ScanOverlay(),
          // Top buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Iconsax.image,
                    onTap: _pickFromGallery,
                  ),
                  _CircleButton(
                    icon: scanState.isTorchOn
                        ? Iconsax.flash_slash
                        : Iconsax.flash,
                    onTap: () =>
                        ref.read(scanControllerProvider.notifier).toggleTorch(),
                  ),
                ],
              ),
            ),
          ),
          // Bottom hint pill
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point at a QR code to scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Camera loading placeholder ───────────────────────────────────────────────

class _CameraLoadingView extends StatelessWidget {
  const _CameraLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                children: const [
                  Positioned(top: 0, left: 0, child: _Corner(topLeft: true)),
                  Positioned(top: 0, right: 0, child: _Corner(topRight: true)),
                  Positioned(
                      bottom: 0, left: 0, child: _Corner(bottomLeft: true)),
                  Positioned(
                      bottom: 0, right: 0, child: _Corner(bottomRight: true)),
                  Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Starting camera…',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scan overlay ─────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.68;

    return CustomPaint(
      size: size,
      painter: _OverlayPainter(scanSize: scanSize),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Center(
          child: SizedBox(
            width: scanSize,
            height: scanSize,
            child: Stack(
              children: [
                const Positioned(
                    top: 0, left: 0, child: _Corner(topLeft: true)),
                const Positioned(
                    top: 0, right: 0, child: _Corner(topRight: true)),
                const Positioned(
                    bottom: 0, left: 0, child: _Corner(bottomLeft: true)),
                const Positioned(
                    bottom: 0, right: 0, child: _Corner(bottomRight: true)),
                _ScanLine(scanSize: scanSize),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _Corner({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _CornerPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
          color: AppColors.primary,
          thickness: 3.5,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  final Color color;
  final double thickness;

  _CornerPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (topLeft) {
      canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
    }
    if (topRight) {
      canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
      canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
    }
    if (bottomRight) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _ScanLine extends StatefulWidget {
  final double scanSize;
  const _ScanLine({required this.scanSize});

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Positioned(
        top: _animation.value * widget.scanSize,
        left: 4,
        right: 4,
        child: Container(
          height: 2.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.primary.withValues(alpha: 0.8),
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double scanSize;
  _OverlayPainter({required this.scanSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.scanOverlay;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = scanSize / 2;
    const r = 14.0;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
        const Radius.circular(r),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.scanSize != scanSize;
}

// ─── Top circle buttons ───────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(50),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ─── Permission view ──────────────────────────────────────────────────────────

class _PermissionView extends StatelessWidget {
  final VoidCallback onRequest;
  const _PermissionView({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Camera Access Needed',
                  style: AppTextStyles.subheading(context)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'QRSnap needs camera access to scan QR codes.',
                style: AppTextStyles.body(context)
                    .copyWith(color: AppColors.textSubColor(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRequest,
                  child: const Text('Allow Camera'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Fallback for when permission is permanently denied
              TextButton(
                onPressed: openAppSettings,
                child: Text(
                  'Open App Settings',
                  style: TextStyle(
                      color: AppColors.textSubColor(context), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
