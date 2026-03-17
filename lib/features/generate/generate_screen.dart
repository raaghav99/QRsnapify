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
  final _inputController = TextEditingController();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _inputController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    try {
      final bytes = await _captureQr();
      if (bytes == null) return;

      // Write to temp file then save to gallery via MediaStore (visible in gallery app)
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/qrsnap_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Gal.putImage(file.path, album: 'QRSnap');

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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareQr() async {
    final state = ref.read(generateControllerProvider);
    if (!state.hasContent) return;

    final bytes = await _captureQr();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/qrsnap_share.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'QR Code from QRSnap');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateControllerProvider);
    final controller = ref.read(generateControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Generate QR', style: AppTextStyles.subheading(context)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
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
                      onSelected: (_) {
                        controller.selectType(type);
                        _inputController.clear();
                        _ssidController.clear();
                        _passwordController.clear();
                      },
                      selectedColor: AppColors.primary,
                      // Explicit bg so dark-mode chip surface is correct
                      backgroundColor: AppColors.cardColor(context),
                      labelStyle: TextStyle(
                        // colorScheme.onSurface is always contrast-correct for
                        // the active theme (light text on dark, dark on light)
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      checkmarkColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
            const Gap(AppSpacing.lg),
            // Input fields
            if (state.selectedType == GenerateType.wifi)
              _WifiFields(
                ssidController: _ssidController,
                passwordController: _passwordController,
                security: state.security,
                onSsidChanged: controller.setSsid,
                onPasswordChanged: controller.setPassword,
                onSecurityChanged: controller.setSecurity,
              )
            else
              TextField(
                controller: _inputController,
                onChanged: controller.setInput,
                maxLength: 2953,
                decoration: InputDecoration(
                  hintText: _hintText(state.selectedType),
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
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                ),
                keyboardType: _keyboardType(state.selectedType),
                maxLines: state.selectedType == GenerateType.text ? 4 : 1,
              ),
            const Gap(AppSpacing.xl),
            // QR Preview
            if (state.hasContent) ...[
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
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      label: 'Save',
                      icon: Iconsax.save_2,
                      isLoading: _isSaving,
                      onPressed: state.hasContent ? _saveToGallery : null,
                      backgroundColor: AppColors.primary,
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
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded,
                            size: 52, color: AppColors.primary),
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
        ),
      ),
    );
  }

  String _typeLabel(GenerateType type) => switch (type) {
    GenerateType.url => 'URL',
    GenerateType.text => 'Text',
    GenerateType.email => 'Email',
    GenerateType.phone => 'Phone',
    GenerateType.wifi => 'WiFi',
  };

  String _hintText(GenerateType type) => switch (type) {
    GenerateType.url => 'https://example.com',
    GenerateType.text => 'Enter your text here...',
    GenerateType.email => 'email@example.com',
    GenerateType.phone => '+1 234 567 8900',
    GenerateType.wifi => '',
  };

  TextInputType _keyboardType(GenerateType type) => switch (type) {
    GenerateType.phone => TextInputType.phone,
    GenerateType.email => TextInputType.emailAddress,
    GenerateType.url => TextInputType.url,
    _ => TextInputType.text,
  };
}

class _WifiFields extends StatefulWidget {
  final TextEditingController ssidController;
  final TextEditingController passwordController;
  final String security;
  final ValueChanged<String> onSsidChanged;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onSecurityChanged;

  const _WifiFields({
    required this.ssidController,
    required this.passwordController,
    required this.security,
    required this.onSsidChanged,
    required this.onPasswordChanged,
    required this.onSecurityChanged,
  });

  @override
  State<_WifiFields> createState() => _WifiFieldsState();
}

class _WifiFieldsState extends State<_WifiFields> {
  bool _obscurePassword = true;

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.ssidController,
          onChanged: widget.onSsidChanged,
          decoration: _fieldDecoration('Network Name (SSID)'),
        ),
        const Gap(AppSpacing.md),
        TextField(
          controller: widget.passwordController,
          onChanged: widget.onPasswordChanged,
          obscureText: _obscurePassword,
          decoration: _fieldDecoration('Password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        DropdownButtonFormField<String>(
          value: widget.security,
          items: ['WPA', 'WEP', 'nopass']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            if (v != null) widget.onSecurityChanged(v);
          },
          decoration: _fieldDecoration('Security'),
        ),
      ],
    );
  }
}
