import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/base_repository.dart';

/// CI-09: Repository for finance-domain operations.
///
/// Abstracts queries for invoices, payments, finance_transactions
/// from site_finances_subtab.dart, finance_overview_card.dart, etc.
class FinanceRepository extends BaseRepository {
  // ─── Invoices ──────────────────────────────────────────────────

  /// Fetch invoices for an account (with joined project & submitter data).
  Future<List<Invoice>> getInvoices(
    String accountId, {
    String? projectId,
  }) async {
    var query = supabase
        .from(DbTables.invoices)
        .select('*, projects(${DbColumns.name}), '
            'users!invoices_submitted_by_fkey(${DbColumns.fullName})')
        .eq(DbColumns.accountId, accountId);
    if (projectId != null) {
      query = query.eq(DbColumns.projectId, projectId);
    }
    final data = await safeQuery(
      () => query.order(DbColumns.createdAt, ascending: false),
      label: 'getInvoices',
    );
    return (data as List).map((e) => Invoice.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Get invoice by ID.
  Future<Invoice?> getInvoiceById(String invoiceId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.invoices)
          .select('*')
          .eq(DbColumns.id, invoiceId)
          .maybeSingle(),
      label: 'getInvoiceById',
    );
    if (data == null) return null;
    return Invoice.fromJson(data);
  }

  /// Create a new invoice.
  Future<void> createInvoice(Map<String, dynamic> invoiceData) async {
    await safeQuery(
      () => supabase.from(DbTables.invoices).insert(invoiceData),
      label: 'createInvoice',
    );
  }

  /// Update invoice status.
  Future<void> updateInvoiceStatus(
    String invoiceId,
    String status, {
    Map<String, dynamic>? extraFields,
  }) async {
    final updateData = {
      DbColumns.status: status,
      DbColumns.updatedAt: DateTime.now().toIso8601String(),
      ...?extraFields,
    };
    await safeQuery(
      () => supabase.from(DbTables.invoices).update(updateData).eq(DbColumns.id, invoiceId),
      label: 'updateInvoiceStatus',
    );
  }

  // ─── Payments (Site-level) ─────────────────────────────────────

  /// Fetch site-level payments for an account.
  Future<List<Payment>> getPayments(
    String accountId, {
    String? projectId,
  }) async {
    var query = supabase
        .from(DbTables.payments)
        .select('*, projects(${DbColumns.name})')
        .eq(DbColumns.accountId, accountId);
    if (projectId != null) {
      query = query.eq(DbColumns.projectId, projectId);
    }
    final data = await safeQuery(
      () => query.order(DbColumns.createdAt, ascending: false),
      label: 'getPayments',
    );
    return (data as List).map((e) => Payment.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Create a new payment.
  Future<void> createPayment(Map<String, dynamic> paymentData) async {
    await safeQuery(
      () => supabase.from(DbTables.payments).insert(paymentData),
      label: 'createPayment',
    );
  }

  // ─── Finance Overview ──────────────────────────────────────────

  /// Get aggregate finance data for a project.
  Future<FinanceOverview> getProjectOverview(String projectId) async {
    final results = await Future.wait([
      safeQuery(
        () => supabase
            .from(DbTables.ownerPayments)
            .select(DbColumns.amount)
            .eq(DbColumns.projectId, projectId),
        label: 'overviewOwnerPayments',
      ),
      safeQuery(
        () => supabase
            .from(DbTables.payments)
            .select(DbColumns.amount)
            .eq(DbColumns.projectId, projectId),
        label: 'overviewPayments',
      ),
      safeQuery(
        () => supabase
            .from(DbTables.financeTransactions)
            .select(DbColumns.amount)
            .eq(DbColumns.projectId, projectId),
        label: 'overviewTransactions',
      ),
      safeQuery(
        () => supabase
            .from(DbTables.invoices)
            .select('amount, ${DbColumns.status}')
            .eq(DbColumns.projectId, projectId),
        label: 'overviewInvoices',
      ),
      safeQuery(
        () => supabase
            .from(DbTables.fundRequests)
            .select('${DbColumns.amount}, ${DbColumns.status}')
            .eq(DbColumns.projectId, projectId),
        label: 'overviewFundRequests',
      ),
    ]);

    return FinanceOverview.fromQueryResults(
      ownerPayments: results[0] as List,
      payments: results[1] as List,
      transactions: results[2] as List,
      invoices: results[3] as List,
      fundRequests: results[4] as List,
    );
  }
}

/// Aggregated finance overview for a project.
class FinanceOverview {
  final double totalOwnerPayments;
  final double totalPayments;
  final double totalTransactions;
  final double totalInvoiced;
  final double pendingInvoiced;
  final double totalFundRequests;
  final double approvedFundRequests;

  const FinanceOverview({
    this.totalOwnerPayments = 0,
    this.totalPayments = 0,
    this.totalTransactions = 0,
    this.totalInvoiced = 0,
    this.pendingInvoiced = 0,
    this.totalFundRequests = 0,
    this.approvedFundRequests = 0,
  });

  factory FinanceOverview.fromQueryResults({
    required List ownerPayments,
    required List payments,
    required List transactions,
    required List invoices,
    required List fundRequests,
  }) {
    double sumOwner = 0, sumPay = 0, sumTx = 0;
    double sumInvoiced = 0, sumPendingInv = 0;
    double sumFr = 0, sumApprovedFr = 0;

    for (final r in ownerPayments) {
      sumOwner += JsonHelpers.toDoubleOr(r['amount']);
    }
    for (final r in payments) {
      sumPay += JsonHelpers.toDoubleOr(r['amount']);
    }
    for (final r in transactions) {
      sumTx += JsonHelpers.toDoubleOr(r['amount']);
    }
    for (final r in invoices) {
      final amt = JsonHelpers.toDoubleOr(r['amount']);
      sumInvoiced += amt;
      if (r['status'] == 'pending') sumPendingInv += amt;
    }
    for (final r in fundRequests) {
      final amt = JsonHelpers.toDoubleOr(r['amount']);
      sumFr += amt;
      if (r['status'] == 'approved') sumApprovedFr += amt;
    }

    return FinanceOverview(
      totalOwnerPayments: sumOwner,
      totalPayments: sumPay,
      totalTransactions: sumTx,
      totalInvoiced: sumInvoiced,
      pendingInvoiced: sumPendingInv,
      totalFundRequests: sumFr,
      approvedFundRequests: sumApprovedFr,
    );
  }

  double get netPosition => totalOwnerPayments - totalPayments;
}
