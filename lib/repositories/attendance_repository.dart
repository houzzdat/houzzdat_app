import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/base_repository.dart';

/// CI-09: Repository for `attendance` table operations.
///
/// Abstracts attendance queries from attendance_tab.dart, progress_tab.dart,
/// my_logs_tab.dart, and manager_site_detail_screen.dart.
class AttendanceRepository extends BaseRepository {
  /// Get today's attendance record for a user on a project.
  Future<AttendanceRecord?> getTodayRecord(
    String userId,
    String projectId,
  ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.attendance)
          .select('*')
          .eq(DbColumns.userId, userId)
          .eq(DbColumns.projectId, projectId)
          .gte(DbColumns.checkInAt, startOfDay)
          .lte(DbColumns.checkInAt, endOfDay)
          .order(DbColumns.checkInAt, ascending: false)
          .limit(1)
          .maybeSingle(),
      label: 'getTodayAttendance',
    );
    if (data == null) return null;
    return AttendanceRecord.fromJson(data);
  }

  /// Get attendance history for a user (with voice notes).
  Future<List<AttendanceRecord>> getHistory(
    String userId,
    String projectId, {
    int limit = 30,
  }) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.attendance)
          .select('${DbColumns.id}, ${DbColumns.checkInAt}, ${DbColumns.checkOutAt}, '
              '${DbColumns.reportType}, report_text, '
              'voice_notes!${DbColumns.reportVoiceNoteId}(*)')
          .eq(DbColumns.userId, userId)
          .eq(DbColumns.projectId, projectId)
          .order(DbColumns.checkInAt, ascending: false)
          .limit(limit),
      label: 'getAttendanceHistory',
    );
    return (data as List)
        .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Check in a worker.
  Future<AttendanceRecord> checkIn({
    required String userId,
    required String projectId,
    required String accountId,
    Map<String, dynamic>? extraData,
  }) async {
    final insertData = {
      DbColumns.userId: userId,
      DbColumns.projectId: projectId,
      DbColumns.accountId: accountId,
      DbColumns.checkInAt: DateTime.now().toIso8601String(),
      ...?extraData,
    };

    final data = await safeQuery(
      () => supabase.from(DbTables.attendance).insert(insertData).select().single(),
      label: 'checkIn',
    );
    return AttendanceRecord.fromJson(data);
  }

  /// Check out a worker.
  Future<void> checkOut(String attendanceId) async {
    await safeQuery(
      () => supabase.from(DbTables.attendance).update({
        DbColumns.checkOutAt: DateTime.now().toIso8601String(),
      }).eq(DbColumns.id, attendanceId),
      label: 'checkOut',
    );
  }

  /// Update attendance report.
  Future<void> updateReport(
    String attendanceId, {
    String? reportType,
    String? reportText,
    String? reportVoiceNoteId,
  }) async {
    final update = <String, dynamic>{};
    if (reportType != null) update[DbColumns.reportType] = reportType;
    if (reportText != null) update['report_text'] = reportText;
    if (reportVoiceNoteId != null) update[DbColumns.reportVoiceNoteId] = reportVoiceNoteId;

    if (update.isNotEmpty) {
      await safeQuery(
        () => supabase.from(DbTables.attendance).update(update).eq(DbColumns.id, attendanceId),
        label: 'updateAttendanceReport',
      );
    }
  }

  /// Get attendance records for a project on a date (for manager view).
  Future<List<AttendanceRecord>> getProjectAttendance(
    String projectId, {
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day).toIso8601String();
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59).toIso8601String();

    final data = await safeQuery(
      () => supabase
          .from(DbTables.attendance)
          .select('${DbColumns.reportVoiceNoteId}, ${DbColumns.userId}, '
              '${DbColumns.checkInAt}, ${DbColumns.checkOutAt}')
          .eq(DbColumns.projectId, projectId)
          .gte(DbColumns.checkInAt, startOfDay)
          .lte(DbColumns.checkInAt, endOfDay)
          .order(DbColumns.checkInAt, ascending: false),
      label: 'getProjectAttendance',
    );
    return (data as List)
        .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
