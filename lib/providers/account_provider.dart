import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/providers/repository_providers.dart';

/// CI-06: Core account state — the authenticated user's context.
///
/// This provider replaces the scattered `_accountId`, `_userId`, and
/// role-fetching logic duplicated across 20+ StatefulWidget initState() calls.
///
/// Usage in ConsumerWidget:
/// ```dart
/// final accountState = ref.watch(accountProvider);
/// if (accountState.isLoading) return LoadingWidget();
/// final accountId = accountState.value?.accountId;
/// ```

/// The account state holds the current user's context.
class AccountState {
  final String userId;
  final String? accountId;
  final String? role;
  final String? fullName;
  final String? email;
  final String? currentProjectId;
  final bool quickTagEnabled;

  const AccountState({
    required this.userId,
    this.accountId,
    this.role,
    this.fullName,
    this.email,
    this.currentProjectId,
    this.quickTagEnabled = false,
  });

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'admin' || role == 'manager';
  bool get isWorker => role == 'worker' || role == 'field_worker';
}

/// Provider that loads the current user's account context.
final accountProvider = FutureProvider<AccountState?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final repo = ref.read(usersRepositoryProvider);
  final appUser = await repo.getById(user.id);
  if (appUser == null) return null;

  return AccountState(
    userId: user.id,
    accountId: appUser.accountId,
    role: appUser.role,
    fullName: appUser.fullName,
    email: appUser.email,
    currentProjectId: appUser.currentProjectId,
    quickTagEnabled: appUser.quickTagEnabled,
  );
});

/// Simple provider for just the account ID string.
/// Convenience for widgets that only need the account_id.
final accountIdProvider = Provider<String?>((ref) {
  return ref.watch(accountProvider).valueOrNull?.accountId;
});

/// Simple provider for just the user ID string.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(accountProvider).valueOrNull?.userId;
});
