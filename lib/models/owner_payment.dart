import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `owner_payments` table.
///
/// CI-07: Used in owner_payment_card.dart, owner_finances_subtab.dart,
/// finance_overview_card.dart, and finance_export_service.dart.
class OwnerPayment {
  final String id;
  final String? projectId;
  final String? accountId;
  final String? ownerId;
  final double? amount;
  final String? currency;
  final String? paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final String? status;
  final bool confirmed;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final DateTime? receivedDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined/enriched fields
  final String? projectName;
  final String? ownerName;
  final String? confirmedByName;

  const OwnerPayment({
    required this.id,
    this.projectId,
    this.accountId,
    this.ownerId,
    this.amount,
    this.currency,
    this.paymentMethod,
    this.referenceNumber,
    this.notes,
    this.status,
    this.confirmed = false,
    this.confirmedBy,
    this.confirmedAt,
    this.receivedDate,
    this.createdAt,
    this.updatedAt,
    this.projectName,
    this.ownerName,
    this.confirmedByName,
  });

  factory OwnerPayment.fromJson(Map<String, dynamic> json) {
    final projects = JsonHelpers.toMap(json['projects']);
    final users = JsonHelpers.toMap(json['users']);
    final confirmedByUser = JsonHelpers.toMap(json['confirmed_by_user']);

    return OwnerPayment(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      ownerId: json['owner_id']?.toString(),
      amount: JsonHelpers.toDouble(json['amount']),
      currency: json['currency']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      referenceNumber: json['reference_number']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      confirmed: JsonHelpers.toBool(json['confirmed']),
      confirmedBy: json['confirmed_by']?.toString(),
      confirmedAt: JsonHelpers.tryParseDate(json['confirmed_at']),
      receivedDate: JsonHelpers.tryParseDate(json['received_date']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      updatedAt: JsonHelpers.tryParseDate(json['updated_at']),
      projectName: projects?['name']?.toString() ?? json['project_name']?.toString(),
      ownerName: users?['full_name']?.toString(),
      confirmedByName: confirmedByUser?['full_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'account_id': accountId,
    'owner_id': ownerId,
    'amount': amount,
    'currency': currency,
    'payment_method': paymentMethod,
    'reference_number': referenceNumber,
    'notes': notes,
    'status': status,
    'confirmed': confirmed,
    'confirmed_by': confirmedBy,
    'confirmed_at': confirmedAt?.toIso8601String(),
    'received_date': receivedDate?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  OwnerPayment copyWith({
    String? id,
    String? projectId,
    String? accountId,
    String? ownerId,
    double? amount,
    String? currency,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
    String? status,
    bool? confirmed,
    String? confirmedBy,
    DateTime? confirmedAt,
    DateTime? receivedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectName,
    String? ownerName,
    String? confirmedByName,
  }) {
    return OwnerPayment(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      ownerId: ownerId ?? this.ownerId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      confirmed: confirmed ?? this.confirmed,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      receivedDate: receivedDate ?? this.receivedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectName: projectName ?? this.projectName,
      ownerName: ownerName ?? this.ownerName,
      confirmedByName: confirmedByName ?? this.confirmedByName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OwnerPayment && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OwnerPayment(id: $id, amount: $amount, confirmed: $confirmed)';
}
