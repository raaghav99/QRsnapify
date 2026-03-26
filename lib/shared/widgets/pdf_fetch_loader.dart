import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../painters/wind_painter.dart';

enum PdfFetchResult { success, timeout, networkError }

class PdfFetchLoader {
  static _PdfFetchLoaderDialogState? _dialogState;
  static BuildContext? _dialogContext;

  static void show(BuildContext context) {
    _dialogState = null;
    _dialogContext = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: _PdfFetchLoaderDialog(
          onStateReady: (state) {
            _dialogState = state;
            _dialogContext = dialogCtx;
          },
        ),
      ),
    ).then((_) {
      _dialogState = null;
      _dialogContext = null;
    });
  }

  /// Update progress (0.0 – 1.0) and optionally the stage message
  static void updateProgress(double value, {String? stage}) {
    _dialogState?.updateProgress(value, stage: stage);
  }

  static void dismiss(BuildContext context) {
    final ctx = _dialogContext ?? context;
    _dialogState = null;
    _dialogContext = null;
    try {
      if (Navigator.of(ctx, rootNavigator: true).canPop()) {
        Navigator.of(ctx, rootNavigator: true).pop();
      }
    } catch (_) {
      // Context might be disposed — safe to ignore
    }
  }

  static Future<void> showResult(
      BuildContext context, {required PdfFetchResult result, String? filePath}) async {
    if (_dialogState != null) {
      _dialogState!.showResult(result, filePath: filePath);
      final delay = result == PdfFetchResult.success
          ? const Duration(milliseconds: 2800)
          : const Duration(seconds: 2);
      await Future.delayed(delay);
    }
    if (context.mounted) dismiss(context);
  }
}

class _PdfFetchLoaderDialog extends StatefulWidget {
  final ValueChanged<_PdfFetchLoaderDialogState> onStateReady;
  const _PdfFetchLoaderDialog({required this.onStateReady});

  @override
  State<_PdfFetchLoaderDialog> createState() => _PdfFetchLoaderDialogState();
}

class _PdfFetchLoaderDialogState extends State<_PdfFetchLoaderDialog>
    with TickerProviderStateMixin {
  late final AnimationController _windController;
  late final AnimationController _cursorController;

  // Real progress driven by the caller
  double _progress = 0.0;

  // Messages cycle while a stage is active
  static const _idleMessages = [
    'Hang tight',
    'Working on it',
    'Getting things ready',
    'Just a moment',
    'Bear with us',
  ];

  String _currentStage = 'Connecting';
  int _idleIndex = 0;
  String _displayText = 'Connecting';
  bool _isFadingOut = false;
  Timer? _idleTimer;
  String? _resultMessage;
  bool _showCaption = true;

  @override
  void initState() {
    super.initState();
    widget.onStateReady(this);

    _windController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Cycle idle messages every 4.5s — slow enough to read, fast enough to feel alive
    _idleTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || _resultMessage != null) return;
      _cycleIdleMessage();
    });

    // Hide caption after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showCaption = false);
    });
  }

  void _cycleIdleMessage() {
    setState(() => _isFadingOut = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _resultMessage != null) return;
      _idleIndex = (_idleIndex + 1) % _idleMessages.length;
      setState(() {
        _displayText = _currentStage;
        _isFadingOut = false;
      });
      // After showing stage for 2.5s, show an idle quip
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted || _resultMessage != null) return;
        setState(() => _displayText = _idleMessages[_idleIndex]);
      });
    });
  }

  void updateProgress(double value, {String? stage}) {
    if (!mounted) return;
    setState(() {
      _progress = value.clamp(0.0, 1.0);
      if (stage != null) {
        _currentStage = stage;
        _displayText = stage;
      }
    });
  }

  void showResult(PdfFetchResult result, {String? filePath}) {
    _idleTimer?.cancel();
    setState(() {
      _progress = result == PdfFetchResult.success ? 1.0 : _progress;
      _isFadingOut = false;
      _resultMessage = switch (result) {
        PdfFetchResult.success => 'PDF saved to QRSnapify_PDFs folder',
        PdfFetchResult.timeout =>
          'Something went wrong. The site might be down.',
        PdfFetchResult.networkError =>
          'No internet. Check your connection.',
      };
      _displayText = _resultMessage!;
    });
  }

  @override
  void dispose() {
    _windController.dispose();
    _cursorController.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuccess = _resultMessage != null &&
        _resultMessage!.startsWith('PDF saved');
    final isError = _resultMessage != null && !isSuccess;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Wind animation background
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _windController,
                  builder: (context, _) => CustomPaint(
                    painter: WindPainter(
                      progress: _windController.value,
                      brightness: Theme.of(context).brightness,
                      primaryColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress line — real progress
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1.5),
                      child: SizedBox(
                        height: 3,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _progress),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          builder: (_, value, __) => LinearProgressIndicator(
                            value: value,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isError ? AppColors.error : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Result icon for success/error
                    if (_resultMessage != null) ...[
                      Icon(
                        isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: isSuccess ? AppColors.success : AppColors.error,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Animated message with blinking dots
                    SizedBox(
                      height: 48,
                      child: AnimatedOpacity(
                        opacity: _isFadingOut ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _displayText,
                                style: GoogleFonts.poppins(
                                  fontSize: _resultMessage != null ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                  color: isError
                                      ? AppColors.error
                                      : AppColors.textColor(context),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                              ),
                            ),
                            // Blinking dots while loading
                            if (_resultMessage == null)
                              FadeTransition(
                                opacity: _cursorController,
                                child: Text(
                                  '...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Caption
                    AnimatedOpacity(
                      opacity: _showCaption && _resultMessage == null ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        'Heavy sites take a bit longer',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSubColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
