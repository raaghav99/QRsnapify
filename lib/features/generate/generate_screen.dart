import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/theme.dart';
import '../../shared/widgets/adaptive_button.dart';
import 'generate_controller.dart';

class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  final _qrKey = GlobalKey();
  final _scrollController = ScrollController();
  final _actionsKey = GlobalKey();
  bool _isSaving = false;
  bool _wasShowingQr = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final ctx = _qrKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.3, // keep QR in upper-third — shows input above & buttons below
        );
      }
    });
  }

  Future<Uint8List?> _captureQr() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    final state = ref.read(generateControllerProvider);
    if (!state.hasContent) return;

    setState(() => _isSaving = true);
    File? tempFile;
    try {
      final bytes = await _captureQr();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/qrsnap_save.png');
      await tempFile.writeAsBytes(bytes);
      await Gal.putImage(tempFile.path, album: 'QRSnap');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      tempFile?.delete().ignore(); // Clean up temp file
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _printQr() async {
    final bytes = await _captureQr();
    if (bytes == null) return;
    final image = pw.MemoryImage(bytes);
    await Printing.layoutPdf(
      onLayout: (_) async {
        final doc = pw.Document();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Image(image, width: 200, height: 200),
          ),
        ));
        return doc.save();
      },
    );
  }

  Future<void> _shareQr() async {
    final state = ref.read(generateControllerProvider);
    if (!state.hasContent) return;

    try {
      final bytes = await _captureQr();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qrsnap_share.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'QR Code from QRSnap');
      file.delete().ignore();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateControllerProvider);
    final controller = ref.read(generateControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Generate QR', style: AppTextStyles.subheading(context)),
        centerTitle: true,
        actions: [
          if (state.hasContent)
            IconButton(
              onPressed: _printQr,
              icon: const Icon(Icons.print_rounded, size: 22),
              tooltip: 'Print QR',
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + 64 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: GenerateType.values.map((type) {
                  final isSelected = state.selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(_typeLabel(type)),
                      selected: isSelected,
                      onSelected: (_) => controller.selectType(type),
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: AppColors.cardColor(context),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Gap(AppSpacing.lg),
            // Input fields — each type has its own form
            // Key forces rebuild when type changes so controllers reset
            KeyedSubtree(
              key: ValueKey(state.selectedType),
              child: _buildInputFields(context, state, controller),
            ),
            const Gap(AppSpacing.xl),
            // QR Preview
            if (state.hasContent) ...[
              Builder(builder: (_) {
                if (!_wasShowingQr) {
                  _wasShowingQr = true;
                  _scrollToActions();
                }
                return const SizedBox.shrink();
              }),
              Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.cardRadius,
                      boxShadow: const [AppShadows.card],
                    ),
                    child: QrImageView(
                      data: state.qrData,
                      version: QrVersions.auto,
                      size: 220,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
              ),
              const Gap(AppSpacing.xl),
              Row(
                key: _actionsKey,
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      label: 'Save',
                      icon: Iconsax.save_2,
                      isLoading: _isSaving,
                      onPressed: state.hasContent ? _saveToGallery : null,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: AdaptiveButton(
                      label: 'Share',
                      icon: Iconsax.send_2,
                      onPressed: state.hasContent ? _shareQr : null,
                      backgroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Builder(builder: (_) {
                _wasShowingQr = false;
                return const SizedBox.shrink();
              }),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.qr_code_2_rounded,
                            size: 52, color: Theme.of(context).colorScheme.primary),
                      ),
                      const Gap(AppSpacing.lg),
                      Text(
                        'Enter content above\nto generate a QR code',
                        style: AppTextStyles.body(context).copyWith(
                            color: AppColors.textSecondary, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputFields(
      BuildContext context, GenerateState state, GenerateController controller) {
    return switch (state.selectedType) {
      GenerateType.wifi => _MultiFieldForm(fields: [
          _FieldConfig(label: 'Network Name (SSID)', onChanged: controller.setSsid, initialValue: state.ssid),
          _FieldConfig(label: 'Password', onChanged: controller.setPassword, obscure: true, initialValue: state.password),
          _FieldConfig(
            label: 'Security',
            onChanged: controller.setSecurity,
            isDropdown: true,
            dropdownItems: ['WPA', 'WEP', 'nopass'],
            dropdownValue: state.security,
          ),
        ]),
      GenerateType.sms => _MultiFieldForm(fields: [
          _FieldConfig(
            label: 'Phone Number',
            onChanged: controller.setSmsPhone,
            keyboard: TextInputType.phone,
            initialValue: state.smsPhone,
          ),
          _FieldConfig(label: 'Message', onChanged: controller.setSmsBody, maxLines: 3, initialValue: state.smsBody),
        ]),
      GenerateType.upi => _MultiFieldForm(fields: [
          _FieldConfig(label: 'UPI ID (e.g. name@upi)', onChanged: controller.setUpiVpa, initialValue: state.upiVpa),
          _FieldConfig(label: 'Payee Name', onChanged: controller.setUpiName, initialValue: state.upiName),
          _FieldConfig(
            label: 'Amount (optional)',
            onChanged: controller.setUpiAmount,
            keyboard: TextInputType.number,
            initialValue: state.upiAmount,
          ),
        ]),
      GenerateType.whatsapp => _MultiFieldForm(fields: [
          _FieldConfig(
            label: 'Phone Number (with country code)',
            onChanged: controller.setWaPhone,
            keyboard: TextInputType.phone,
            initialValue: state.waPhone,
          ),
          _FieldConfig(
            label: 'Pre-filled Message (optional)',
            onChanged: controller.setWaMessage,
            maxLines: 3,
            initialValue: state.waMessage,
          ),
        ]),
      GenerateType.vcard => _MultiFieldForm(fields: [
          _FieldConfig(label: 'Full Name', onChanged: controller.setVcardName, initialValue: state.vcardName),
          _FieldConfig(
            label: 'Phone',
            onChanged: controller.setVcardPhone,
            keyboard: TextInputType.phone,
            initialValue: state.vcardPhone,
          ),
          _FieldConfig(
            label: 'Email',
            onChanged: controller.setVcardEmail,
            keyboard: TextInputType.emailAddress,
            initialValue: state.vcardEmail,
          ),
          _FieldConfig(label: 'Organization (optional)', onChanged: controller.setVcardOrg, initialValue: state.vcardOrg),
        ]),
      GenerateType.geo => _MultiFieldForm(fields: [
          _FieldConfig(
            label: 'Latitude (e.g. 28.6139)',
            onChanged: controller.setGeoLat,
            keyboard: TextInputType.numberWithOptions(signed: true, decimal: true),
            initialValue: state.geoLat,
          ),
          _FieldConfig(
            label: 'Longitude (e.g. 77.2090)',
            onChanged: controller.setGeoLng,
            keyboard: TextInputType.numberWithOptions(signed: true, decimal: true),
            initialValue: state.geoLng,
          ),
          _FieldConfig(label: 'Label (optional)', onChanged: controller.setGeoLabel, initialValue: state.geoLabel),
        ]),
      GenerateType.url => _SimpleField(
          hint: 'https://example.com',
          onChanged: controller.setUrlInput,
          keyboard: TextInputType.url,
          maxLines: 1,
          initialValue: state.urlInput,
        ),
      GenerateType.text => _SimpleField(
          hint: 'Enter your text here...',
          onChanged: controller.setTextInput,
          keyboard: TextInputType.text,
          maxLines: 4,
          initialValue: state.textInput,
        ),
      GenerateType.email => _SimpleField(
          hint: 'email@example.com',
          onChanged: controller.setEmailInput,
          keyboard: TextInputType.emailAddress,
          maxLines: 1,
          initialValue: state.emailInput,
        ),
      GenerateType.phone => _SimpleField(
          hint: '+1 234 567 8900',
          onChanged: controller.setPhoneInput,
          keyboard: TextInputType.phone,
          maxLines: 1,
          initialValue: state.phoneInput,
        ),
    };
  }

  String _typeLabel(GenerateType type) => switch (type) {
    GenerateType.url => 'URL',
    GenerateType.text => 'Text',
    GenerateType.email => 'Email',
    GenerateType.phone => 'Phone',
    GenerateType.sms => 'SMS',
    GenerateType.wifi => 'WiFi',
    GenerateType.upi => 'UPI',
    GenerateType.whatsapp => 'WhatsApp',
    GenerateType.vcard => 'Contact',
    GenerateType.geo => 'Location',
  };

  String _hintText(GenerateType type) => switch (type) {
    GenerateType.url => 'https://example.com',
    GenerateType.text => 'Enter your text here...',
    GenerateType.email => 'email@example.com',
    GenerateType.phone => '+1 234 567 8900',
    _ => '',
  };

  TextInputType _keyboardType(GenerateType type) => switch (type) {
    GenerateType.phone => TextInputType.phone,
    GenerateType.email => TextInputType.emailAddress,
    GenerateType.url => TextInputType.url,
    _ => TextInputType.text,
  };
}

// ── QR action button (icon + label, no overflow) ─────────────────────────────

class _QrActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool isLoading;

  const _QrActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: color, strokeWidth: 2),
                      ),
                    )
                  : Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field config for multi-field forms ────────────────────────────────────────

class _FieldConfig {
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType keyboard;
  final int maxLines;
  final bool obscure;
  final bool isDropdown;
  final List<String>? dropdownItems;
  final String? dropdownValue;
  final String initialValue;

  const _FieldConfig({
    required this.label,
    required this.onChanged,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
    this.obscure = false,
    this.isDropdown = false,
    this.dropdownItems,
    this.dropdownValue,
    this.initialValue = '',
  });
}

// ── Simple single text field ──────────────────────────────────────────────────

class _SimpleField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType keyboard;
  final int maxLines;
  final String initialValue;

  const _SimpleField({
    required this.hint,
    required this.onChanged,
    required this.keyboard,
    required this.maxLines,
    this.initialValue = '',
  });

  @override
  State<_SimpleField> createState() => _SimpleFieldState();
}

class _SimpleFieldState extends State<_SimpleField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLength: 2953,
      decoration: _inputDecoration(context, widget.hint),
      keyboardType: widget.keyboard,
      maxLines: widget.maxLines,
    );
  }
}

// ── Multi-field form (WiFi, SMS, UPI, etc.) ───────────────────────────────────

class _MultiFieldForm extends StatefulWidget {
  final List<_FieldConfig> fields;
  const _MultiFieldForm({required this.fields});

  @override
  State<_MultiFieldForm> createState() => _MultiFieldFormState();
}

class _MultiFieldFormState extends State<_MultiFieldForm> {
  late final List<TextEditingController> _controllers;
  final Map<int, bool> _obscured = {};

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.fields.length,
      (i) => TextEditingController(text: widget.fields[i].initialValue),
    );
    for (var i = 0; i < widget.fields.length; i++) {
      if (widget.fields[i].obscure) _obscured[i] = true;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.fields.asMap().entries.map((entry) {
        final i = entry.key;
        final field = entry.value;

        if (field.isDropdown) {
          return Padding(
            padding: EdgeInsets.only(bottom: i < widget.fields.length - 1 ? AppSpacing.md : 0),
            child: DropdownButtonFormField<String>(
              value: field.dropdownValue,
              items: (field.dropdownItems ?? [])
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v != null) field.onChanged(v);
              },
              decoration: _inputDecoration(context, field.label, isLabel: true),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: i < widget.fields.length - 1 ? AppSpacing.md : 0),
          child: TextField(
            controller: _controllers[i],
            onChanged: field.onChanged,
            keyboardType: field.keyboard,
            maxLines: field.obscure ? 1 : field.maxLines,
            obscureText: _obscured[i] ?? false,
            decoration: _inputDecoration(context, field.label, isLabel: true).copyWith(
              suffixIcon: field.obscure
                  ? IconButton(
                      icon: Icon(
                        (_obscured[i] ?? false) ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscured[i] = !(_obscured[i] ?? false)),
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared input decoration ──────────────────────────────────────────────────

InputDecoration _inputDecoration(BuildContext context, String hint, {bool isLabel = false}) {
  return InputDecoration(
    hintText: isLabel ? null : hint,
    labelText: isLabel ? hint : null,
    filled: true,
    fillColor: AppColors.cardColor(context),
    border: OutlineInputBorder(
      borderRadius: AppRadius.cardRadius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.cardRadius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.cardRadius,
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.all(AppSpacing.lg),
  );
}
