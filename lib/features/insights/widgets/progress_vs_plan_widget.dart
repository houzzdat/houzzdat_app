import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/project_state.dart';

/// Milestone timeline showing planned bars vs actual bars per milestone.
class ProgressVsPlanWidget extends StatelessWidget {
  final List<MilestoneSnapshot> milestones;
  final double plannedProgress;
  final double actualProgress;

  const ProgressVsPlanWidget({
    super.key,
    required this.milestones,
    required this.plannedProgress,
    required this.actualProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No milestones defined yet',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final variance = actualProgress - plannedProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall progress summary
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Overall Progress',
                      style: AppTheme.headingSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (variance >= 0 ? AppTheme.successGreen : AppTheme.errorRed)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      variance >= 0 ? '+${variance.round()}%' : '${variance.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: variance >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Dual progress bars
              _buildDualBar('Planned', plannedProgress, Colors.grey.shade400),
              const SizedBox(height: 8),
              _buildDualBar(
                'Actual',
                actualProgress,
                variance >= 0 ? AppTheme.successGreen : AppTheme.warningOrange,
              ),
            ],
          ),
        ),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('MILESTONES', style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          )),
        ),

        // Milestone list
        ...milestones.map(_buildMilestoneRow),
      ],
    );
  }

  Widget _buildDualBar(String label, double progress, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (progress / 100).clamp(0, 1),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${progress.round()}%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneRow(MilestoneSnapshot ms) {
    final statusConfig = _getStatusConfig(ms.status);
    final dateFormat = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + Status badge + Weight
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusConfig.$2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(statusConfig.$1, size: 16, color: statusConfig.$2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ms.name,
                      style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusConfig.$3,
                      style: TextStyle(fontSize: 11, color: statusConfig.$2, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Weight badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${ms.weightPercent.round()}%',
                  style: const TextStyle(fontSize: 10, color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Planned vs Actual date bars
          Row(
            children: [
              // Planned dates
              Expanded(
                child: _buildDateRow(
                  'Planned',
                  ms.plannedStart != null ? dateFormat.format(ms.plannedStart!) : '--',
                  ms.plannedEnd != null ? dateFormat.format(ms.plannedEnd!) : '--',
                  Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 12),
              // Actual dates
              Expanded(
                child: _buildDateRow(
                  'Actual',
                  ms.actualStart != null ? dateFormat.format(ms.actualStart!) : '--',
                  ms.actualEnd != null ? dateFormat.format(ms.actualEnd!) : '--',
                  ms.delayDays > 0 ? AppTheme.errorRed : AppTheme.successGreen,
                ),
              ),
            ],
          ),

          // Delay indicator
          if (ms.delayDays > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 12, color: AppTheme.errorRed),
                  const SizedBox(width: 4),
                  Text(
                    '${ms.delayDays} day${ms.delayDays == 1 ? '' : 's'} delayed',
                    style: const TextStyle(fontSize: 11, color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, String start, String end, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          '$start - $end',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  (IconData, Color, String) _getStatusConfig(String status) {
    switch (status) {
      case 'completed':
        return (Icons.check_circle, AppTheme.successGreen, 'Completed');
      case 'in_progress':
        return (Icons.sync, AppTheme.infoBlue, 'In Progress');
      case 'delayed':
        return (Icons.warning_amber, AppTheme.errorRed, 'Delayed');
      case 'not_started':
      default:
        return (Icons.circle_outlined, AppTheme.textSecondary, 'Not Started');
    }
  }
}
