import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/financial_state.dart';
import 'package:houzzdat_app/features/insights/widgets/budget_vs_actuals_widget.dart';

/// Full-screen drill-down for a single project's financial position.
class FinancialPositionDetail extends StatelessWidget {
  final FinancialPosition state;

  const FinancialPositionDetail({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isPositive = state.netPosition >= 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(state.projectName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cash flow hero
            _buildCashFlowHero(isPositive),

            // Outstanding section
            if (state.pendingInvoices > 0 || state.overdueInvoices > 0 || state.pendingFundRequests > 0)
              _buildOutstandingSection(),

            // Budget vs Actuals
            _buildSectionHeader('BUDGET VS ACTUALS'),
            BudgetVsActualsWidget(state: state),

            // Spend trend
            _buildSectionHeader('SPEND TREND'),
            _buildSpendTrendCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowHero(bool isPositive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          // Net position
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                _formatCurrency(state.netPosition.abs()),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isPositive ? 'Net Positive Cash Flow' : 'Net Negative Cash Flow',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          // Received vs Spent cards
          Row(
            children: [
              Expanded(child: _buildFlowCard('Received', state.totalReceived, AppTheme.successGreen, Icons.arrow_downward)),
              const SizedBox(width: 12),
              Expanded(child: _buildFlowCard('Spent', state.totalSpent, AppTheme.errorRed, Icons.arrow_upward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(amount),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('OUTSTANDING'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (state.overdueInvoices > 0)
                _buildOutstandingRow(
                  Icons.error_outline,
                  '${state.overdueInvoices} overdue invoice${state.overdueInvoices == 1 ? '' : 's'}',
                  _formatCurrency(state.overdueInvoiceAmount),
                  AppTheme.errorRed,
                ),
              if (state.pendingInvoices > 0)
                _buildOutstandingRow(
                  Icons.receipt_long,
                  '${state.pendingInvoices} pending invoice${state.pendingInvoices == 1 ? '' : 's'}',
                  _formatCurrency(state.pendingInvoiceAmount),
                  AppTheme.warningOrange,
                ),
              if (state.pendingFundRequests > 0)
                _buildOutstandingRow(
                  Icons.account_balance_wallet,
                  '${state.pendingFundRequests} fund request${state.pendingFundRequests == 1 ? '' : 's'}',
                  _formatCurrency(state.pendingFundRequestAmount),
                  AppTheme.infoBlue,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutstandingRow(IconData icon, String label, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTheme.bodyMedium),
          ),
          Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSpendTrendCard() {
    final trendColor = state.spendTrend == 'increasing'
        ? AppTheme.warningOrange
        : state.spendTrend == 'decreasing'
            ? AppTheme.successGreen
            : AppTheme.textSecondary;
    final trendIcon = state.spendTrend == 'increasing'
        ? Icons.trending_up
        : state.spendTrend == 'decreasing'
            ? Icons.trending_down
            : Icons.trending_flat;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // This week
          Expanded(
            child: Column(
              children: [
                Text('This Week', style: AppTheme.caption),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(state.spendThisWeek),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Trend arrow
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(trendIcon, size: 24, color: trendColor),
          ),
          // Last week
          Expanded(
            child: Column(
              children: [
                Text('Last Week', style: AppTheme.caption),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(state.spendLastWeek),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: AppTheme.caption.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      )),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)} K';
    return amount.toStringAsFixed(0);
  }
}
