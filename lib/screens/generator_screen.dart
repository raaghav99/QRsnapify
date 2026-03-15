import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import '../widgets/adaptive_button.dart';

enum QrType { url, text, email, phone }

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  QrType _selectedType = QrType.url;
  final _controller = TextEditingController();
  final _qrKey = GlobalKey();
  bool _saving = false;

  /// Debounced QR data — updated 350 ms after the user stops typing to avoid
  /// re-encoding the QR matrix on every keystroke.
  String _debouncedQrData = '';
  Timer? _debounce;

  String get _hint => switch (_selectedType) {
        QrType.url => 'https://example.com',
        QrType.text => 'Enter any text',
        QrType.email => 'hello@example.com',
        QrType.phone => '+1 555 000 0000',
      };

  /// Live QR data used at save time (no debounce needed there).
  String get _qrData {
    final val = _controller.text.trim();
    if (val.isEmpty) return '';
    return switch (_selectedType) {
      QrType.email => val.startsWith('mailto:') ? val : 'mailto:$val',
      QrType.phone => val.startsWith('tel:') ? val : 'tel:$val',
      _ => val,
    };
  }

  void _onTextChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _debouncedQrData = _qrData);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate QR')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kSubtitle,
                ),
              ),
              const SizedBox(height: 10),
              _TypeSelector(
                selected: _selectedType,
                onChanged: (t) => setState(() {
                  _selectedType = t;
                  _controller.clear();
                  _debouncedQrData = '';
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                onChanged: _onTextChanged,
                keyboardType: switch (_selectedType) {
                  QrType.url => TextInputType.url,
                  QrType.email => TextInputType.emailAddress,
                  QrType.phone => TextInputType.phone,
                  _ => TextInputType.text,
                },
                decoration: InputDecoration(
                  hintText: _hint,
                  prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 28),
              if (_debouncedQrData.isNotEmpty) ...[
                Center(
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(kCardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _debouncedQrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: kSurface,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: kOnBackground,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: kOnBackground,
                        ),
                      ),
                    ),
                  ).animate().scale(duration: kAnimNormal),
                ),
                const SizedBox(height: 24),
                AdaptiveButton(
                  label: _saving ? 'Saving…' : 'Save & Share',
                  icon: Icons.share_outlined,
                  onPressed: _saving ? null : _saveAndShare,
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndShare() async {
    setState(() => _saving = true);
    try {
      final ctx = _qrKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qrsnap_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR code generated with QRSnap',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save QR code. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final QrType selected;
  final ValueChanged<QrType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<QrType>(
      segments: const [
        ButtonSegment(value: QrType.url, label: Text('URL'), icon: Icon(Icons.link_outlined, size: 16)),
        ButtonSegment(value: QrType.text, label: Text('Text'), icon: Icon(Icons.text_fields_outlined, size: 16)),
        ButtonSegment(value: QrType.email, label: Text('Email'), icon: Icon(Icons.email_outlined, size: 16)),
        ButtonSegment(value: QrType.phone, label: Text('Phone'), icon: Icon(Icons.phone_outlined, size: 16)),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kButtonRadius)),
        ),
      ),
    );
  }
}
