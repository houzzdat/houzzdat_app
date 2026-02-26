import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  // UX-audit PP-04: Format responded_at timestamp for audit trail
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return isoDate;
    }
  }

  /// UX-audit PP-09: Split bar showing approved vs deferred portion
  Widget _buildPartialApprovalBar({
    required double totalAmount,
    required double approvedAmount,
    required String currency,
  }) {
    final deferredAmount = totalAmount - approvedAmount;
    final approvedFraction = totalAmount > 0 ? (approvedAmount / totalAmount).clamp(0.0, 1.0) : 0.0;

    // Only show if there's a meaningful split (not 100% approved or 100% deferred)
    if (approvedFraction >= 1.0 || approvedFraction <= 0.0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Partial Approval',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          // Split bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Flexible(
                    flex: (approvedFraction * 100).round(),
                    child: Container(color: AppTheme.successGreen),
                  ),
                  Flexible(
                    flex: ((1 - approvedFraction) * 100).round(),
                    child: Container(color: AppTheme.warningOrange.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Labels
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.successGreen)),
              const SizedBox(width: 4),
              Text(
                'Approved: $currency ${approvedAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.successGreen),
              ),
              const Spacer(),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.warningOrange.withValues(alpha: 0.6))),
              const SizedBox(width: 4),
              Text(
                'Deferred: $currency ${deferredAmount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.warningOrange.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = approval['status'] ?? 'pending';
    final isPending = status == 'pending';
    final amount = approval['amount'];
    final currency = approval['currency'] ?? 'INR';
    final requestedByName = approval['requested_by_name'] ?? 'Manager';
    final projectName = approval['project_name'] ?? '';

    // UX-audit #17: Swipe-to-approve/deny for pending cards
    if (isPending) {
      return Dismissible(
        key: Key('approval-${approval['id'] ?? approval.hashCode}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd && onApprove != null) {
            HapticFeedback.mediumImpact();
            onApprove!();
            return false; // Let the callback handle state change
          } else if (direction == DismissDirection.endToStart && onDeny != null) {
            HapticFeedback.mediumImpact();
            onDeny!();
            return false;
          }
          return false;
        },
        background: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            color: AppTheme.successGreen,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            color: AppTheme.errorRed,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Deny', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 8),
              Icon(Icons.cancel, color: Colors.white, size: 28),
            ],
          ),
        ),
        child: _buildCardContent(
          status: status,
          isPending: isPending,
          amount: amount,
          currency: currency,
          requestedByName: requestedByName,
          projectName: projectName,
        ),
      );
    }

    return _buildCardContent(
      status: status,
      isPending: isPending,
      amount: amount,
      currency: currency,
      requestedByName: requestedByName,
      projectName: projectName,
    );
  }

  Widget _buildCardContent({
    required String status,
    required bool isPending,
    required dynamic amount,
    required String currency,
    required String requestedByName,
    required String projectName,
  }) {
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
            // UX-audit PP-09: Partial approval split bar visualization
            if (!isPending && amount != null && approval['approved_amount'] != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              _buildPartialApprovalBar(
                totalAmount: (amount as num).toDouble(),
                approvedAmount: (approval['approved_amount'] as num).toDouble(),
                currency: currency,
              ),
            ],
            if (approval['owner_response'] != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    // UX-audit PP-04: Show responded_at timestamp for audit trail
                    if (approval['responded_at'] != null) ...[
                      const SizedBox(height: AppTheme.spacingXS),
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Text(
                          'Responded: ${_formatDate(approval['responded_at'].toString())}',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
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
                      onPressed: onApprove != null ? () {
                        HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
                        onApprove!();
                      } : null,
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
                      onPressed: onDeny != null ? () {
                        HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
                        onDeny!();
                      } : null,
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
