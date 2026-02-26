import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `notifications` table.
///
/// CI-07: Used in notification_service.dart and owner_messages_tab.dart.
class AppNotification {
  final String id;
  final String? userId;
  final String? accountId;
  final String? title;
  final String? body;
  final String? type;
  final String? actionItemId;
  final String? voiceNoteId;
  final String? projectId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    this.userId,
    this.accountId,
    this.title,
    this.body,
    this.type,
    this.actionItemId,
    this.voiceNoteId,
    this.projectId,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      accountId: json['account_id']?.toString(),
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      type: json['type']?.toString(),
      actionItemId: json['action_item_id']?.toString(),
      voiceNoteId: json['voice_note_id']?.toString(),
      projectId: json['project_id']?.toString(),
      isRead: JsonHelpers.toBool(json['is_read']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'account_id': accountId,
    'title': title,
    'body': body,
    'type': type,
    'action_item_id': actionItemId,
    'voice_note_id': voiceNoteId,
    'project_id': projectId,
    'is_read': isRead,
    'created_at': createdAt?.toIso8601String(),
  };

  AppNotification copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? title,
    String? body,
    String? type,
    String? actionItemId,
    String? voiceNoteId,
    String? projectId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      actionItemId: actionItemId ?? this.actionItemId,
      voiceNoteId: voiceNoteId ?? this.voiceNoteId,
      projectId: projectId ?? this.projectId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppNotification && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppNotification(id: $id, type: $type, title: $title)';
}
