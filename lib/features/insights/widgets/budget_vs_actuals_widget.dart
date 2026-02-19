import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/financial_state.dart';

/// Budget vs Actuals visualization with stacked horizontal bars per category.
class BudgetVsActualsWidget extends StatelessWidget {
  final FinancialPosition state;

  const BudgetVsActualsWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.hasBudget) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No budget uploaded yet',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Budget summary card
        _buildSummaryCard(),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('BY CATEGORY', style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          )),
        ),

        // Category bars
        ...state.budgetByCategory.keys.map(_buildCategoryBar),

        // Line item variances
        if (state.lineItemVariances.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('LINE ITEMS', style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            )),
          ),
          ...state.lineItemVariances.map(_buildLineItemRow),
        ],
      ],
    );
  }

  Widget _buildSummaryCard() {
    final utilColor = state.budgetUtilization > 100
        ? AppTheme.errorRed
        : state.budgetUtilization > 80
            ? AppTheme.warningOrange
            : AppTheme.successGreen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budget Overview', style: AppTheme.headingSmall),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: utilColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _budgetStatusLabel(state.budgetStatus),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: utilColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Budget / Spent / Remaining row
          Row(
            children: [
              Expanded(child: _buildAmountBlock('Budget', state.totalBudget, AppTheme.textPrimary)),
              Expanded(child: _buildAmountBlock('Spent', state.totalActualSpend, utilColor)),
              Expanded(
                child: _buildAmountBlock(
                  'Remaining',
                  state.budgetVariance,
                  state.budgetVariance >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Utilization bar
          _buildUtilizationBar(state.budgetUtilization, utilColor),
        ],
      ),
    );
  }

  Widget _buildAmountBlock(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(amount.abs()),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildUtilizationBar(double util, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Utilization', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            Text('${util.round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (util / 100).clamp(0, 1),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryBar(String category) {
    final budgeted = state.budgetByCategory[category] ?? 0;
    final actual = state.spendByCategory[category] ?? 0;
    final utilization = budgeted > 0 ? (actual / budgeted * 100) : 0.0;
    final barColor = utilization > 100
        ? AppTheme.errorRed
        : utilization > 80
            ? AppTheme.warningOrange
            : AppTheme.successGreen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatCategoryLabel(category),
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${utilization.round()}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dual bars: budget (outline) vs actual (filled)
          Stack(
            children: [
              // Budget bar (outline)
              Container(
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // Actual bar (filled)
              FractionallySizedBox(
                widthFactor: budgeted > 0 ? (actual / budgeted).clamp(0, 1) : 0,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budget: ${_formatCurrency(budgeted)}', style: AppTheme.caption),
              Text('Spent: ${_formatCurrency(actual)}',
                  style: AppTheme.caption.copyWith(color: barColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemRow(BudgetLineVariance item) {
    final utilColor = item.utilizationPercent > 100
        ? AppTheme.errorRed
        : item.utilizationPercent > 80
            ? AppTheme.warningOrange
            : AppTheme.successGreen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: utilColor),
          ),
          const SizedBox(width: 10),
          // Item name + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.lineItem,
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatCategoryLabel(item.category),
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          // Amounts
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(item.actual),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: utilColor),
              ),
              Text(
                'of ${_formatCurrency(item.budgeted)}',
                style: AppTheme.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)} K';
    return amount.toStringAsFixed(0);
  }

  String _formatCategoryLabel(String category) {
    return category.replaceAll('_', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _budgetStatusLabel(String status) {
    switch (status) {
      case 'under_budget': return 'Under Budget';
      case 'on_budget': return 'On Budget';
      case 'over_budget': return 'Over Budget';
      case 'critical': return 'Critical';
      default: return status;
    }
  }
}
