import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../app/theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        boxShadow: const [AppShadows.card],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Iconsax.scan,
                label: 'Scan',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Iconsax.document,
                label: 'Generate',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Iconsax.clock,
                label: 'History',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = isActive ? primary : AppColors.textSubColor(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon with active pill background
            Container(
              width: 40,
              height: 28,
              decoration: isActive
                  ? BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Center(
                child: Icon(
                  icon, // always outline — no icon switching = no shifting
                  color: color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500, // constant weight — no layout shift
              ),
            ),
          ],
        ),
      ),
    );
  }
}
