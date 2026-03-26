import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanState {
  final bool isTorchOn;
  final String? lastCode;
  final bool isCameraReady;

  const ScanState({
    this.isTorchOn = false,
    this.lastCode,
    this.isCameraReady = false,
  });

  ScanState copyWith({
    bool? isTorchOn,
    String? lastCode,
    bool? isCameraReady,
  }) => ScanState(
    isTorchOn: isTorchOn ?? this.isTorchOn,
    lastCode: lastCode ?? this.lastCode,
    isCameraReady: isCameraReady ?? this.isCameraReady,
  );
}

class ScanController extends StateNotifier<ScanState> {
  ScanController() : super(const ScanState());

  MobileScannerController? cameraController;
  DateTime? _lastScan;

  void initCamera() {
    if (cameraController != null) return; // already initialized — don't recreate
    cameraController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );
    state = state.copyWith(isCameraReady: true);
  }

  Future<void> startCamera() async {
    try {
      await cameraController?.start();
    } catch (e) {
      debugPrint('Camera start failed: $e');
    }
  }

  Future<void> stopCamera() async {
    try {
      await cameraController?.stop();
    } catch (_) {}
  }

  Future<void> disposeCamera() async {
    await stopCamera();
    cameraController?.dispose();
    cameraController = null;
    state = state.copyWith(isCameraReady: false);
  }

  Future<void> toggleTorch() async {
    try {
      await cameraController?.toggleTorch();
      state = state.copyWith(isTorchOn: !state.isTorchOn);
    } catch (_) {
      // Torch not available or camera not ready — ignore, keep state as-is
    }
  }

  bool canProcessScan(String code) {
    final now = DateTime.now();
    if (_lastScan != null && now.difference(_lastScan!) < const Duration(seconds: 2)) {
      return false;
    }
    if (code == state.lastCode && _lastScan != null &&
        now.difference(_lastScan!) < const Duration(seconds: 10)) {
      return false;
    }
    _lastScan = now;
    state = state.copyWith(lastCode: code);
    return true;
  }

}

// No autoDispose — camera controller must persist through tab switches
final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>(
  (_) => ScanController(),
);
