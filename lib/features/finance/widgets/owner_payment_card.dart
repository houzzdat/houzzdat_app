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

    String dateLabel = '';
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        dateLabel = _dateFormat.format(DateTime.parse(dateStr));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isConfirmed
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : const Color(0xFFE0E0E0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
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
    );
  }
}
