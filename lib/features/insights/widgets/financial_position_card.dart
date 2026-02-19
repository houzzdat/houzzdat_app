import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/financial_state.dart';

/// Card showing financial position at a glance.
class FinancialPositionCard extends StatelessWidget {
  final FinancialPosition state;
  final VoidCallback? onTap;

  const FinancialPositionCard({
    super.key,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = state.netPosition >= 0;

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
                    child: Text(
                      state.projectName,
                      style: AppTheme.headingSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),

              const SizedBox(height: 12),

              // Net position
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatCurrency(state.netPosition.abs()),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPositive ? 'Net Positive' : 'Net Negative',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Received vs Spent
              Row(
                children: [
                  Expanded(
                    child: _buildAmountChip(
                      'Received',
                      state.totalReceived,
                      AppTheme.successGreen,
                      Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAmountChip(
                      'Spent',
                      state.totalSpent,
                      AppTheme.errorRed,
                      Icons.arrow_upward,
                    ),
                  ),
                ],
              ),

              // Budget utilization bar
              if (state.hasBudget) ...[
                const SizedBox(height: 16),
                _buildBudgetBar(),
              ],

              // Alerts row
              if (state.overdueInvoices > 0 || state.pendingFundRequests > 0) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (state.overdueInvoices > 0)
                      _buildAlertChip(
                        '${state.overdueInvoices} overdue',
                        AppTheme.errorRed,
                      ),
                    if (state.pendingFundRequests > 0)
                      _buildAlertChip(
                        '${state.pendingFundRequests} fund requests',
                        AppTheme.warningOrange,
                      ),
                    if (state.pendingInvoices > 0)
                      _buildAlertChip(
                        '${state.pendingInvoices} pending invoices',
                        AppTheme.infoBlue,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountChip(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.caption),
          const SizedBox(height: 2),
          Text(
            _formatCurrency(amount),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetBar() {
    final util = state.budgetUtilization.clamp(0, 150);
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
            Text('Budget Utilization', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            Text(
              '${state.budgetUtilization.round()}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (util / 100).clamp(0, 1),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Budget: ${_formatCurrency(state.totalBudget)} · Spent: ${_formatCurrency(state.totalActualSpend)}',
          style: AppTheme.caption,
        ),
      ],
    );
  }

  Widget _buildAlertChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)} K';
    return amount.toStringAsFixed(0);
  }
}
