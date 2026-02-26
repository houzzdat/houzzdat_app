import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/models/models.dart';

/// A compact metric card for the 4 strategic KPIs:
/// RUNWAY | CRITICAL BLOCKERS | VALUE DELIVERED | FORECAST CONFIDENCE
class RunwayMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isAlert;

  const RunwayMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isAlert = false,
  });

  factory RunwayMetricCard.runway(PhaseHealthMetrics metrics) {
    final zone = metrics.runwayZone;
    final color = zone == RunwayZone.green
        ? AppTheme.successGreen
        : zone == RunwayZone.amber
            ? AppTheme.warningOrange
            : AppTheme.errorRed;

    return RunwayMetricCard(
      title: 'RUNWAY',
      value: '${metrics.runwayDays}d',
      subtitle: metrics.nextGateName != null
          ? 'to ${metrics.nextGateName}'
          : 'no active phase',
      icon: LucideIcons.gauge,
      color: color,
      isAlert: zone == RunwayZone.red,
    );
  }

  factory RunwayMetricCard.blockers(PhaseHealthMetrics metrics) {
    return RunwayMetricCard(
      title: 'BLOCKERS',
      value: '${metrics.criticalBlockers}',
      subtitle: metrics.criticalBlockers == 0 ? 'all clear' : 'need attention',
      icon: LucideIcons.alertOctagon,
      color: metrics.criticalBlockers == 0 ? AppTheme.successGreen : AppTheme.errorRed,
      isAlert: metrics.criticalBlockers > 0,
    );
  }

  factory RunwayMetricCard.valueDelivered(PhaseHealthMetrics metrics) {
    final pct = metrics.valueDeliveredPercent.round();
    return RunwayMetricCard(
      title: 'VALUE',
      value: '$pct%',
      subtitle: 'delivered this month',
      icon: LucideIcons.trendingUp,
      color: pct >= 70
          ? AppTheme.successGreen
          : pct >= 40
              ? AppTheme.warningOrange
              : AppTheme.errorRed,
    );
  }

  factory RunwayMetricCard.forecast(PhaseHealthMetrics metrics) {
    final pct = metrics.forecastConfidencePercent.round();
    return RunwayMetricCard(
      title: 'FORECAST',
      value: '$pct%',
      subtitle: 'on-time confidence',
      icon: LucideIcons.barChart2,
      color: pct >= 80
          ? AppTheme.successGreen
          : pct >= 60
              ? AppTheme.warningOrange
              : AppTheme.errorRed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? color.withValues(alpha: 0.5) : Colors.grey[200]!,
          width: isAlert ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
