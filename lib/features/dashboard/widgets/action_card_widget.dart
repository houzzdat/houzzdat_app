import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

class ActionCardWidget extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onInstruct;
  final VoidCallback onForward;

  const ActionCardWidget({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onInstruct,
    required this.onForward,
  });

  Color _getCategoryColor() {
    switch (item['category']) {
      case 'action_required':
        return AppTheme.errorRed;
      case 'approval':
        return AppTheme.warningOrange;
      case 'update':
        return AppTheme.successGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = item['status'] ?? 'pending';
    final priority = item['priority']?.toString() ?? 'Med';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: PriorityIndicator(priority: priority),
            title: Text(
              item['summary'] ?? 'Action Item',
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTheme.spacingXS),
                CategoryBadge(
                  text: 'Priority: $priority',
                  color: _getCategoryColor(),
                ),
                if (item['ai_analysis'] != null && item['ai_analysis'].toString().isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    item['ai_analysis'],
                    style: AppTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppTheme.spacingXS),
                CategoryBadge(
                  text: 'Status: $status',
                  color: status == 'approved' ? AppTheme.successGreen : AppTheme.textSecondary,
                  icon: status == 'approved' ? Icons.check_circle : Icons.pending,
                ),
              ],
            ),
          ),
          if (status == 'pending') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive layout: column on small screens, row on larger
                  if (constraints.maxWidth < 400) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildActionButton(
                          label: 'Approve',
                          icon: Icons.check_circle,
                          color: AppTheme.successGreen,
                          onPressed: onApprove,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        _buildActionButton(
                          label: 'Instruct',
                          icon: Icons.mic,
                          color: AppTheme.infoBlue,
                          onPressed: onInstruct,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        _buildActionButton(
                          label: 'Forward',
                          icon: Icons.forward,
                          color: AppTheme.warningOrange,
                          onPressed: onForward,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Approve',
                          icon: Icons.check_circle,
                          color: AppTheme.successGreen,
                          onPressed: onApprove,
                          isCompact: true,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Instruct',
                          icon: Icons.mic,
                          color: AppTheme.infoBlue,
                          onPressed: onInstruct,
                          isCompact: true,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Forward',
                          icon: Icons.forward,
                          color: AppTheme.warningOrange,
                          onPressed: onForward,
                          isCompact: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isCompact = false,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: isCompact ? 16 : 18),
      label: Text(
        label,
        style: TextStyle(fontSize: isCompact ? 12 : 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? AppTheme.spacingS : AppTheme.spacingM,
        ),
      ),
      onPressed: onPressed,
    );
  }
}