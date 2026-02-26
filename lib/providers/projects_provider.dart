import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/providers/repository_providers.dart';

/// CI-06: Projects state management provider.
///
/// Replaces scattered project loading logic across owner_projects_tab.dart,
/// actions_tab.dart (filter dropdown), projects_tab.dart, etc.

/// Fetch all projects for an account.
final projectsProvider =
    FutureProvider.family<List<Project>, String>((ref, accountId) async {
  final repo = ref.read(projectsRepositoryProvider);
  return repo.getByAccount(accountId);
});

/// Fetch project names only (lightweight for dropdowns).
final projectNamesProvider =
    FutureProvider.family<List<Project>, String>((ref, accountId) async {
  final repo = ref.read(projectsRepositoryProvider);
  return repo.getProjectNames(accountId);
});

/// Fetch projects linked to an owner.
final ownerProjectsProvider =
    FutureProvider.family<List<Project>, String>((ref, ownerId) async {
  final repo = ref.read(projectsRepositoryProvider);
  return repo.getByOwner(ownerId);
});

/// Batch project stats (pending/inProgress/completed counts).
final projectStatsProvider = FutureProvider.family<
    Map<String, Map<String, int>>, List<String>>((ref, projectIds) async {
  final repo = ref.read(actionItemsRepositoryProvider);
  return repo.getBatchProjectStats(projectIds);
});
