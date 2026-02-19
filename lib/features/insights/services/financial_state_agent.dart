import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/features/insights/models/financial_state.dart';

/// Consolidates financial data into position summaries with budget vs actuals.
class FinancialStateAgent {
  final _supabase = Supabase.instance.client;

  /// Compute financial position for all projects + company-wide summary.
  Future<List<FinancialPosition>> computeAllProjects(String accountId) async {
    final projects = await _supabase
        .from('projects')
        .select('id, name')
        .eq('account_id', accountId);

    final results = <FinancialPosition>[];

    // Per-project positions
    for (final project in projects) {
      final state = await computeProject(
        project['id'] as String,
        project['name'] as String? ?? 'Unnamed',
        accountId,
      );
      results.add(state);
    }

    // Company-wide summary
    if (results.isNotEmpty) {
      results.insert(0, _computeCompanyWide(results, accountId));
    }

    return results;
  }

  /// Compute financial position for a single project.
  Future<FinancialPosition> computeProject(
    String projectId,
    String projectName,
    String accountId,
  ) async {
    final results = await Future.wait([
      _fetchOwnerPayments(projectId),
      _fetchPayments(projectId),
      _fetchTransactions(projectId),
      _fetchInvoices(projectId),
      _fetchFundRequests(projectId),
      _fetchBudget(projectId),
    ]);

    final ownerPayments = results[0] as List<Map<String, dynamic>>;
    final payments = results[1] as List<Map<String, dynamic>>;
    final transactions = results[2] as List<Map<String, dynamic>>;
    final invoices = results[3] as List<Map<String, dynamic>>;
    final fundRequests = results[4] as List<Map<String, dynamic>>;
    final budgetData = results[5] as Map<String, dynamic>?;

    // Cash flow
    final totalReceived = _sumAmount(ownerPayments, 'amount');
    final paymentSpend = _sumAmount(payments, 'amount');
    final transactionSpend = _sumAmount(transactions, 'amount');
    final totalSpent = paymentSpend + transactionSpend;
    final netPosition = totalReceived - totalSpent;
    final cashFlowStatus = netPosition > 0
        ? 'positive'
        : netPosition < 0
            ? 'negative'
            : 'balanced';

    // Outstanding invoices
    final pendingInvoices = invoices.where((i) =>
        i['status'] == 'submitted' || i['status'] == 'approved').toList();
    final overdueInvoices = invoices.where((i) => i['status'] == 'overdue').toList();

    // Pending fund requests
    final pendingFunds = fundRequests.where((f) => f['status'] == 'pending').toList();

    // Spend by category
    final spendByCategory = <String, double>{};
    for (final t in transactions) {
      final cat = t['type']?.toString() ?? 'other';
      spendByCategory[cat] = (spendByCategory[cat] ?? 0) + ((t['amount'] as num?)?.toDouble() ?? 0);
    }

    // Budget vs actuals
    final hasBudget = budgetData != null;
    double totalBudget = 0;
    final budgetByCategory = <String, double>{};
    final lineItemVariances = <BudgetLineVariance>[];

    if (hasBudget) {
      totalBudget = (budgetData!['total_budget'] as num?)?.toDouble() ?? 0;
      final budgetItems = budgetData['items'] as List<Map<String, dynamic>>? ?? [];
      for (final item in budgetItems) {
        final cat = item['category']?.toString() ?? 'other';
        final amount = (item['budgeted_amount'] as num?)?.toDouble() ?? 0;
        budgetByCategory[cat] = (budgetByCategory[cat] ?? 0) + amount;
      }

      // Compute per-category variances
      final allCategories = {...budgetByCategory.keys, ...spendByCategory.keys};
      for (final cat in allCategories) {
        final budgeted = budgetByCategory[cat] ?? 0;
        final actual = spendByCategory[cat] ?? 0;
        final variance = budgeted - actual;
        final utilization = budgeted > 0 ? (actual / budgeted * 100) : 0.0;
        lineItemVariances.add(BudgetLineVariance(
          category: cat,
          lineItem: cat, // Category-level aggregation
          budgeted: budgeted,
          actual: actual,
          variance: variance,
          utilizationPercent: utilization,
          status: utilization > 100 ? 'over' : utilization > 80 ? 'on_track' : 'under',
        ));
      }
    }

    final budgetVariance = totalBudget - totalSpent;
    final budgetUtilization = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;
    final budgetStatus = budgetUtilization > 110
        ? 'critical'
        : budgetUtilization > 100
            ? 'over_budget'
            : budgetUtilization > 80
                ? 'on_budget'
                : 'under_budget';

    // Spend trends (this week vs last week)
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final spendThisWeek = _sumAmountInRange(transactions, 'amount', 'created_at', weekStart, now) +
        _sumAmountInRange(payments, 'amount', 'created_at', weekStart, now);
    final spendLastWeek = _sumAmountInRange(transactions, 'amount', 'created_at', lastWeekStart, weekStart) +
        _sumAmountInRange(payments, 'amount', 'created_at', lastWeekStart, weekStart);
    final spendTrend = spendThisWeek > spendLastWeek * 1.1
        ? 'increasing'
        : spendThisWeek < spendLastWeek * 0.9
            ? 'decreasing'
            : 'stable';

    return FinancialPosition(
      projectId: projectId,
      projectName: projectName,
      totalReceived: totalReceived,
      totalSpent: totalSpent,
      netPosition: netPosition,
      cashFlowStatus: cashFlowStatus,
      hasBudget: hasBudget,
      totalBudget: totalBudget,
      totalActualSpend: totalSpent,
      budgetVariance: budgetVariance,
      budgetUtilization: budgetUtilization,
      budgetStatus: budgetStatus,
      lineItemVariances: lineItemVariances,
      pendingInvoices: pendingInvoices.length,
      pendingInvoiceAmount: _sumAmount(pendingInvoices, 'amount'),
      overdueInvoices: overdueInvoices.length,
      overdueInvoiceAmount: _sumAmount(overdueInvoices, 'amount'),
      pendingFundRequests: pendingFunds.length,
      pendingFundRequestAmount: _sumAmount(pendingFunds, 'amount'),
      budgetByCategory: budgetByCategory,
      spendByCategory: spendByCategory,
      spendThisWeek: spendThisWeek,
      spendLastWeek: spendLastWeek,
      spendTrend: spendTrend,
    );
  }

  FinancialPosition _computeCompanyWide(List<FinancialPosition> projects, String accountId) {
    double totalReceived = 0, totalSpent = 0, totalBudget = 0;
    int pendingInv = 0, overdueInv = 0, pendingFunds = 0;
    double pendingInvAmt = 0, overdueInvAmt = 0, pendingFundAmt = 0;
    double weekSpend = 0, lastWeekSpend = 0;
    final budgetByCat = <String, double>{};
    final spendByCat = <String, double>{};
    bool anyBudget = false;

    for (final p in projects) {
      totalReceived += p.totalReceived;
      totalSpent += p.totalSpent;
      totalBudget += p.totalBudget;
      pendingInv += p.pendingInvoices;
      overdueInv += p.overdueInvoices;
      pendingFunds += p.pendingFundRequests;
      pendingInvAmt += p.pendingInvoiceAmount;
      overdueInvAmt += p.overdueInvoiceAmount;
      pendingFundAmt += p.pendingFundRequestAmount;
      weekSpend += p.spendThisWeek;
      lastWeekSpend += p.spendLastWeek;
      if (p.hasBudget) anyBudget = true;
      for (final e in p.budgetByCategory.entries) {
        budgetByCat[e.key] = (budgetByCat[e.key] ?? 0) + e.value;
      }
      for (final e in p.spendByCategory.entries) {
        spendByCat[e.key] = (spendByCat[e.key] ?? 0) + e.value;
      }
    }

    final netPos = totalReceived - totalSpent;
    final budgetUtil = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;

    return FinancialPosition(
      projectId: null,
      projectName: 'All Projects',
      totalReceived: totalReceived,
      totalSpent: totalSpent,
      netPosition: netPos,
      cashFlowStatus: netPos > 0 ? 'positive' : netPos < 0 ? 'negative' : 'balanced',
      hasBudget: anyBudget,
      totalBudget: totalBudget,
      totalActualSpend: totalSpent,
      budgetVariance: totalBudget - totalSpent,
      budgetUtilization: budgetUtil,
      budgetStatus: budgetUtil > 110 ? 'critical' : budgetUtil > 100 ? 'over_budget' : budgetUtil > 80 ? 'on_budget' : 'under_budget',
      lineItemVariances: [],
      pendingInvoices: pendingInv,
      pendingInvoiceAmount: pendingInvAmt,
      overdueInvoices: overdueInv,
      overdueInvoiceAmount: overdueInvAmt,
      pendingFundRequests: pendingFunds,
      pendingFundRequestAmount: pendingFundAmt,
      budgetByCategory: budgetByCat,
      spendByCategory: spendByCat,
      spendThisWeek: weekSpend,
      spendLastWeek: lastWeekSpend,
      spendTrend: weekSpend > lastWeekSpend * 1.1 ? 'increasing' : weekSpend < lastWeekSpend * 0.9 ? 'decreasing' : 'stable',
    );
  }

  // ─── Data Fetchers ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchOwnerPayments(String projectId) async {
    return await _supabase
        .from('owner_payments')
        .select('amount, received_date, created_at')
        .eq('project_id', projectId);
  }

  Future<List<Map<String, dynamic>>> _fetchPayments(String projectId) async {
    return await _supabase
        .from('payments')
        .select('amount, payment_date, created_at')
        .eq('project_id', projectId);
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions(String projectId) async {
    return await _supabase
        .from('finance_transactions')
        .select('amount, type, created_at')
        .eq('project_id', projectId);
  }

  Future<List<Map<String, dynamic>>> _fetchInvoices(String projectId) async {
    return await _supabase
        .from('invoices')
        .select('amount, status, due_date, created_at')
        .eq('project_id', projectId);
  }

  Future<List<Map<String, dynamic>>> _fetchFundRequests(String projectId) async {
    return await _supabase
        .from('fund_requests')
        .select('amount, status, created_at')
        .eq('project_id', projectId);
  }

  Future<Map<String, dynamic>?> _fetchBudget(String projectId) async {
    final plan = await _supabase
        .from('project_plans')
        .select('id, total_budget')
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (plan == null) return null;

    final items = await _supabase
        .from('project_budgets')
        .select('category, line_item, budgeted_amount')
        .eq('plan_id', plan['id']);

    return {
      'total_budget': plan['total_budget'],
      'items': items,
    };
  }

  // ─── Helpers ────────────────────────────────────────────────

  double _sumAmount(List<Map<String, dynamic>> rows, String field) {
    return rows.fold(0.0, (sum, r) => sum + ((r[field] as num?)?.toDouble() ?? 0));
  }

  double _sumAmountInRange(
    List<Map<String, dynamic>> rows,
    String amountField,
    String dateField,
    DateTime start,
    DateTime end,
  ) {
    return rows.fold(0.0, (sum, r) {
      final date = DateTime.tryParse(r[dateField]?.toString() ?? '');
      if (date != null && date.isAfter(start) && date.isBefore(end)) {
        return sum + ((r[amountField] as num?)?.toDouble() ?? 0);
      }
      return sum;
    });
  }
}
