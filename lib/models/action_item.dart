import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `action_items` table.
///
/// CI-07: The most heavily used entity in the codebase. Replaces
/// `Map<String, dynamic>` in action_card_widget.dart, actions_tab.dart,
/// daily_tasks_tab.dart, and 15+ other files.
class ActionItem {
  final String id;
  final String? userId;
  final String? projectId;
  final String? accountId;
  final String? voiceNoteId;
  final String? summary;
  final String? status;
  final String? priority;
  final String? category;
  final double? confidenceScore;
  final bool needsReview;
  final bool isCriticalFlag;
  final String? correctionType;
  final String? assignedTo;
  final String? proofPhotoUrl;
  final String? dueDate;
  final List<Map<String, dynamic>> interactionHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined/enriched fields (not in DB directly)
  final String? senderName;
  final String? projectName;

  const ActionItem({
    required this.id,
    this.userId,
    this.projectId,
    this.accountId,
    this.voiceNoteId,
    this.summary,
    this.status,
    this.priority,
    this.category,
    this.confidenceScore,
    this.needsReview = false,
    this.isCriticalFlag = false,
    this.correctionType,
    this.assignedTo,
    this.proofPhotoUrl,
    this.dueDate,
    this.interactionHistory = const [],
    this.createdAt,
    this.updatedAt,
    this.senderName,
    this.projectName,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      voiceNoteId: json['voice_note_id']?.toString(),
      summary: json['summary']?.toString(),
      status: json['status']?.toString(),
      priority: json['priority']?.toString(),
      category: json['category']?.toString(),
      confidenceScore: JsonHelpers.toDouble(json['confidence_score']),
      needsReview: JsonHelpers.toBool(json['needs_review']),
      isCriticalFlag: JsonHelpers.toBool(json['is_critical_flag']),
      correctionType: json['correction_type']?.toString(),
      assignedTo: json['assigned_to']?.toString(),
      proofPhotoUrl: json['proof_photo_url']?.toString(),
      dueDate: json['due_date']?.toString(),
      interactionHistory: JsonHelpers.toMapList(json['interaction_history']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      updatedAt: JsonHelpers.tryParseDate(json['updated_at']),
    );
  }

  /// Convert back to JSON map for Supabase updates.
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'project_id': projectId,
    'account_id': accountId,
    'voice_note_id': voiceNoteId,
    'summary': summary,
    'status': status,
    'priority': priority,
    'category': category,
    'confidence_score': confidenceScore,
    'needs_review': needsReview,
    'is_critical_flag': isCriticalFlag,
    'correction_type': correctionType,
    'assigned_to': assignedTo,
    'proof_photo_url': proofPhotoUrl,
    'due_date': dueDate,
    'interaction_history': interactionHistory,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// Convert to raw map for backward compatibility with existing widgets
  /// that still consume `Map<String, dynamic>`.
  Map<String, dynamic> toRawMap() => {
    ...toJson(),
    // Enriched fields for UI consumption
    if (senderName != null) '_sender_name': senderName,
    if (projectName != null) '_project_name': projectName,
  };

  bool get isPending => status == 'pending' || status == 'approved';
  bool get isInProgress => status == 'in_progress' || status == 'verifying';
  bool get isCompleted => status == 'completed';
  bool get isHighPriority => priority == 'high' || priority == 'critical';
  bool get isLowConfidence => (confidenceScore ?? 1.0) < 0.70;

  ActionItem copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? accountId,
    String? voiceNoteId,
    String? summary,
    String? status,
    String? priority,
    String? category,
    double? confidenceScore,
    bool? needsReview,
    bool? isCriticalFlag,
    String? correctionType,
    String? assignedTo,
    String? proofPhotoUrl,
    String? dueDate,
    List<Map<String, dynamic>>? interactionHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? senderName,
    String? projectName,
  }) {
    return ActionItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      voiceNoteId: voiceNoteId ?? this.voiceNoteId,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      needsReview: needsReview ?? this.needsReview,
      isCriticalFlag: isCriticalFlag ?? this.isCriticalFlag,
      correctionType: correctionType ?? this.correctionType,
      assignedTo: assignedTo ?? this.assignedTo,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      dueDate: dueDate ?? this.dueDate,
      interactionHistory: interactionHistory ?? this.interactionHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderName: senderName ?? this.senderName,
      projectName: projectName ?? this.projectName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ActionItem && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ActionItem(id: $id, status: $status, priority: $priority, category: $category)';
}
