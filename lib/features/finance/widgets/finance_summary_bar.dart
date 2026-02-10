import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Horizontal row of 4 summary metric cards for the Site Finances tab.
/// Shows: Total Invoiced, Total Paid, Pending, Overdue.
class FinanceSummaryBar extends StatelessWidget {
  final double totalInvoiced;
  final double totalPaid;
  final double totalPending;
  final double totalOverdue;

  const FinanceSummaryBar({
    super.key,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalPending,
    required this.totalOverdue,
  });

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryCard(
              label: 'Total Invoiced',
              amount: totalInvoiced,
              icon: Icons.receipt_long_rounded,
              color: AppTheme.infoBlue,
            ),
            const SizedBox(width: AppTheme.spacingS),
            _SummaryCard(
              label: 'Total Paid',
              amount: totalPaid,
              icon: Icons.check_circle_rounded,
              color: AppTheme.successGreen,
            ),
            const SizedBox(width: AppTheme.spacingS),
            _SummaryCard(
              label: 'Pending',
              amount: totalPending,
              icon: Icons.hourglass_top_rounded,
              color: AppTheme.warningOrange,
            ),
            const SizedBox(width: AppTheme.spacingS),
            _SummaryCard(
              label: 'Overdue',
              amount: totalOverdue,
              icon: Icons.warning_amber_rounded,
              color: AppTheme.errorRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            FinanceSummaryBar._currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
