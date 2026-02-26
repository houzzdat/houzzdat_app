import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `owner_approvals` table.
///
/// CI-07: Used in owner_approvals_tab.dart, owner_approval_card.dart,
/// and action_card_widget.dart for escalate-to-owner flows.
class OwnerApproval {
  final String id;
  final String? ownerId;
  final String? projectId;
  final String? accountId;
  final String? actionItemId;
  final String? title;
  final String? description;
  final String? type;
  final String? status;
  final double? amount;
  final double? approvedAmount;
  final String? currency;
  final String? requestedBy;
  final String? ownerResponse;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  // Joined/enriched fields
  final String? projectName;
  final String? requestedByName;

  const OwnerApproval({
    required this.id,
    this.ownerId,
    this.projectId,
    this.accountId,
    this.actionItemId,
    this.title,
    this.description,
    this.type,
    this.status,
    this.amount,
    this.approvedAmount,
    this.currency,
    this.requestedBy,
    this.ownerResponse,
    this.createdAt,
    this.respondedAt,
    this.projectName,
    this.requestedByName,
  });

  factory OwnerApproval.fromJson(Map<String, dynamic> json) {
    // Extract joined project name
    final projects = JsonHelpers.toMap(json['projects']);
    final projectName = projects?['name']?.toString() ?? json['project_name']?.toString();

    // Extract joined requester name
    final users = JsonHelpers.toMap(json['users']);
    final requestedByName = users?['full_name']?.toString() ??
        users?['email']?.toString() ??
        json['requested_by_name']?.toString();

    return OwnerApproval(
      id: json['id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString(),
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      actionItemId: json['action_item_id']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      amount: JsonHelpers.toDouble(json['amount']),
      approvedAmount: JsonHelpers.toDouble(json['approved_amount']),
      currency: json['currency']?.toString(),
      requestedBy: json['requested_by']?.toString(),
      ownerResponse: json['owner_response']?.toString(),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      respondedAt: JsonHelpers.tryParseDate(json['responded_at']),
      projectName: projectName,
      requestedByName: requestedByName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'project_id': projectId,
    'account_id': accountId,
    'action_item_id': actionItemId,
    'title': title,
    'description': description,
    'type': type,
    'status': status,
    'amount': amount,
    'approved_amount': approvedAmount,
    'currency': currency,
    'requested_by': requestedBy,
    'owner_response': ownerResponse,
    'created_at': createdAt?.toIso8601String(),
    'responded_at': respondedAt?.toIso8601String(),
  };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get isPartiallyApproved =>
      isApproved &&
      amount != null &&
      approvedAmount != null &&
      approvedAmount! < amount!;

  OwnerApproval copyWith({
    String? id,
    String? ownerId,
    String? projectId,
    String? accountId,
    String? actionItemId,
    String? title,
    String? description,
    String? type,
    String? status,
    double? amount,
    double? approvedAmount,
    String? currency,
    String? requestedBy,
    String? ownerResponse,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? projectName,
    String? requestedByName,
  }) {
    return OwnerApproval(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      actionItemId: actionItemId ?? this.actionItemId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      currency: currency ?? this.currency,
      requestedBy: requestedBy ?? this.requestedBy,
      ownerResponse: ownerResponse ?? this.ownerResponse,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      projectName: projectName ?? this.projectName,
      requestedByName: requestedByName ?? this.requestedByName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OwnerApproval && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OwnerApproval(id: $id, status: $status, title: $title)';
}
