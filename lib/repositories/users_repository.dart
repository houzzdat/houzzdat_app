import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/base_repository.dart';

/// CI-09: Repository for `users` table operations.
///
/// Abstracts user queries from auth_wrapper.dart, settings_screen.dart,
/// team_tab.dart, and action_card_widget.dart.
class UsersRepository extends BaseRepository {
  /// Get current user profile.
  Future<AppUser?> getCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getById(userId);
  }

  /// Get user by ID.
  Future<AppUser?> getById(String userId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.users)
          .select('*')
          .eq(DbColumns.id, userId)
          .maybeSingle(),
      label: 'getUserById',
    );
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  /// Get user's account ID and role.
  Future<({String? accountId, String? role})> getUserContext(String userId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.users)
          .select('${DbColumns.role}, ${DbColumns.accountId}')
          .eq(DbColumns.id, userId)
          .maybeSingle(),
      label: 'getUserContext',
    );
    return (
      accountId: data?[DbColumns.accountId]?.toString(),
      role: data?[DbColumns.role]?.toString(),
    );
  }

  /// Get user display name (full_name or email).
  Future<String> getDisplayName(String userId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.users)
          .select('${DbColumns.fullName}, ${DbColumns.email}')
          .eq(DbColumns.id, userId)
          .maybeSingle(),
      label: 'getDisplayName',
    );
    return data?[DbColumns.fullName]?.toString() ??
        data?[DbColumns.email]?.toString() ??
        'Unknown';
  }

  /// Get team members for a project.
  Future<List<AppUser>> getTeamMembers(
    String accountId, {
    String? role,
  }) async {
    var query = supabase
        .from(DbTables.users)
        .select('${DbColumns.id}, ${DbColumns.email}, ${DbColumns.fullName}, '
            '${DbColumns.phoneNumber}, ${DbColumns.currentProjectId}, '
            '${DbColumns.geofenceExempt}, ${DbColumns.quickTagEnabled}')
        .eq(DbColumns.accountId, accountId);
    if (role != null) {
      query = query.eq(DbColumns.role, role);
    }
    final data = await safeQuery(
      () => query.order(DbColumns.fullName, ascending: true),
      label: 'getTeamMembers',
    );
    return (data as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Update user settings.
  Future<void> updateSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    await safeQuery(
      () => supabase.from(DbTables.users).update(settings).eq(DbColumns.id, userId),
      label: 'updateUserSettings',
    );
  }

  /// Get user profile data for settings screen.
  Future<AppUser?> getProfile(String userId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.users)
          .select('${DbColumns.fullName}, ${DbColumns.email}, ${DbColumns.role}')
          .eq(DbColumns.id, userId)
          .maybeSingle(),
      label: 'getUserProfile',
    );
    if (data == null) return null;
    return AppUser.fromJson({...data, DbColumns.id: userId});
  }
}
