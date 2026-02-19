import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/project_state.dart';
import 'package:houzzdat_app/features/insights/widgets/health_score_indicator.dart';
import 'package:houzzdat_app/features/insights/widgets/progress_vs_plan_widget.dart';

/// Full-screen drill-down for a single project's health state.
class ProjectHealthDetail extends StatelessWidget {
  final ProjectHealthState state;
  final VoidCallback? onSetupPlan;

  const ProjectHealthDetail({
    super.key,
    required this.state,
    this.onSetupPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(state.projectName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Health score hero section
            _buildHeroSection(),

            // Metrics grid
            _buildMetricsGrid(),

            // Timeline info
            if (state.hasPlan) _buildTimelineCard(),

            // Progress vs Plan
            if (state.hasPlan) ...[
              _buildSectionHeader('PROGRESS VS PLAN'),
              ProgressVsPlanWidget(
                milestones: state.milestones,
                plannedProgress: state.plannedProgress,
                actualProgress: state.actualProgress,
              ),
            ] else ...[
              _buildNoPlanCard(),
            ],

            // Top blockers
            if (state.topBlockers.isNotEmpty) ...[
              _buildSectionHeader('TOP BLOCKERS'),
              ...state.topBlockers.map(_buildBlockerRow),
            ],

            // Activity section
            _buildSectionHeader('ACTIVITY'),
            _buildActivityCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          HealthScoreIndicator(score: state.healthScore, size: 96, strokeWidth: 8),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Health label badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.healthColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: state.healthColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    state.healthLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: state.healthColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Schedule status
                if (state.hasPlan)
                  _buildScheduleBadge(state.scheduleStatus),
                const SizedBox(height: 8),
                // Trend
                Row(
                  children: [
                    Icon(
                      state.trend == 'improving'
                          ? Icons.trending_up
                          : state.trend == 'declining'
                              ? Icons.trending_down
                              : Icons.trending_flat,
                      size: 18,
                      color: state.trend == 'improving'
                          ? AppTheme.successGreen
                          : state.trend == 'declining'
                              ? AppTheme.errorRed
                              : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${state.trend[0].toUpperCase()}${state.trend.substring(1)}',
                      style: AppTheme.bodySmall,
                    ),
                    if (state.trendDelta != 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${state.trendDelta > 0 ? '+' : ''}${state.trendDelta})',
                        style: TextStyle(
                          fontSize: 12,
                          color: state.trendDelta > 0 ? AppTheme.successGreen : AppTheme.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBadge(String status) {
    final config = {
      'ahead': (AppTheme.successGreen, Icons.fast_forward, 'Ahead of Schedule'),
      'on_track': (AppTheme.infoBlue, Icons.check, 'On Track'),
      'behind': (AppTheme.warningOrange, Icons.schedule, 'Behind Schedule'),
      'critical': (AppTheme.errorRed, Icons.error_outline, 'Critical Delay'),
    };
    final (color, icon, label) = config[status] ?? (Colors.grey, Icons.help_outline, status);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('Tasks Done', '${state.completedTasks}/${state.totalTasks}',
              Icons.check_circle_outline, AppTheme.successGreen)),
          const SizedBox(width: 8),
          Expanded(child: _buildMetricCard('Blockers', '${state.blockedTasks}',
              Icons.warning_amber, state.blockedTasks > 0 ? AppTheme.errorRed : AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: _buildMetricCard('Overdue', '${state.overdueTasks}',
              Icons.schedule, state.overdueTasks > 0 ? AppTheme.warningOrange : AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: _buildMetricCard('On Site', '${state.workersOnSiteToday}/${state.totalWorkers}',
              Icons.people_outline, AppTheme.infoBlue)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryIndigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.plannedStartDate != null && state.plannedEndDate != null)
                  Text(
                    '${dateFormat.format(state.plannedStartDate!)} - ${dateFormat.format(state.plannedEndDate!)}',
                    style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${state.daysElapsed} days elapsed, ${state.daysRemaining} days remaining',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          // Milestone counts
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${state.milestonesCompleted}/${state.milestonesTotal}',
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.successGreen),
              ),
              Text('milestones', style: AppTheme.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlanCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.add_chart, size: 40, color: AppTheme.primaryIndigo.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('No Project Plan', style: AppTheme.headingSmall),
          const SizedBox(height: 4),
          Text(
            'Upload milestones and timeline to track progress vs plan',
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (onSetupPlan != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSetupPlan,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Set Up Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockerRow(BlockerItem blocker) {
    final priorityColor = blocker.priority == 'Critical' ? AppTheme.errorRed : AppTheme.warningOrange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: priorityColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blocker.summary,
                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(blocker.priority,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(blocker.createdAt),
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildActivityMetric(Icons.mic, '${state.voiceNotesToday}', 'Notes Today', AppTheme.primaryIndigo),
          _divider(),
          _buildActivityMetric(Icons.people, '${state.workersOnSiteToday}', 'On Site', AppTheme.successGreen),
          _divider(),
          _buildActivityMetric(
            Icons.access_time,
            state.daysSinceLastActivity == 0 ? 'Today' : '${state.daysSinceLastActivity}d',
            'Last Active',
            state.daysSinceLastActivity > 2 ? AppTheme.warningOrange : AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMetric(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: AppTheme.caption.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      )),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
