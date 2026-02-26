import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `reports` table.
///
/// CI-07: Used in reports_screen.dart, report_detail_screen.dart,
/// report_card.dart, owner_reports_tab.dart, and owner_report_view_screen.dart.
class Report {
  final String id;
  final String? projectId;
  final String? accountId;
  final String? createdBy;
  final String? title;
  final String? content;
  final String? markdownContent;
  final String? status;
  final String? reportType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final List<String>? projectIds;
  final List<String>? sharedWith;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined/enriched fields
  final String? createdByName;
  final String? projectName;

  const Report({
    required this.id,
    this.projectId,
    this.accountId,
    this.createdBy,
    this.title,
    this.content,
    this.markdownContent,
    this.status,
    this.reportType,
    this.periodStart,
    this.periodEnd,
    this.projectIds,
    this.sharedWith,
    this.sentAt,
    this.createdAt,
    this.updatedAt,
    this.createdByName,
    this.projectName,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    final users = JsonHelpers.toMap(json['users']);

    return Report(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      createdBy: json['created_by']?.toString(),
      title: json['title']?.toString(),
      content: json['content']?.toString(),
      markdownContent: json['markdown_content']?.toString(),
      status: json['status']?.toString(),
      reportType: json['report_type']?.toString(),
      periodStart: JsonHelpers.tryParseDate(json['period_start']),
      periodEnd: JsonHelpers.tryParseDate(json['period_end']),
      projectIds: _toStringList(json['project_ids']),
      sharedWith: _toStringList(json['shared_with']),
      sentAt: JsonHelpers.tryParseDate(json['sent_at']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      updatedAt: JsonHelpers.tryParseDate(json['updated_at']),
      createdByName: users?['full_name']?.toString() ?? json['created_by_name']?.toString(),
      projectName: json['project_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'account_id': accountId,
    'created_by': createdBy,
    'title': title,
    'content': content,
    'markdown_content': markdownContent,
    'status': status,
    'report_type': reportType,
    'period_start': periodStart?.toIso8601String(),
    'period_end': periodEnd?.toIso8601String(),
    'project_ids': projectIds,
    'shared_with': sharedWith,
    'sent_at': sentAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  bool get isDraft => status == 'draft';
  bool get isSent => status == 'sent';
  bool get isPublished => status == 'published';

  Report copyWith({
    String? id,
    String? projectId,
    String? accountId,
    String? createdBy,
    String? title,
    String? content,
    String? markdownContent,
    String? status,
    String? reportType,
    DateTime? periodStart,
    DateTime? periodEnd,
    List<String>? projectIds,
    List<String>? sharedWith,
    DateTime? sentAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByName,
    String? projectName,
  }) {
    return Report(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      content: content ?? this.content,
      markdownContent: markdownContent ?? this.markdownContent,
      status: status ?? this.status,
      reportType: reportType ?? this.reportType,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      projectIds: projectIds ?? this.projectIds,
      sharedWith: sharedWith ?? this.sharedWith,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByName: createdByName ?? this.createdByName,
      projectName: projectName ?? this.projectName,
    );
  }

  static List<String>? _toStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Report && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Report(id: $id, title: $title, status: $status)';
}
