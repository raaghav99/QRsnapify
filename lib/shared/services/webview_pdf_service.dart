import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/pdf_fetch_loader.dart';
import '../widgets/debug_overlay.dart';

/// Pushes as a full-screen route.
/// Calls native Android to render the URL in a WebView and export PDF
/// via createPrintDocumentAdapter — same pipeline Chrome uses.
/// Pops with the saved file path on success, null on failure/cancel.
class WebViewPdfCapturePage extends StatefulWidget {
  final String url;
  const WebViewPdfCapturePage({super.key, required this.url});

  @override
  State<WebViewPdfCapturePage> createState() => _WebViewPdfCapturePageState();
}

class _WebViewPdfCapturePageState extends State<WebViewPdfCapturePage> {
  static const _channel = MethodChannel('qrsnap/pdf');

  bool _isAborted = false;
  Timer? _progressTimer;
  double _fakeProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PdfFetchLoader.show(context);
        _startFakeProgress();
        _generate();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  // Slowly animate progress 0 → 0.80 while native WebView works
  void _startFakeProgress() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_isAborted || !mounted) return;
      if (_fakeProgress < 0.80) {
        _fakeProgress += 0.013;
        final stage = _fakeProgress < 0.25
            ? 'Loading page'
            : _fakeProgress < 0.55
                ? 'Rendering'
                : 'Generating PDF';
        PdfFetchLoader.updateProgress(_fakeProgress.clamp(0.0, 0.80), stage: stage);
      }
    });
  }

  Future<void> _generate() async {
    try {
      DebugLogger.log('generatePdf → ${widget.url}');

      // Native side: loads URL in Android WebView, renders to bitmap,
      // slices into PDF pages, returns cache path
      final tempPath = await _channel.invokeMethod<String>(
        'generatePdf',
        {'url': widget.url},
      );

      _progressTimer?.cancel();
      DebugLogger.log('Native done: $tempPath');

      if (tempPath == null || !mounted || _isAborted) return;

      // Copy from Android cache to app's external storage (no permission needed, persists)
      PdfFetchLoader.updateProgress(0.90, stage: 'Saving');
      final extDir = await getExternalStorageDirectory();
      final baseDir = extDir ?? await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${baseDir.path}/QRSnap_PDFs');
      if (!pdfDir.existsSync()) pdfDir.createSync(recursive: true);
      if (!pdfDir.existsSync()) pdfDir.createSync(recursive: true);
      final fileName = _pdfFileName(widget.url);
      final savedFile = File('${pdfDir.path}/$fileName');
      await File(tempPath).copy(savedFile.path);
      // Delete the temp cache file
      try { File(tempPath).deleteSync(); } catch (_) {}
      DebugLogger.log('Saved to: ${savedFile.path}');

      if (!mounted || _isAborted) return;

      // showResult() calls dismiss() internally — do NOT call dismiss() again
      // or it will pop the page without the return value (button won't change)
      await PdfFetchLoader.showResult(
        context,
        result: PdfFetchResult.success,
        filePath: fileName,
      );

      if (mounted && !_isAborted) Navigator.of(context).pop(savedFile.path);
    } on PlatformException catch (e) {
      _progressTimer?.cancel();
      DebugLogger.log('PlatformException [${e.code}]: ${e.message}');
      _abort();
    } catch (e) {
      _progressTimer?.cancel();
      DebugLogger.log('Error: $e');
      _abort();
    }
  }

  String _pdfFileName(String url) {
    return 'QRSnap_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }


  void _abort() async {
    if (_isAborted) return;
    _isAborted = true;
    if (!mounted) return;
    await PdfFetchLoader.showResult(context, result: PdfFetchResult.timeout);
    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.01),
      body: const SizedBox.shrink(),
    );
    return PopScope(
      canPop: false,
      child: kDebugOverlayEnabled ? DebugOverlay(child: scaffold) : scaffold,
    );
  }
}
