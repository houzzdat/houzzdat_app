import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Theme.of(context).cardColor,
      elevation: 8,
      padding: EdgeInsets.zero, // fix 3px overflow — remove default M3 internal padding
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.checklist_rounded,
              label: 'Actions',
              isActive: currentIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            _NavItem(
              icon: Icons.insights,
              label: 'Insights',
              isActive: currentIndex == 1,
              onTap: () => onTabSelected(1),
            ),
            const SizedBox(width: 60), // Space for FAB
            _NavItem(
              icon: Icons.people_rounded,
              label: 'Users',
              isActive: currentIndex == 3,
              onTap: () => onTabSelected(3),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Finance',
              isActive: currentIndex == 4,
              onTap: () => onTabSelected(4),
            ),
            _NavItem(
              icon: LucideIcons.folderOpen,
              label: 'Docs',
              isActive: currentIndex == 5,
              onTap: () => onTabSelected(5),
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: 4, // tighter to fit 60dp bar without overflow
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.primaryIndigo : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: isActive ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}