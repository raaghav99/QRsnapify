import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../models/scan_result.dart';
import '../../shared/widgets/qr_result_sheet.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _selectedIds = {};
  bool _selectMode = false;
  bool _showFavouritesOnly = false;
  bool _hasAnimated = false;

  void _enterSelectMode(String id) {
    setState(() {
      _selectMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<ScanResult> items) {
    setState(() {
      _selectedIds.addAll(items.map((e) => e.id));
    });
  }

  Future<void> _deleteSelected(HistoryController controller) async {
    final ids = Set<String>.from(_selectedIds);
    _exitSelectMode();
    await controller.deleteMany(ids);
  }

  @override
  Widget build(BuildContext context) {
    // Reset favourites filter when the last favourite is removed
    ref.listen(historyProvider, (_, next) {
      next.whenData((items) {
        if (_showFavouritesOnly && !items.any((e) => e.isFavourite)) {
          setState(() => _showFavouritesOnly = false);
        }
      });
    });

    final historyAsync = ref.watch(historyProvider);
    final controller = ref.read(historyControllerProvider);

    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectMode) _exitSelectMode();
      },
      child: Scaffold(
        appBar: _selectMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _exitSelectMode,
                ),
                title: Text(
                  '${_selectedIds.length} selected',
                  style: AppTextStyles.subheading(context),
                ),
                actions: [
                  historyAsync.whenOrNull(
                    data: (items) {
                      final visible = _showFavouritesOnly
                          ? items.where((e) => e.isFavourite).toList()
                          : items;
                      return TextButton(
                        onPressed: _selectedIds.length == visible.length
                            ? _exitSelectMode
                            : () => _selectAll(visible),
                        child: Text(
                          _selectedIds.length == visible.length
                              ? 'Deselect all'
                              : 'Select all',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      );
                    },
                  ) ?? const SizedBox.shrink(),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded,
                        color: AppColors.error),
                    tooltip: 'Delete selected',
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => _deleteSelected(controller),
                  ),
                ],
              )
            : AppBar(
                title: Text('History',
                    style: AppTextStyles.subheading(context)),
                centerTitle: true,
                actions: [
                  if (historyAsync.valueOrNull?.isNotEmpty == true)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded),
                      tooltip: 'Clear all',
                      onPressed: () =>
                          _confirmClearAll(context, controller),
                    ),
                ],
              ),
        body: historyAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset(
                      'assets/lottie/empty_history.json',
                      width: 200,
                      height: 200,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.history_rounded,
                        size: 80,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    Text('No scans yet',
                        style: AppTextStyles.subheading(context)
                            .copyWith(
                                color: AppColors.textSubColor(context))),
                    const Gap(AppSpacing.sm),
                    Text('Start scanning to see your history here',
                        style: AppTextStyles.caption(context)),
                  ],
                ),
              );
            }

            final hasFavourites = items.any((e) => e.isFavourite);
            final filtered = _showFavouritesOnly
                ? items.where((e) => e.isFavourite).toList()
                : items;

            return Column(
              children: [
                // Filter toggle — only show if there are favourites
                if (hasFavourites && !_selectMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: !_showFavouritesOnly,
                          onTap: () => setState(() => _showFavouritesOnly = false),
                        ),
                        const Gap(AppSpacing.sm),
                        _FilterChip(
                          label: 'Favourites',
                          isSelected: _showFavouritesOnly,
                          onTap: () => setState(() => _showFavouritesOnly = true),
                        ),
                      ],
                    ),
                  ),
                // Empty favourites state
                if (_showFavouritesOnly && filtered.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.star,
                              size: 56,
                              color: AppColors.textSubColor(context)),
                          const Gap(AppSpacing.lg),
                          Text('No favourites yet',
                              style: AppTextStyles.subheading(context)
                                  .copyWith(
                                      color: AppColors.textSubColor(context))),
                          const Gap(AppSpacing.sm),
                          Text('Tap the star on any scan to save it here',
                              style: AppTextStyles.caption(context)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = _selectedIds.contains(item.id);
                        final shouldAnimate = !_hasAnimated;
                        if (index == filtered.length - 1) _hasAnimated = true;
                        return _HistoryItem(
                          item: item,
                          index: index,
                          selectMode: _selectMode,
                          isSelected: isSelected,
                          animate: shouldAnimate,
                          onDelete: () => controller.delete(item.id),
                          onToggleFavourite: () =>
                              controller.toggleFavourite(item.id),
                          onTap: () {
                            if (_selectMode) {
                              _toggleItem(item.id);
                            } else {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) =>
                                    QrResultSheet(result: item),
                              );
                            }
                          },
                          onLongPress: () {
                            if (!_selectMode) _enterSelectMode(item.id);
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : AppColors.textSubColor(context).withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSubColor(context),
          ),
        ),
      ),
    );
  }
}

// ─── History item ─────────────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  final ScanResult item;
  final int index;
  final bool selectMode;
  final bool isSelected;
  final bool animate;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavourite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HistoryItem({
    required this.item,
    required this.index,
    required this.selectMode,
    required this.isSelected,
    this.animate = true,
    required this.onDelete,
    required this.onToggleFavourite,
    required this.onTap,
    required this.onLongPress,
  });

  IconData _typeIcon(QRType type) => switch (type) {
        QRType.url => Iconsax.link,
        QRType.email => Iconsax.message,
        QRType.phone => Iconsax.call,
        QRType.wifi => Iconsax.wifi,
        QRType.text => Iconsax.document_text,
        QRType.upi => Iconsax.wallet_money,
      };

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : AppColors.cardColor(context),
          borderRadius: AppRadius.cardRadius,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), width: 1.5)
              : null,
          boxShadow: const [AppShadows.card],
        ),
        child: Row(
          children: [
            // Checkbox in select mode, type icon otherwise
            if (selectMode)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Checkbox(
                  key: ValueKey(isSelected),
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.chipRadius,
                ),
                child:
                    Icon(_typeIcon(item.type), color: Theme.of(context).colorScheme.primary, size: 18),
              ),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.content,
                    style: AppTextStyles.body(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Text(_formatDate(item.scannedAt),
                      style: AppTextStyles.caption(context)),
                ],
              ),
            ),
            // Star + delete in normal mode
            if (!selectMode) ...[
              GestureDetector(
                onTap: onToggleFavourite,
                child: Icon(
                  item.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: item.isFavourite
                      ? const Color(0xFFFBBF24)
                      : AppColors.textSubColor(context),
                  size: 22,
                ),
              ),
              const Gap(AppSpacing.sm),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 20),
              ),
            ],
          ],
        ),
      ),
    );

    // Swipe-to-delete only works in normal mode
    if (selectMode) {
      final widget = card;
      return animate
          ? widget.animate(delay: Duration(milliseconds: math.min(50 * index, 300)))
              .fadeIn(duration: 250.ms)
              .slideX(begin: 0.1, duration: 250.ms)
          : widget;
    }

    final dismissible = Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadius.cardRadius,
        ),
        child: const Icon(Iconsax.trash, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: card,
    );
    return animate
        ? dismissible.animate(delay: Duration(milliseconds: math.min(50 * index, 300)))
            .fadeIn(duration: 250.ms)
            .slideX(begin: 0.1, duration: 250.ms)
        : dismissible;
  }
}

// ─── Clear all dialog ─────────────────────────────────────────────────────────

void _confirmClearAll(BuildContext context, HistoryController controller) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clear History'),
      content:
          const Text('Delete all scan history? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            controller.deleteAll();
          },
          child: const Text('Delete All',
              style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
}
