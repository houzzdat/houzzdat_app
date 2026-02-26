import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/base_repository.dart';

/// CI-09: Repository for `action_items` table operations.
///
/// Abstracts all Supabase queries from UI widgets (action_card_widget.dart,
/// actions_tab.dart, daily_tasks_tab.dart, etc.).
class ActionItemsRepository extends BaseRepository {
  /// Fetch paginated action items for an account.
  Future<List<ActionItem>> getByAccount(
    String accountId, {
    int offset = 0,
    int limit = 30,
  }) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.actionItems)
          .select('*')
          .eq(DbColumns.accountId, accountId)
          .order(DbColumns.createdAt, ascending: false)
          .range(offset, offset + limit - 1),
      label: 'getActionsByAccount',
    );
    return (data as List).map((e) => ActionItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Fetch action items for a specific project.
  Future<List<ActionItem>> getByProject(
    String projectId, {
    String? status,
  }) async {
    var query = supabase
        .from(DbTables.actionItems)
        .select('*')
        .eq(DbColumns.projectId, projectId);
    if (status != null) {
      query = query.eq(DbColumns.status, status);
    }
    final data = await safeQuery(
      () => query.order(DbColumns.createdAt, ascending: false),
      label: 'getActionsByProject',
    );
    return (data as List).map((e) => ActionItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Fetch action items assigned to a worker.
  Future<List<ActionItem>> getByAssignee(
    String userId,
    String projectId, {
    List<String>? statuses,
  }) async {
    var query = supabase
        .from(DbTables.actionItems)
        .select('*')
        .eq(DbColumns.assignedTo, userId)
        .eq(DbColumns.projectId, projectId);
    if (statuses != null && statuses.isNotEmpty) {
      query = query.inFilter(DbColumns.status, statuses);
    }
    final data = await safeQuery(
      () => query.order(DbColumns.createdAt, ascending: false),
      label: 'getActionsByAssignee',
    );
    return (data as List).map((e) => ActionItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Fetch a single action item by ID.
  Future<ActionItem?> getById(String id) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.actionItems)
          .select('*')
          .eq(DbColumns.id, id)
          .maybeSingle(),
      label: 'getActionById',
    );
    if (data == null) return null;
    return ActionItem.fromJson(data);
  }

  /// Update action item status with interaction history entry.
  Future<void> updateStatus(
    String id,
    String newStatus, {
    String? userId,
    String? details,
  }) async {
    // Fetch current interaction history
    final current = await getById(id);
    if (current == null) return;

    final history = List<Map<String, dynamic>>.from(current.interactionHistory);
    history.add({
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId ?? currentUserId,
      'action': 'status_change',
      'details': details ?? 'Status changed to $newStatus',
    });

    await safeQuery(
      () => supabase.from(DbTables.actionItems).update({
        DbColumns.status: newStatus,
        DbColumns.interactionHistory: history,
        DbColumns.updatedAt: DateTime.now().toIso8601String(),
      }).eq(DbColumns.id, id),
      label: 'updateActionStatus',
    );
  }

  /// Bulk update status for multiple action items.
  Future<void> bulkUpdateStatus(
    List<String> ids,
    String newStatus, {
    String? userId,
  }) async {
    for (final id in ids) {
      await updateStatus(id, newStatus, userId: userId);
    }
  }

  /// Get action item stats (pending/inProgress/completed counts) for a project.
  Future<Map<String, int>> getProjectStats(String projectId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.actionItems)
          .select(DbColumns.status)
          .eq(DbColumns.projectId, projectId),
      label: 'getProjectStats',
    );

    final stats = {'pending': 0, 'inProgress': 0, 'completed': 0};
    for (final item in (data as List)) {
      switch (item[DbColumns.status]) {
        case 'pending':
        case 'approved':
          stats['pending'] = (stats['pending'] ?? 0) + 1;
          break;
        case 'in_progress':
        case 'verifying':
          stats['inProgress'] = (stats['inProgress'] ?? 0) + 1;
          break;
        case 'completed':
          stats['completed'] = (stats['completed'] ?? 0) + 1;
          break;
      }
    }
    return stats;
  }

  /// Get stats for multiple projects in a single batch query (CI-05).
  Future<Map<String, Map<String, int>>> getBatchProjectStats(
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return {};

    final data = await safeQuery(
      () => supabase
          .from(DbTables.actionItems)
          .select('${DbColumns.projectId}, ${DbColumns.status}')
          .inFilter(DbColumns.projectId, projectIds),
      label: 'getBatchProjectStats',
    );

    final stats = <String, Map<String, int>>{};
    for (final pid in projectIds) {
      stats[pid] = {'pending': 0, 'inProgress': 0, 'completed': 0};
    }
    for (final item in (data as List)) {
      final pid = item[DbColumns.projectId]?.toString() ?? '';
      if (!stats.containsKey(pid)) continue;
      switch (item[DbColumns.status]) {
        case 'pending':
        case 'approved':
          stats[pid]!['pending'] = (stats[pid]!['pending'] ?? 0) + 1;
          break;
        case 'in_progress':
        case 'verifying':
          stats[pid]!['inProgress'] = (stats[pid]!['inProgress'] ?? 0) + 1;
          break;
        case 'completed':
          stats[pid]!['completed'] = (stats[pid]!['completed'] ?? 0) + 1;
          break;
      }
    }
    return stats;
  }

  /// Get the voice note linked to an action item.
  Future<VoiceNote?> getLinkedVoiceNote(String voiceNoteId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.voiceNotes)
          .select('${DbColumns.audioUrl}, ${DbColumns.transcription}, '
              '${DbColumns.transcriptFinal}, ${DbColumns.transcriptEnCurrent}, '
              '${DbColumns.transcriptRawCurrent}, ${DbColumns.transcriptRaw}, '
              '${DbColumns.detectedLanguageCode}, ${DbColumns.isEdited}, ${DbColumns.status}')
          .eq(DbColumns.id, voiceNoteId)
          .maybeSingle(),
      label: 'getLinkedVoiceNote',
    );
    if (data == null) return null;
    return VoiceNote.fromJson({...data, 'id': voiceNoteId});
  }

  /// Add proof photo to an action item.
  Future<void> addProofPhoto(String actionItemId, String photoUrl) async {
    await safeQuery(
      () => supabase.from(DbTables.actionItems).update({
        DbColumns.proofPhotoUrl: photoUrl,
        DbColumns.updatedAt: DateTime.now().toIso8601String(),
      }).eq(DbColumns.id, actionItemId),
      label: 'addProofPhoto',
    );
  }
}
