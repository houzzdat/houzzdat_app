import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

/// Compact payment card widget.
/// Shows amount, payment method badge, date, reference number, paid to.
class PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const PaymentCard({super.key, required this.payment});

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final method = payment['payment_method']?.toString() ?? '';
    final dateStr = payment['payment_date']?.toString();
    final ref = payment['reference_number']?.toString() ?? '';
    final paidTo = payment['paid_to']?.toString() ?? '';
    final description = payment['description']?.toString() ?? '';
    final projectName = payment['projects']?['name']?.toString() ?? '';

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
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
        children: [
          // Left icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: const Icon(
              Icons.payment_rounded,
              color: AppTheme.successGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _currencyFormat.format(amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    if (method.isNotEmpty)
                      CategoryBadge(
                        text: method.replaceAll('_', ' ').toUpperCase(),
                        color: AppTheme.primaryIndigo,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (paidTo.isNotEmpty)
                      Flexible(
                        child: Text(
                          paidTo,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (paidTo.isNotEmpty && projectName.isNotEmpty)
                      const Text(' \u2022 ', style: TextStyle(color: AppTheme.textSecondary)),
                    if (projectName.isNotEmpty)
                      Flexible(
                        child: Text(
                          projectName,
                          style: AppTheme.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (ref.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ref: $ref',
                    style: AppTheme.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTheme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Date
          if (dateLabel.isNotEmpty)
            Text(
              dateLabel,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w500),
            ),
        ],
      ),
      ),
    );
  }
}
