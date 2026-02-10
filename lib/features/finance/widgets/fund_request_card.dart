import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

/// Card showing a fund request to the owner.
/// Follows the owner_approval_card.dart pattern.
/// Shows title, amount, urgency, project, status, owner response.
class FundRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isExpanded;
  final VoidCallback onTap;

  const FundRequestCard({
    super.key,
    required this.request,
    required this.isExpanded,
    required this.onTap,
  });

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  static final _dateFormat = DateFormat('dd MMM yyyy');

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningOrange;
      case 'approved':
        return AppTheme.successGreen;
      case 'denied':
        return AppTheme.errorRed;
      case 'partially_approved':
        return AppTheme.infoBlue;
      default:
        return Colors.grey;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'critical':
        return AppTheme.errorRed;
      case 'high':
        return AppTheme.warningOrange;
      case 'normal':
        return AppTheme.infoBlue;
      case 'low':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = request['title']?.toString() ?? '';
    final description = request['description']?.toString() ?? '';
    final amount = (request['amount'] as num?)?.toDouble() ?? 0;
    final approvedAmount = (request['approved_amount'] as num?)?.toDouble();
    final status = request['status']?.toString() ?? 'pending';
    final urgency = request['urgency']?.toString() ?? 'normal';
    final projectName = request['projects']?['name']?.toString() ?? '';
    final ownerName = request['users']?['full_name']?.toString() ?? 'Owner';
    final ownerResponse = request['owner_response']?.toString() ?? '';
    final createdAt = request['created_at']?.toString();
    final respondedAt = request['responded_at']?.toString();

    String createdLabel = '';
    if (createdAt != null) {
      try {
        createdLabel = _dateFormat.format(DateTime.parse(createdAt));
      } catch (_) {}
    }

    String respondedLabel = '';
    if (respondedAt != null) {
      try {
        respondedLabel = _dateFormat.format(DateTime.parse(respondedAt));
      } catch (_) {}
    }

    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isExpanded ? statusColor.withValues(alpha: 0.4) : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Collapsed content ──
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  // Left color indicator
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _urgencyColor(urgency),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  // Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            CategoryBadge(
                              text: urgency.toUpperCase(),
                              color: _urgencyColor(urgency),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (projectName.isNotEmpty) ...[
                              Icon(Icons.business, size: 12, color: AppTheme.textSecondary),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  projectName,
                                  style: AppTheme.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                            ],
                            Icon(Icons.person_outline, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                ownerName,
                                style: AppTheme.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  // Amount + status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CategoryBadge(
                        text: status.toUpperCase().replaceAll('_', ' '),
                        color: statusColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Date
            if (createdLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacingM + 12,
                  right: AppTheme.spacingM,
                  bottom: AppTheme.spacingS,
                ),
                child: Text(
                  'Requested: $createdLabel',
                  style: AppTheme.caption,
                ),
              ),

            // ── Expanded content ──
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (description.isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(description, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

                    // Approved amount (if partially approved)
                    if (approvedAmount != null && status == 'partially_approved') ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppTheme.infoBlue),
                            const SizedBox(width: AppTheme.spacingS),
                            Text(
                              'Approved: ${_currencyFormat.format(approvedAmount)} of ${_currencyFormat.format(amount)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.infoBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

                    // Owner response
                    if (ownerResponse.isNotEmpty) ...[
                      const Text(
                        'Owner Response',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundGrey,
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ownerResponse,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  if (respondedLabel.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Responded: $respondedLabel',
                                      style: AppTheme.caption,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
