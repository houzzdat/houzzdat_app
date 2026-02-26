import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houzzdat_app/repositories/repositories.dart';

/// CI-06: Repository provider instances (singletons).
///
/// These providers give widgets access to repository instances without
/// creating new instances on every rebuild. They serve as the foundation
/// for all data-fetching providers.

final actionItemsRepositoryProvider = Provider<ActionItemsRepository>((ref) {
  return ActionItemsRepository();
});

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository();
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository();
});

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepository();
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository();
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository();
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});
