import 'package:houzzdat_app/models/json_helpers.dart';
import 'package:houzzdat_app/models/voice_note.dart';

/// Type-safe model for the `attendance` table.
///
/// CI-07: Used in attendance_tab.dart, progress_tab.dart,
/// my_logs_tab.dart, and manager_site_detail_screen.dart.
class AttendanceRecord {
  final String id;
  final String? userId;
  final String? projectId;
  final String? accountId;
  final String? reportType;
  final String? reportText;
  final String? reportVoiceNoteId;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? createdAt;

  // Joined/enriched fields
  final VoiceNote? voiceNote;
  final String? userName;

  const AttendanceRecord({
    required this.id,
    this.userId,
    this.projectId,
    this.accountId,
    this.reportType,
    this.reportText,
    this.reportVoiceNoteId,
    this.checkInAt,
    this.checkOutAt,
    this.createdAt,
    this.voiceNote,
    this.userName,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    // Extract joined voice_notes data
    final voiceNotesData = JsonHelpers.toMap(json['voice_notes']);

    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      reportType: json['report_type']?.toString(),
      reportText: json['report_text']?.toString(),
      reportVoiceNoteId: json['report_voice_note_id']?.toString(),
      checkInAt: JsonHelpers.tryParseDate(json['check_in_at']),
      checkOutAt: JsonHelpers.tryParseDate(json['check_out_at']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      voiceNote: voiceNotesData != null ? VoiceNote.fromJson(voiceNotesData) : null,
      userName: json['user_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'project_id': projectId,
    'account_id': accountId,
    'report_type': reportType,
    'report_text': reportText,
    'report_voice_note_id': reportVoiceNoteId,
    'check_in_at': checkInAt?.toIso8601String(),
    'check_out_at': checkOutAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
  };

  bool get isCheckedIn => checkInAt != null && checkOutAt == null;
  bool get isCheckedOut => checkInAt != null && checkOutAt != null;

  /// Duration of this attendance shift, or null if not checked out.
  Duration? get shiftDuration {
    if (checkInAt == null || checkOutAt == null) return null;
    return checkOutAt!.difference(checkInAt!);
  }

  AttendanceRecord copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? accountId,
    String? reportType,
    String? reportText,
    String? reportVoiceNoteId,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    DateTime? createdAt,
    VoiceNote? voiceNote,
    String? userName,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      reportType: reportType ?? this.reportType,
      reportText: reportText ?? this.reportText,
      reportVoiceNoteId: reportVoiceNoteId ?? this.reportVoiceNoteId,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      createdAt: createdAt ?? this.createdAt,
      voiceNote: voiceNote ?? this.voiceNote,
      userName: userName ?? this.userName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AttendanceRecord && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AttendanceRecord(id: $id, checkIn: $checkInAt, checkOut: $checkOutAt)';
}
