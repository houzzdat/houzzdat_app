import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class OwnerProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final int pendingCount;
  final int inProgressCount;
  final int completedCount;
  final VoidCallback onTap;

  const OwnerProjectCard({
    super.key,
    required this.project,
    required this.pendingCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = project['name'] ?? 'Untitled Site';
    final location = project['location'] ?? '';
    final totalActions = pendingCount + inProgressCount + completedCount;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      elevation: AppTheme.elevationLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryIndigo,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTheme.headingSmall,
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            style: AppTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  _StatChip(
                    label: 'Pending',
                    count: pendingCount,
                    color: AppTheme.warningOrange,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  _StatChip(
                    label: 'Active',
                    count: inProgressCount,
                    color: AppTheme.infoBlue,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  _StatChip(
                    label: 'Done',
                    count: completedCount,
                    color: AppTheme.successGreen,
                  ),
                  const Spacer(),
                  Text(
                    '$totalActions total',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Text(
        '$count $label',
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
