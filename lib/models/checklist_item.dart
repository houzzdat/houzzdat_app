import 'package:houzzdat_app/models/json_helpers.dart';

class ChecklistItem {
  final String id;
  final String moduleId;
  final ChecklistGateType gateType;
  final ChecklistRole role;
  final String itemText;
  final String? itemTextHi;
  final String? itemTextTa;
  final String? itemTextKn;
  final String? itemTextTe;
  final EvidenceRequiredType evidenceRequired;
  final bool isCritical;
  final int sequenceOrder;
  final bool isActive;
  final DateTime createdAt;

  const ChecklistItem({
    required this.id,
    required this.moduleId,
    required this.gateType,
    required this.role,
    required this.itemText,
    this.itemTextHi,
    this.itemTextTa,
    this.itemTextKn,
    this.itemTextTe,
    required this.evidenceRequired,
    required this.isCritical,
    required this.sequenceOrder,
    required this.isActive,
    required this.createdAt,
  });

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as String,
      moduleId: map['module_id'] as String,
      gateType: ChecklistGateType.fromString(map['gate_type'] as String? ?? 'pre_start'),
      role: ChecklistRole.fromString(map['role'] as String? ?? 'manager'),
      itemText: map['item_text'] as String,
      itemTextHi: map['item_text_hi'] as String?,
      itemTextTa: map['item_text_ta'] as String?,
      itemTextKn: map['item_text_kn'] as String?,
      itemTextTe: map['item_text_te'] as String?,
      evidenceRequired: EvidenceRequiredType.fromString(map['evidence_required'] as String? ?? 'none'),
      isCritical: JsonHelpers.toBool(map['is_critical']) ?? false,
      sequenceOrder: JsonHelpers.toInt(map['sequence_order']) ?? 0,
      isActive: JsonHelpers.toBool(map['is_active']) ?? true,
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
    );
  }

  /// Returns localized text based on language code, falls back to English
  String localizedText(String languageCode) {
    switch (languageCode) {
      case 'hi': return itemTextHi ?? itemText;
      case 'ta': return itemTextTa ?? itemText;
      case 'kn': return itemTextKn ?? itemText;
      case 'te': return itemTextTe ?? itemText;
      default: return itemText;
    }
  }
}

enum ChecklistGateType {
  preStart,
  postCompletion;

  static ChecklistGateType fromString(String s) {
    switch (s) {
      case 'post_completion': return postCompletion;
      default: return preStart;
    }
  }

  String get dbValue => this == preStart ? 'pre_start' : 'post_completion';
  String get label => this == preStart ? 'Pre-Start Gate' : 'Completion Gate';
}

enum ChecklistRole {
  manager,
  worker,
  owner;

  static ChecklistRole fromString(String s) {
    switch (s) {
      case 'worker': return worker;
      case 'owner': return owner;
      default: return manager;
    }
  }

  String get label {
    switch (this) {
      case worker: return 'Worker';
      case owner: return 'Owner';
      default: return 'Manager';
    }
  }
}

enum EvidenceRequiredType {
  photo,
  document,
  voice,
  none;

  static EvidenceRequiredType fromString(String s) {
    switch (s) {
      case 'photo': return photo;
      case 'document': return document;
      case 'voice': return voice;
      default: return none;
    }
  }

  String get dbValue => name;
  bool get hasEvidence => this != none;
}

class ChecklistCompletion {
  final String id;
  final String phaseId;
  final String checklistItemId;
  final String projectId;
  final String accountId;
  final String? completedBy;
  final DateTime? completedAt;
  final bool isCompleted;
  final String? overrideReason;
  final EvidenceRequiredType? evidenceType;
  final String? evidenceUrl;
  final DateTime createdAt;

  const ChecklistCompletion({
    required this.id,
    required this.phaseId,
    required this.checklistItemId,
    required this.projectId,
    required this.accountId,
    this.completedBy,
    this.completedAt,
    required this.isCompleted,
    this.overrideReason,
    this.evidenceType,
    this.evidenceUrl,
    required this.createdAt,
  });

  factory ChecklistCompletion.fromMap(Map<String, dynamic> map) {
    return ChecklistCompletion(
      id: map['id'] as String,
      phaseId: map['phase_id'] as String,
      checklistItemId: map['checklist_item_id'] as String,
      projectId: map['project_id'] as String,
      accountId: map['account_id'] as String,
      completedBy: map['completed_by'] as String?,
      completedAt: JsonHelpers.tryParseDate(map['completed_at']),
      isCompleted: JsonHelpers.toBool(map['is_completed']) ?? false,
      overrideReason: map['override_reason'] as String?,
      evidenceType: map['evidence_type'] != null
          ? EvidenceRequiredType.fromString(map['evidence_type'] as String)
          : null,
      evidenceUrl: map['evidence_url'] as String?,
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
    );
  }
}

class PhaseGateApproval {
  final String id;
  final String phaseId;
  final String projectId;
  final String accountId;
  final ChecklistGateType gateType;
  final GateApprovalStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final int incompleteCriticalItems;
  final DateTime createdAt;

  const PhaseGateApproval({
    required this.id,
    required this.phaseId,
    required this.projectId,
    required this.accountId,
    required this.gateType,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.incompleteCriticalItems,
    required this.createdAt,
  });

  factory PhaseGateApproval.fromMap(Map<String, dynamic> map) {
    return PhaseGateApproval(
      id: map['id'] as String,
      phaseId: map['phase_id'] as String,
      projectId: map['project_id'] as String,
      accountId: map['account_id'] as String,
      gateType: ChecklistGateType.fromString(map['gate_type'] as String? ?? 'pre_start'),
      status: GateApprovalStatus.fromString(map['status'] as String? ?? 'pending'),
      approvedBy: map['approved_by'] as String?,
      approvedAt: JsonHelpers.tryParseDate(map['approved_at']),
      rejectionReason: map['rejection_reason'] as String?,
      incompleteCriticalItems: JsonHelpers.toInt(map['incomplete_critical_items']) ?? 0,
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
    );
  }
}

enum GateApprovalStatus {
  pending,
  approved,
  rejected;

  static GateApprovalStatus fromString(String s) {
    switch (s) {
      case 'approved': return approved;
      case 'rejected': return rejected;
      default: return pending;
    }
  }

  String get dbValue => name;
}

/// Holds a checklist item paired with its completion state for a specific phase
class ChecklistItemWithCompletion {
  final ChecklistItem item;
  final ChecklistCompletion? completion;

  const ChecklistItemWithCompletion({
    required this.item,
    this.completion,
  });

  bool get isCompleted => completion?.isCompleted ?? false;
  bool get hasEvidence => completion?.evidenceUrl != null;
  bool get isOverridden => completion?.overrideReason != null && !isCompleted;
  bool get needsEvidence => item.evidenceRequired.hasEvidence && !hasEvidence;
  bool get isBlocking => item.isCritical && !isCompleted && !isOverridden;
}
