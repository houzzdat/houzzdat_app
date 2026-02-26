import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/providers/repository_providers.dart';

/// CI-06: Owner-domain state management providers.
///
/// Replaces setState() calls in owner_dashboard.dart, owner_approvals_tab.dart,
/// owner_finances_subtab.dart, etc.

/// Fetch approvals for an owner.
final ownerApprovalsProvider =
    FutureProvider.family<List<OwnerApproval>, String>((ref, ownerId) async {
  final repo = ref.read(ownerRepositoryProvider);
  return repo.getApprovals(ownerId);
});

/// Get pending approvals count.
final pendingApprovalsCountProvider =
    FutureProvider.family<int, String>((ref, ownerId) async {
  final repo = ref.read(ownerRepositoryProvider);
  return repo.getPendingCount(ownerId);
});

/// Get owner's project IDs.
final ownerProjectIdsProvider =
    FutureProvider.family<List<String>, String>((ref, ownerId) async {
  final repo = ref.read(ownerRepositoryProvider);
  return repo.getOwnerProjectIds(ownerId);
});

/// Fetch owner payments for specific projects.
final ownerPaymentsProvider = FutureProvider.family<List<OwnerPayment>,
    ({String accountId, List<String> projectIds})>((ref, params) async {
  final repo = ref.read(ownerRepositoryProvider);
  return repo.getPayments(params.accountId, params.projectIds);
});

/// Fetch fund requests for specific projects.
final fundRequestsProvider = FutureProvider.family<List<FundRequest>,
    ({String accountId, List<String> projectIds})>((ref, params) async {
  final repo = ref.read(ownerRepositoryProvider);
  return repo.getFundRequests(params.accountId, params.projectIds);
});

/// Net cash position (received - approved).
final netCashPositionProvider = FutureProvider.family<double,
    ({String accountId, List<String> projectIds})>((ref, params) async {
  final repo = ref.read(ownerRepositoryProvider);
  return repo.getNetCashPosition(params.accountId, params.projectIds);
});
