import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final VoidCallback onCentralMicTap;
  final bool isRecording;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCentralMicTap,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Stack(
            children: [
              // Bottom nav items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.checklist_rounded,
                    label: 'Actions',
                    isActive: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                  _NavItem(
                    icon: Icons.business_rounded,
                    label: 'Sites',
                    isActive: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                  ),
                  const SizedBox(width: 80), // Space for FAB
                  _NavItem(
                    icon: Icons.people_rounded,
                    label: 'Users',
                    isActive: currentIndex == 3,
                    onTap: () => onTabSelected(3),
                  ),
                  _NavItem(
                    icon: Icons.feed_rounded,
                    label: 'Feed',
                    isActive: currentIndex == 4,
                    onTap: () => onTabSelected(4),
                  ),
                ],
              ),
              
              // Central FAB
              Positioned(
                left: MediaQuery.of(context).size.width / 2 - 32,
                top: -16, // Raised above the bar
                child: GestureDetector(
                  onTap: onCentralMicTap,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isRecording ? AppTheme.errorRed : AppTheme.accentAmber,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
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