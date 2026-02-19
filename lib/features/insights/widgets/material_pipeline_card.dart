import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/material_state.dart';

/// Card showing material pipeline stages at a glance.
class MaterialPipelineCard extends StatelessWidget {
  final MaterialPipeline state;
  final VoidCallback? onTap;

  const MaterialPipelineCard({
    super.key,
    required this.state,
    this.onTap,
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(state.projectName, style: AppTheme.headingSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (state.hasBOQ) ...[
                          const SizedBox(width: 8),
                          _buildBOQBadge(),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),

              const SizedBox(height: 16),

              // Pipeline visualization
              _buildPipeline(),

              // BOQ utilization (if BOQ exists)
              if (state.hasBOQ) ...[
                const SizedBox(height: 16),
                _buildBOQBar(),
              ],

              // Alerts
              if (state.alerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...state.alerts.take(2).map((alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            alert.severity == 'critical' ? Icons.error : Icons.warning_amber,
                            size: 14,
                            color: alert.severity == 'critical' ? AppTheme.errorRed : AppTheme.warningOrange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              alert.message,
                              style: TextStyle(
                                fontSize: 11,
                                color: alert.severity == 'critical' ? AppTheme.errorRed : AppTheme.warningOrange,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipeline() {
    final stages = [
      ('Requested', state.requested, const Color(0xFF9E9E9E)),
      ('Planned', state.planned, const Color(0xFF1565C0)),
      ('Ordered', state.ordered, const Color(0xFFEF6C00)),
      ('Delivered', state.delivered, const Color(0xFF2E7D32)),
      ('Installed', state.installed, const Color(0xFF1A237E)),
    ];

    return Row(
      children: stages.asMap().entries.map((entry) {
        final i = entry.key;
        final (label, count, color) = entry.value;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: count > 0 ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: count > 0 ? color : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: count > 0 ? color : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (i < stages.length - 1)
                Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade300),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBOQBadge() {
    final utilColor = state.boqUtilization > 100
        ? AppTheme.errorRed
        : state.boqUtilization > 80
            ? AppTheme.warningOrange
            : AppTheme.successGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: utilColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'BOQ ${state.boqUtilization.round()}%',
        style: TextStyle(fontSize: 10, color: utilColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBOQBar() {
    final util = state.boqUtilization.clamp(0, 150);
    final barColor = util > 100
        ? AppTheme.errorRed
        : util > 80
            ? AppTheme.warningOrange
            : AppTheme.successGreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('BOQ Consumption', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            Row(
              children: [
                if (state.boqItemsOverConsumed > 0)
                  Text(
                    '${state.boqItemsOverConsumed} over-consumed',
                    style: const TextStyle(fontSize: 10, color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(width: 8),
                Text('${util.round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (util / 100).clamp(0, 1),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
