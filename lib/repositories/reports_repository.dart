import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/base_repository.dart';

/// CI-09: Repository for `reports` table operations.
///
/// Abstracts report queries from reports_screen.dart, report_detail_screen.dart,
/// owner_reports_tab.dart, and owner_report_view_screen.dart.
class ReportsRepository extends BaseRepository {
  /// Fetch reports for an account (with joined creator data).
  Future<List<Report>> getByAccount(String accountId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.reports)
          .select('*, users!reports_created_by_fkey(${DbColumns.fullName})')
          .eq(DbColumns.accountId, accountId)
          .order(DbColumns.createdAt, ascending: false),
      label: 'getReportsByAccount',
    );
    return (data as List).map((e) => Report.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Fetch reports for an owner's projects.
  Future<List<Report>> getByOwner(
    String ownerId,
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return [];
    final data = await safeQuery(
      () => supabase
          .from(DbTables.reports)
          .select('*, users!reports_created_by_fkey(${DbColumns.fullName})')
          .inFilter(DbColumns.projectId, projectIds)
          .order(DbColumns.createdAt, ascending: false),
      label: 'getReportsByOwner',
    );
    return (data as List).map((e) => Report.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Fetch a single report by ID (with creator join).
  Future<Report?> getById(String reportId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.reports)
          .select('*, users!reports_created_by_fkey(${DbColumns.fullName})')
          .eq(DbColumns.id, reportId)
          .maybeSingle(),
      label: 'getReportById',
    );
    if (data == null) return null;
    return Report.fromJson(data);
  }

  /// Update report content.
  Future<void> updateContent(
    String reportId, {
    String? markdownContent,
    String? title,
    String? status,
  }) async {
    final update = <String, dynamic>{
      DbColumns.updatedAt: DateTime.now().toIso8601String(),
    };
    if (markdownContent != null) update['markdown_content'] = markdownContent;
    if (title != null) update[DbColumns.title] = title;
    if (status != null) update[DbColumns.status] = status;

    await safeQuery(
      () => supabase.from(DbTables.reports).update(update).eq(DbColumns.id, reportId),
      label: 'updateReportContent',
    );
  }

  /// Mark report as sent.
  Future<void> markAsSent(
    String reportId, {
    List<String>? sharedWith,
  }) async {
    final update = <String, dynamic>{
      DbColumns.status: 'sent',
      DbColumns.sentAt: DateTime.now().toIso8601String(),
      DbColumns.updatedAt: DateTime.now().toIso8601String(),
    };
    if (sharedWith != null) update['shared_with'] = sharedWith;

    await safeQuery(
      () => supabase.from(DbTables.reports).update(update).eq(DbColumns.id, reportId),
      label: 'markReportAsSent',
    );
  }

  /// Delete a report.
  Future<void> delete(String reportId) async {
    await safeQuery(
      () => supabase.from(DbTables.reports).delete().eq(DbColumns.id, reportId),
      label: 'deleteReport',
    );
  }

  /// Get reports count for KPI bar.
  Future<int> getCountForProjects(List<String> projectIds) async {
    if (projectIds.isEmpty) return 0;
    final data = await safeQuery(
      () => supabase
          .from(DbTables.reports)
          .select(DbColumns.id)
          .inFilter(DbColumns.projectId, projectIds),
      label: 'getReportsCount',
    );
    return (data as List).length;
  }
}
