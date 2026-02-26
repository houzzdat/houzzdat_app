import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/base_repository.dart';

/// CI-09: Repository for owner-domain operations.
///
/// Abstracts queries for owner_approvals, owner_payments, and related
/// data from owner_dashboard.dart, owner_approvals_tab.dart,
/// owner_finances_subtab.dart, and owner_payment_card.dart.
class OwnerRepository extends BaseRepository {
  // ─── Approvals ─────────────────────────────────────────────────

  /// Fetch all approvals for an owner (with joined project & requester data).
  Future<List<OwnerApproval>> getApprovals(String ownerId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.ownerApprovals)
          .select('*, projects(${DbColumns.name}), '
              'users!owner_approvals_requested_by_fkey(${DbColumns.fullName}, ${DbColumns.email})')
          .eq(DbColumns.ownerId, ownerId)
          .order(DbColumns.createdAt, ascending: false),
      label: 'getOwnerApprovals',
    );
    return (data as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      return OwnerApproval.fromJson(map);
    }).toList();
  }

  /// Update an approval's status.
  Future<void> respondToApproval(
    String approvalId, {
    required String status,
    String? ownerResponse,
  }) async {
    await safeQuery(
      () => supabase.from(DbTables.ownerApprovals).update({
        DbColumns.status: status,
        DbColumns.ownerResponse: ownerResponse,
        DbColumns.respondedAt: DateTime.now().toIso8601String(),
      }).eq(DbColumns.id, approvalId),
      label: 'respondToApproval',
    );
  }

  /// Add a note to an existing approval.
  Future<void> addNote(String approvalId, String note) async {
    final current = await safeQueryOrNull(
      () => supabase
          .from(DbTables.ownerApprovals)
          .select(DbColumns.ownerResponse)
          .eq(DbColumns.id, approvalId)
          .maybeSingle(),
      label: 'getApprovalNote',
    );

    final existing = current?[DbColumns.ownerResponse]?.toString() ?? '';
    final updated = existing.isNotEmpty ? '$existing\n---\n$note' : note;

    await safeQuery(
      () => supabase.from(DbTables.ownerApprovals).update({
        DbColumns.ownerResponse: updated,
      }).eq(DbColumns.id, approvalId),
      label: 'addApprovalNote',
    );
  }

  /// Get pending approvals count for an owner.
  Future<int> getPendingCount(String ownerId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.ownerApprovals)
          .select(DbColumns.id)
          .eq(DbColumns.ownerId, ownerId)
          .eq(DbColumns.status, 'pending'),
      label: 'getPendingApprovalsCount',
    );
    return (data as List).length;
  }

  // ─── Payments ──────────────────────────────────────────────────

  /// Fetch owner payments for projects.
  Future<List<OwnerPayment>> getPayments(
    String accountId,
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return [];
    final data = await safeQuery(
      () => supabase
          .from(DbTables.ownerPayments)
          .select('*, users!owner_payments_owner_id_fkey(${DbColumns.fullName}), projects(${DbColumns.name})')
          .eq(DbColumns.accountId, accountId)
          .inFilter(DbColumns.projectId, projectIds)
          .order(DbColumns.createdAt, ascending: false),
      label: 'getOwnerPayments',
    );
    return (data as List).map((e) => OwnerPayment.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Get total received amount for an owner's projects.
  Future<double> getTotalReceived(
    String accountId,
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return 0.0;
    final data = await safeQuery(
      () => supabase
          .from(DbTables.ownerPayments)
          .select(DbColumns.amount)
          .eq(DbColumns.accountId, accountId)
          .inFilter(DbColumns.projectId, projectIds),
      label: 'getTotalReceived',
    );
    double total = 0.0;
    for (final row in (data as List)) {
      total += JsonHelpers.toDoubleOr(row[DbColumns.amount]);
    }
    return total;
  }

  // ─── Fund Requests ─────────────────────────────────────────────

  /// Fetch fund requests for an owner's projects.
  Future<List<FundRequest>> getFundRequests(
    String accountId,
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return [];
    final data = await safeQuery(
      () => supabase
          .from(DbTables.fundRequests)
          .select('*, users!fund_requests_owner_id_fkey(${DbColumns.fullName}), projects(${DbColumns.name})')
          .eq(DbColumns.accountId, accountId)
          .inFilter(DbColumns.projectId, projectIds)
          .order(DbColumns.createdAt, ascending: false),
      label: 'getFundRequests',
    );
    return (data as List).map((e) => FundRequest.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Get total approved fund requests amount.
  Future<double> getTotalApprovedRequests(
    String accountId,
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return 0.0;
    final data = await safeQuery(
      () => supabase
          .from(DbTables.fundRequests)
          .select(DbColumns.amount)
          .eq(DbColumns.accountId, accountId)
          .inFilter(DbColumns.projectId, projectIds)
          .eq(DbColumns.status, 'approved'),
      label: 'getTotalApprovedRequests',
    );
    double total = 0.0;
    for (final row in (data as List)) {
      total += JsonHelpers.toDoubleOr(row[DbColumns.amount]);
    }
    return total;
  }

  // ─── KPI Helpers ───────────────────────────────────────────────

  /// Get project IDs linked to an owner.
  Future<List<String>> getOwnerProjectIds(String ownerId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.projectOwners)
          .select(DbColumns.projectId)
          .eq(DbColumns.ownerId, ownerId),
      label: 'getOwnerProjectIds',
    );
    return (data as List)
        .map((e) => e[DbColumns.projectId]?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Compute net cash position (received - approved requests).
  Future<double> getNetCashPosition(
    String accountId,
    List<String> projectIds,
  ) async {
    final received = await getTotalReceived(accountId, projectIds);
    final approved = await getTotalApprovedRequests(accountId, projectIds);
    return received - approved;
  }
}
