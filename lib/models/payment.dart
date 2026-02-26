import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `payments` table (site-level payments).
///
/// CI-07: Used in payment_card.dart, site_finances_subtab.dart,
/// and finance_overview_card.dart.
class Payment {
  final String id;
  final String? projectId;
  final String? accountId;
  final String? invoiceId;
  final String? paidBy;
  final String? vendorName;
  final String? description;
  final double? amount;
  final String? currency;
  final String? paymentMethod;
  final String? referenceNumber;
  final String? status;
  final String? category;
  final DateTime? paymentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined/enriched fields
  final String? projectName;

  const Payment({
    required this.id,
    this.projectId,
    this.accountId,
    this.invoiceId,
    this.paidBy,
    this.vendorName,
    this.description,
    this.amount,
    this.currency,
    this.paymentMethod,
    this.referenceNumber,
    this.status,
    this.category,
    this.paymentDate,
    this.createdAt,
    this.updatedAt,
    this.projectName,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final projects = JsonHelpers.toMap(json['projects']);

    return Payment(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      invoiceId: json['invoice_id']?.toString(),
      paidBy: json['paid_by']?.toString(),
      vendorName: json['vendor_name']?.toString(),
      description: json['description']?.toString(),
      amount: JsonHelpers.toDouble(json['amount']),
      currency: json['currency']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      referenceNumber: json['reference_number']?.toString(),
      status: json['status']?.toString(),
      category: json['category']?.toString(),
      paymentDate: JsonHelpers.tryParseDate(json['payment_date']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      updatedAt: JsonHelpers.tryParseDate(json['updated_at']),
      projectName: projects?['name']?.toString() ?? json['project_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'account_id': accountId,
    'invoice_id': invoiceId,
    'paid_by': paidBy,
    'vendor_name': vendorName,
    'description': description,
    'amount': amount,
    'currency': currency,
    'payment_method': paymentMethod,
    'reference_number': referenceNumber,
    'status': status,
    'category': category,
    'payment_date': paymentDate?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  Payment copyWith({
    String? id,
    String? projectId,
    String? accountId,
    String? invoiceId,
    String? paidBy,
    String? vendorName,
    String? description,
    double? amount,
    String? currency,
    String? paymentMethod,
    String? referenceNumber,
    String? status,
    String? category,
    DateTime? paymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectName,
  }) {
    return Payment(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      invoiceId: invoiceId ?? this.invoiceId,
      paidBy: paidBy ?? this.paidBy,
      vendorName: vendorName ?? this.vendorName,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      category: category ?? this.category,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectName: projectName ?? this.projectName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Payment && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Payment(id: $id, amount: $amount, status: $status)';
}
