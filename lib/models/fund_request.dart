import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `fund_requests` table.
///
/// CI-07: Used in fund_request_card.dart, owner_finances_subtab.dart,
/// finance_overview_card.dart, and finance_export_service.dart.
class FundRequest {
  final String id;
  final String? projectId;
  final String? accountId;
  final String? ownerId;
  final String? requestedBy;
  final String? title;
  final String? description;
  final String? category;
  final double? amount;
  final double? approvedAmount;
  final String? currency;
  final String? status;
  final String? priority;
  final String? supportingDocs;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined/enriched fields
  final String? projectName;
  final String? ownerName;
  final String? requestedByName;

  const FundRequest({
    required this.id,
    this.projectId,
    this.accountId,
    this.ownerId,
    this.requestedBy,
    this.title,
    this.description,
    this.category,
    this.amount,
    this.approvedAmount,
    this.currency,
    this.status,
    this.priority,
    this.supportingDocs,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.projectName,
    this.ownerName,
    this.requestedByName,
  });

  factory FundRequest.fromJson(Map<String, dynamic> json) {
    final projects = JsonHelpers.toMap(json['projects']);
    final users = JsonHelpers.toMap(json['users']);

    return FundRequest(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      ownerId: json['owner_id']?.toString(),
      requestedBy: json['requested_by']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      amount: JsonHelpers.toDouble(json['amount']),
      approvedAmount: JsonHelpers.toDouble(json['approved_amount']),
      currency: json['currency']?.toString(),
      status: json['status']?.toString(),
      priority: json['priority']?.toString(),
      supportingDocs: json['supporting_docs']?.toString(),
      dueDate: JsonHelpers.tryParseDate(json['due_date']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      updatedAt: JsonHelpers.tryParseDate(json['updated_at']),
      projectName: projects?['name']?.toString() ?? json['project_name']?.toString(),
      ownerName: users?['full_name']?.toString(),
      requestedByName: json['requested_by_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'account_id': accountId,
    'owner_id': ownerId,
    'requested_by': requestedBy,
    'title': title,
    'description': description,
    'category': category,
    'amount': amount,
    'approved_amount': approvedAmount,
    'currency': currency,
    'status': status,
    'priority': priority,
    'supporting_docs': supportingDocs,
    'due_date': dueDate?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get isPartial => status == 'partial';

  FundRequest copyWith({
    String? id,
    String? projectId,
    String? accountId,
    String? ownerId,
    String? requestedBy,
    String? title,
    String? description,
    String? category,
    double? amount,
    double? approvedAmount,
    String? currency,
    String? status,
    String? priority,
    String? supportingDocs,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectName,
    String? ownerName,
    String? requestedByName,
  }) {
    return FundRequest(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      ownerId: ownerId ?? this.ownerId,
      requestedBy: requestedBy ?? this.requestedBy,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      supportingDocs: supportingDocs ?? this.supportingDocs,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectName: projectName ?? this.projectName,
      ownerName: ownerName ?? this.ownerName,
      requestedByName: requestedByName ?? this.requestedByName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FundRequest && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FundRequest(id: $id, status: $status, amount: $amount)';
}
