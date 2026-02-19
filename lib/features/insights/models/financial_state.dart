/// Variance for a single budget line item.
class BudgetLineVariance {
  final String category;
  final String lineItem;
  final double budgeted;
  final double actual;
  final double variance;
  final double utilizationPercent;
  final String status; // under, on_track, over

  const BudgetLineVariance({
    required this.category,
    required this.lineItem,
    required this.budgeted,
    required this.actual,
    required this.variance,
    required this.utilizationPercent,
    required this.status,
  });
}

/// Complete financial position for a project or company-wide.
class FinancialPosition {
  final String? projectId;
  final String projectName;

  // Cash flow
  final double totalReceived;
  final double totalSpent;
  final double netPosition;
  final String cashFlowStatus; // positive, negative, balanced

  // Budget vs Actuals
  final bool hasBudget;
  final double totalBudget;
  final double totalActualSpend;
  final double budgetVariance;
  final double budgetUtilization;
  final String budgetStatus; // under_budget, on_budget, over_budget, critical
  final List<BudgetLineVariance> lineItemVariances;

  // Outstanding
  final int pendingInvoices;
  final double pendingInvoiceAmount;
  final int overdueInvoices;
  final double overdueInvoiceAmount;

  // Fund requests
  final int pendingFundRequests;
  final double pendingFundRequestAmount;

  // Breakdown by category
  final Map<String, double> budgetByCategory;
  final Map<String, double> spendByCategory;

  // Trend
  final double spendThisWeek;
  final double spendLastWeek;
  final String spendTrend; // increasing, stable, decreasing

  const FinancialPosition({
    this.projectId,
    required this.projectName,
    this.totalReceived = 0,
    this.totalSpent = 0,
    this.netPosition = 0,
    this.cashFlowStatus = 'balanced',
    this.hasBudget = false,
    this.totalBudget = 0,
    this.totalActualSpend = 0,
    this.budgetVariance = 0,
    this.budgetUtilization = 0,
    this.budgetStatus = 'on_budget',
    this.lineItemVariances = const [],
    this.pendingInvoices = 0,
    this.pendingInvoiceAmount = 0,
    this.overdueInvoices = 0,
    this.overdueInvoiceAmount = 0,
    this.pendingFundRequests = 0,
    this.pendingFundRequestAmount = 0,
    this.budgetByCategory = const {},
    this.spendByCategory = const {},
    this.spendThisWeek = 0,
    this.spendLastWeek = 0,
    this.spendTrend = 'stable',
  });
}
