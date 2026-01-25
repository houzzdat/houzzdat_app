import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/dashboard_settings_service.dart';

/// Dialog to switch between Classic and Kanban layouts
class LayoutSettingsDialog extends StatefulWidget {
  const LayoutSettingsDialog({super.key});

  @override
  State<LayoutSettingsDialog> createState() => _LayoutSettingsDialogState();
}

class _LayoutSettingsDialogState extends State<LayoutSettingsDialog> {
  final _settingsService = DashboardSettingsService();
  late DashboardLayout _selectedLayout;

  @override
  void initState() {
    super.initState();
    _selectedLayout = _settingsService.currentLayout;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: AppTheme.primaryIndigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard Layout',
                        style: AppTheme.headingMedium,
                      ),
                      Text(
                        'Choose your preferred view',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Layout Options
            _LayoutOption(
              layout: DashboardLayout.classic,
              isSelected: _selectedLayout == DashboardLayout.classic,
              onTap: () {
                setState(() => _selectedLayout = DashboardLayout.classic);
              },
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            _LayoutOption(
              layout: DashboardLayout.kanban,
              isSelected: _selectedLayout == DashboardLayout.kanban,
              onTap: () {
                setState(() => _selectedLayout = DashboardLayout.kanban);
              },
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                      ),
                    ),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _settingsService.setLayout(_selectedLayout);
                      if (context.mounted) {
                        Navigator.pop(context, true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Switched to ${_selectedLayout.displayName}',
                            ),
                            backgroundColor: AppTheme.successGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryIndigo,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                      ),
                    ),
                    child: const Text('APPLY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  final DashboardLayout layout;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.layout,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryIndigo.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryIndigo
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryIndigo
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(
                layout.icon,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            
            const SizedBox(width: AppTheme.spacingM),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        layout.displayName,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppTheme.primaryIndigo
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: AppTheme.spacingS),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryIndigo,
                            borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: AppTheme.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    layout.description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryIndigo
                      : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? AppTheme.primaryIndigo : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}