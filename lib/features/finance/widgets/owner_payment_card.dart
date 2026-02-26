import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

/// Card showing a payment received from the owner.
/// Displays owner name, amount, method, date, allocated site, confirmed status.
class OwnerPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback? onConfirm;

  const OwnerPaymentCard({
    super.key,
    required this.payment,
    this.onConfirm,
  });

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final ownerName = payment['users']?['full_name']?.toString() ?? 'Owner';
    final method = payment['payment_method']?.toString() ?? '';
    final ref = payment['reference_number']?.toString() ?? '';
    final description = payment['description']?.toString() ?? '';
    final projectName = payment['projects']?['name']?.toString() ?? '';
    final dateStr = payment['received_date']?.toString();
    final isConfirmed = payment['confirmed_by'] != null;

    // UX-audit PP-08: Parse confirmed audit trail
    final confirmedByName = payment['confirmed_by_user']?['full_name']?.toString()
        ?? payment['confirmed_by']?.toString();
    String? confirmedAtLabel;
    final confirmedAtStr = payment['confirmed_at']?.toString();
    if (confirmedAtStr != null && confirmedAtStr.isNotEmpty) {
      try {
        confirmedAtLabel = _dateFormat.format(DateTime.parse(confirmedAtStr));
      } catch (e) {
        debugPrint('Error parsing confirmed_at: $e');
      }
    }

    String dateLabel = '';
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        dateLabel = _dateFormat.format(DateTime.parse(dateStr));
      } catch (e) {
        debugPrint('Error parsing payment date: $e');
      }
    }

    // UX-audit #19: standardized Card elevation instead of custom BoxShadow
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      elevation: AppTheme.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        side: BorderSide(
          color: isConfirmed
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : AppTheme.dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Owner avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                child: Text(
                  ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'O',
                  style: const TextStyle(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ownerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isConfirmed)
                          const CategoryBadge(
                            text: 'CONFIRMED',
                            color: AppTheme.successGreen,
                            icon: Icons.check_circle,
                          )
                        else
                          const CategoryBadge(
                            text: 'UNCONFIRMED',
                            color: AppTheme.warningOrange,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (projectName.isNotEmpty)
                      Text(
                        'Allocated to: $projectName',
                        style: AppTheme.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),

          // Amount + method + date row
          Row(
            children: [
              Text(
                _currencyFormat.format(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              if (method.isNotEmpty)
                CategoryBadge(
                  text: method.replaceAll('_', ' ').toUpperCase(),
                  color: AppTheme.primaryIndigo,
                ),
              const Spacer(),
              if (dateLabel.isNotEmpty)
                Text(dateLabel, style: AppTheme.caption),
            ],
          ),

          // Reference
          if (ref.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Ref: $ref', style: AppTheme.caption),
          ],

          // Description
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // UX-audit PP-08: Confirmed audit trail (who confirmed and when)
          if (isConfirmed && (confirmedByName != null || confirmedAtLabel != null)) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified_user, size: 14,
                    color: AppTheme.successGreen.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      if (confirmedByName != null) 'Confirmed by $confirmedByName',
                      if (confirmedAtLabel != null) 'on $confirmedAtLabel',
                    ].join(' '),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.successGreen.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Confirm button
          if (!isConfirmed && onConfirm != null) ...[
            const SizedBox(height: AppTheme.spacingS),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirm'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
