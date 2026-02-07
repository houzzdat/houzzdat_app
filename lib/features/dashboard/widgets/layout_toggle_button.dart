import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/dashboard_settings_service.dart';
import 'package:houzzdat_app/features/dashboard/widgets/layout_settings_dialog.dart';

/// Quick toggle button for switching dashboard layouts
/// Can be placed in AppBar actions or as a floating button
class LayoutToggleButton extends StatelessWidget {
  final bool showLabel;
  final ButtonStyle? style;

  const LayoutToggleButton({
    super.key,
    this.showLabel = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final settingsService = DashboardSettingsService();
    
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, child) {
        final isKanban = settingsService.isKanbanMode;
        
        if (showLabel) {
          return TextButton.icon(
            onPressed: () => _showLayoutDialog(context),
            icon: Icon(
              isKanban 
                  ? Icons.view_kanban_rounded 
                  : Icons.view_list_rounded,
            ),
            label: Text(
              isKanban ? 'Kanban' : 'Classic',
            ),
            style: style,
          );
        }
        
        return IconButton(
          onPressed: () => _showLayoutDialog(context),
          icon: Icon(
            isKanban 
                ? Icons.view_kanban_rounded 
                : Icons.view_list_rounded,
          ),
          tooltip: 'Change layout (${isKanban ? 'Kanban' : 'Classic'})',
        );
      },
    );
  }

  Future<void> _showLayoutDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const LayoutSettingsDialog(),
    );
  }
}

/// Alternative: Compact toggle switch (no dialog)
class LayoutQuickToggle extends StatelessWidget {
  const LayoutQuickToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = DashboardSettingsService();
    
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, child) {
        final isKanban = settingsService.isKanbanMode;
        
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToggleOption(
                icon: Icons.view_list_rounded,
                label: 'Classic',
                isActive: !isKanban,
                onTap: () async {
                  await settingsService.setLayout(DashboardLayout.classic);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Switched to Classic View'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 4),
              _ToggleOption(
                icon: Icons.view_kanban_rounded,
                label: 'Kanban',
                isActive: isKanban,
                onTap: () async {
                  await settingsService.setLayout(DashboardLayout.kanban);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Switched to Kanban View'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppTheme.primaryIndigo : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: isActive ? AppTheme.primaryIndigo : Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}