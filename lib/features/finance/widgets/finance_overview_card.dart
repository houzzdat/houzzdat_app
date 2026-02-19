import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Top-level finance summary card showing:
/// - Total spent vs total received
/// - Outstanding invoices count + amount
/// - Pending fund requests count + amount
/// - Cash flow status (positive/negative indicator)
class FinanceOverviewCard extends StatefulWidget {
  final String accountId;
  const FinanceOverviewCard({super.key, required this.accountId});

  @override
  State<FinanceOverviewCard> createState() => _FinanceOverviewCardState();
}

class _FinanceOverviewCardState extends State<FinanceOverviewCard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  double _totalReceived = 0;
  double _totalSpent = 0;
  int _pendingInvoices = 0;
  double _pendingInvoiceAmount = 0;
  int _pendingFundRequests = 0;
  double _pendingFundRequestAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        // Owner payments (received)
        _supabase
            .from('owner_payments')
            .select('amount')
            .eq('account_id', widget.accountId),
        // Payments (spent)
        _supabase
            .from('payments')
            .select('amount')
            .eq('account_id', widget.accountId),
        // Finance transactions (spent)
        _supabase
            .from('finance_transactions')
            .select('amount')
            .eq('account_id', widget.accountId),
        // Pending invoices
        _supabase
            .from('invoices')
            .select('total_amount, status')
            .eq('account_id', widget.accountId)
            .inFilter('status', ['submitted', 'draft']),
        // Pending fund requests
        _supabase
            .from('fund_requests')
            .select('amount, status')
            .eq('account_id', widget.accountId)
            .eq('status', 'pending'),
      ]);

      double received = 0;
      for (final row in results[0] as List) {
        received += (row['amount'] as num?)?.toDouble() ?? 0;
      }

      double spent = 0;
      for (final row in results[1] as List) {
        spent += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      for (final row in results[2] as List) {
        spent += (row['amount'] as num?)?.toDouble() ?? 0;
      }

      final invoiceList = results[3] as List;
      double invAmount = 0;
      for (final inv in invoiceList) {
        invAmount += (inv['total_amount'] as num?)?.toDouble() ?? 0;
      }

      final fundList = results[4] as List;
      double fundAmount = 0;
      for (final fr in fundList) {
        fundAmount += (fr['amount'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _totalReceived = received;
          _totalSpent = spent;
          _pendingInvoices = invoiceList.length;
          _pendingInvoiceAmount = invAmount;
          _pendingFundRequests = fundList.length;
          _pendingFundRequestAmount = fundAmount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('FinanceOverviewCard error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)} K';
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryIndigo),
        )),
      );
    }

    final netPosition = _totalReceived - _totalSpent;
    final isPositive = netPosition >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net position
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Net: ${isPositive ? '+' : ''}₹${_formatAmount(netPosition)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Received vs Spent chips
          Row(
            children: [
              _chip('Received', '₹${_formatAmount(_totalReceived)}', AppTheme.successGreen),
              const SizedBox(width: 8),
              _chip('Spent', '₹${_formatAmount(_totalSpent)}', AppTheme.errorRed),
            ],
          ),

          // Alert chips
          if (_pendingInvoices > 0 || _pendingFundRequests > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_pendingInvoices > 0)
                  _alertChip(
                    '$_pendingInvoices invoice${_pendingInvoices == 1 ? '' : 's'} pending',
                    '₹${_formatAmount(_pendingInvoiceAmount)}',
                    AppTheme.warningOrange,
                  ),
                if (_pendingFundRequests > 0)
                  _alertChip(
                    '$_pendingFundRequests fund request${_pendingFundRequests == 1 ? '' : 's'}',
                    '₹${_formatAmount(_pendingFundRequestAmount)}',
                    AppTheme.infoBlue,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _alertChip(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 14, color: color),
          const SizedBox(width: 4),
          Text('$label ($amount)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
