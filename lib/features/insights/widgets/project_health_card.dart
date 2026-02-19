import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/project_state.dart';
import 'package:houzzdat_app/features/insights/widgets/health_score_indicator.dart';

/// Compact card showing project health at a glance.
class ProjectHealthCard extends StatelessWidget {
  final ProjectHealthState state;
  final VoidCallback? onTap;
  final VoidCallback? onSetupPlan;

  const ProjectHealthCard({
    super.key,
    required this.state,
    this.onTap,
    this.onSetupPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: score + name + schedule badge
              Row(
                children: [
                  HealthScoreIndicator(score: state.healthScore, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.projectName,
                          style: AppTheme.headingSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildHealthBadge(state.healthLabel, state.healthColor),
                            const SizedBox(width: 8),
                            if (state.hasPlan) _buildScheduleBadge(state.scheduleStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),

              const Divider(height: 24),

              // Metrics row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric(
                    '${state.completedTasks}/${state.totalTasks}',
                    'Tasks Done',
                    Icons.check_circle_outline,
                    AppTheme.successGreen,
                  ),
                  _buildMetric(
                    '${state.workersOnSiteToday}',
                    'On Site',
                    Icons.people_outline,
                    AppTheme.infoBlue,
                  ),
                  _buildMetric(
                    '${state.blockedTasks}',
                    'Blockers',
                    Icons.warning_amber_rounded,
                    state.blockedTasks > 0 ? AppTheme.errorRed : AppTheme.textSecondary,
                  ),
                  if (state.hasPlan)
                    _buildMetric(
                      '${state.actualProgress.round()}%',
                      'Progress',
                      Icons.trending_up,
                      state.progressVariance >= 0 ? AppTheme.successGreen : AppTheme.warningOrange,
                    ),
                ],
              ),

              // Progress vs Plan bar (if plan exists)
              if (state.hasPlan) ...[
                const SizedBox(height: 16),
                _buildProgressBar(),
              ],

              // Setup plan prompt if no plan
              if (!state.hasPlan && onSetupPlan != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onSetupPlan,
                  icon: const Icon(Icons.add_chart, size: 18),
                  label: const Text('Set Up Project Plan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryIndigo,
                    side: BorderSide(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildScheduleBadge(String status) {
    final config = {
      'ahead': (const Color(0xFF2E7D32), Icons.fast_forward, 'Ahead'),
      'on_track': (const Color(0xFF1565C0), Icons.check, 'On Track'),
      'behind': (const Color(0xFFEF6C00), Icons.schedule, 'Behind'),
      'critical': (const Color(0xFFD32F2F), Icons.error_outline, 'Critical'),
    };
    final (color, icon, label) = config[status] ?? (Colors.grey, Icons.help_outline, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: AppTheme.caption),
      ],
    );
  }

  Widget _buildProgressBar() {
    final planned = state.plannedProgress.clamp(0, 100);
    final actual = state.actualProgress.clamp(0, 100);
    final variance = state.progressVariance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Progress vs Plan', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            Text(
              variance >= 0 ? '+${variance.round()}%' : '${variance.round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: variance >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Planned progress bar (grey background)
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Planned marker
            FractionallySizedBox(
              widthFactor: planned / 100,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Actual progress bar
            FractionallySizedBox(
              widthFactor: actual / 100,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: variance >= 0 ? AppTheme.successGreen : AppTheme.warningOrange,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Planned ${planned.round()}%', style: AppTheme.caption),
              ],
            ),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: variance >= 0 ? AppTheme.successGreen : AppTheme.warningOrange, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Actual ${actual.round()}%', style: AppTheme.caption),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
