import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Opens the color wheel dialog; returns selected color or null if cancelled
  Future<Color?> _pickColor(BuildContext context, Color initial) async {
    Color picked = initial;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pick a colour'),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: picked,
                  onColorChanged: (c) => setDialogState(() => picked = c),
                  colorPickerWidth: 280,
                  pickerAreaHeightPercent: 0.7,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: const [],
                  pickerAreaBorderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 12),
                // Quick-pick preset dots
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPresetColors.map((c) {
                    final isActive = picked.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () => setDialogState(() => picked = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? AppColors.textColor(ctx)
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isActive
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    return confirmed == true ? picked : null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.subheading(context)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Appearance',
              style: AppTextStyles.caption(context)
                  .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.md),

          // ── App colour ──────────────────────────────────────────────────────
          _SectionCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              title: Text('App colour',
                  style: AppTextStyles.body(context)
                      .copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Tap to open colour wheel',
                  style: AppTextStyles.caption(context)),
              trailing: GestureDetector(
                onTap: () async {
                  final color = await _pickColor(context, settings.selectedColor);
                  if (color != null) notifier.selectColor(color);
                },
                child: _ColorDot(color: primary, size: 40, selected: false, showRing: false),
              ),
              onTap: () async {
                final color = await _pickColor(context, settings.selectedColor);
                if (color != null) notifier.selectColor(color);
              },
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Weekly colours ──────────────────────────────────────────────────
          _SectionCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Weekly colours',
                      style: AppTextStyles.body(context)
                          .copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Set a different colour for each day',
                      style: AppTextStyles.caption(context)),
                  value: settings.weeklyColorsEnabled,
                  onChanged: (_) {
                    notifier.toggleWeeklyColors();
                  },
                  activeColor: primary,
                ),

                if (settings.weeklyColorsEnabled) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ...List.generate(7, (i) {
                    final weekday = i + 1;
                    final argb = settings.weeklyMap[weekday];
                    final dayColor = argb != null ? Color(argb) : null;
                    final isToday = DateTime.now().weekday == weekday;

                    return Column(
                      children: [
                        InkWell(
                          onTap: () async {
                            final color = await _pickColor(
                                context, dayColor ?? settings.selectedColor);
                            if (color != null) {
                              notifier.setDayColor(weekday, color);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    _dayNames[i],
                                    style: AppTextStyles.body(context).copyWith(
                                      fontWeight: isToday
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isToday ? primary : null,
                                    ),
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Today',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: primary,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                                const Spacer(),
                                if (dayColor != null) ...[
                                  _ColorDot(color: dayColor, size: 24, selected: false, showRing: false),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => notifier.setDayColor(weekday, null),
                                    child: Icon(Icons.close_rounded,
                                        size: 16,
                                        color: AppColors.textSubColor(context)),
                                  ),
                                ] else
                                  Text('—',
                                      style: AppTextStyles.caption(context)),
                                const SizedBox(width: 4),
                                Icon(Icons.color_lens_outlined,
                                    size: 18,
                                    color: AppColors.textSubColor(context)),
                              ],
                            ),
                          ),
                        ),
                        if (i < 6)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Colour dot ────────────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool selected;
  final bool showRing;

  const _ColorDot({
    required this.color,
    required this.size,
    required this.selected,
    required this.showRing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: showRing && selected
            ? Border.all(color: AppColors.textColor(context), width: 2.5)
            : Border.all(color: Colors.transparent, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }
}

// ── Shared card container ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
