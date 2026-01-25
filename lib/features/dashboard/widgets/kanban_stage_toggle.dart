import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/tabs/actions_kanban_tab.dart';

class KanbanStageToggle extends StatelessWidget {
  final KanbanStage currentStage;
  final Function(KanbanStage) onStageChanged;

  const KanbanStageToggle({
    super.key,
    required this.currentStage,
    required this.onStageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: const BoxDecoration(
        color: AppTheme.primaryIndigo,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _StageButton(
              icon: Icons.error_outline_rounded,
              label: 'QUEUE',
              isActive: currentStage == KanbanStage.queue,
              onTap: () => onStageChanged(KanbanStage.queue),
            ),
            _StageButton(
              icon: Icons.construction_rounded,
              label: 'ACTIVE',
              isActive: currentStage == KanbanStage.active,
              onTap: () => onStageChanged(KanbanStage.active),
            ),
            _StageButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'LOGS',
              isActive: currentStage == KanbanStage.logs,
              onTap: () => onStageChanged(KanbanStage.logs),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _StageButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingM,
          ),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppTheme.primaryIndigo : Colors.white,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: isActive ? AppTheme.primaryIndigo : Colors.white,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}