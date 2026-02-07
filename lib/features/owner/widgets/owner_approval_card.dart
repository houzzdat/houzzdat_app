import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

class OwnerApprovalCard extends StatelessWidget {
  final Map<String, dynamic> approval;
  final VoidCallback? onApprove;
  final VoidCallback? onDeny;
  final VoidCallback? onAddNote;

  const OwnerApprovalCard({
    super.key,
    required this.approval,
    this.onApprove,
    this.onDeny,
    this.onAddNote,
  });

  Color _getCategoryColor() {
    switch (approval['category']) {
      case 'spending': return AppTheme.warningOrange;
      case 'design_change': return AppTheme.infoBlue;
      case 'material_change': return AppTheme.primaryIndigo;
      case 'schedule_change': return AppTheme.errorRed;
      default: return AppTheme.textSecondary;
    }
  }

  String _getCategoryLabel() {
    switch (approval['category']) {
      case 'spending': return 'SPENDING';
      case 'design_change': return 'DESIGN CHANGE';
      case 'material_change': return 'MATERIAL CHANGE';
      case 'schedule_change': return 'SCHEDULE CHANGE';
      default: return 'OTHER';
    }
  }

  Color _getStatusColor() {
    switch (approval['status']) {
      case 'approved': return AppTheme.successGreen;
      case 'denied': return AppTheme.errorRed;
      case 'deferred': return AppTheme.warningOrange;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = approval['status'] ?? 'pending';
    final isPending = status == 'pending';
    final amount = approval['amount'];
    final currency = approval['currency'] ?? 'INR';
    final requestedByName = approval['requested_by_name'] ?? 'Manager';
    final projectName = approval['project_name'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      elevation: AppTheme.elevationLow,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        approval['title'] ?? 'Approval Request',
                        style: AppTheme.headingSmall,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Wrap(
                        spacing: AppTheme.spacingS,
                        runSpacing: AppTheme.spacingXS,
                        children: [
                          CategoryBadge(
                            text: _getCategoryLabel(),
                            color: _getCategoryColor(),
                          ),
                          CategoryBadge(
                            text: status.toUpperCase(),
                            color: _getStatusColor(),
                            icon: status == 'approved'
                                ? Icons.check_circle
                                : status == 'denied'
                                    ? Icons.cancel
                                    : Icons.pending,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (amount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(color: AppTheme.accentAmber.withValues(alpha:0.3)),
                    ),
                    child: Text(
                      '$currency ${amount.toStringAsFixed(0)}',
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.warningOrange,
                      ),
                    ),
                  ),
              ],
            ),
            if (approval['description'] != null) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                approval['description'],
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'By $requestedByName',
                  style: AppTheme.caption,
                ),
                if (projectName.isNotEmpty) ...[
                  const SizedBox(width: AppTheme.spacingM),
                  Icon(Icons.business, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: AppTheme.spacingXS),
                  Expanded(
                    child: Text(
                      projectName,
                      style: AppTheme.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (approval['owner_response'] != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.reply, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        approval['owner_response'],
                        style: AppTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('APPROVE', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onApprove,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.note_add, size: 16),
                      label: const Text('ADD NOTE', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.infoBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onAddNote,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('DENY', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onDeny,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
