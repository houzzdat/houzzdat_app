import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `invoices` table.
///
/// CI-07: Used in invoice_card.dart, site_finances_subtab.dart,
/// and finance_overview_card.dart.
class Invoice {
  final String id;
  final String? projectId;
  final String? accountId;
  final String? submittedBy;
  final String? vendorName;
  final String? invoiceNumber;
  final String? description;
  final double? amount;
  final double? totalAmount;
  final String? currency;
  final String? status;
  final String? category;
  final String? attachmentUrl;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined/enriched fields
  final String? projectName;
  final String? submittedByName;

  const Invoice({
    required this.id,
    this.projectId,
    this.accountId,
    this.submittedBy,
    this.vendorName,
    this.invoiceNumber,
    this.description,
    this.amount,
    this.totalAmount,
    this.currency,
    this.status,
    this.category,
    this.attachmentUrl,
    this.invoiceDate,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.projectName,
    this.submittedByName,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final projects = JsonHelpers.toMap(json['projects']);
    final users = JsonHelpers.toMap(json['users']);

    return Invoice(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      submittedBy: json['submitted_by']?.toString(),
      vendorName: json['vendor_name']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      description: json['description']?.toString(),
      amount: JsonHelpers.toDouble(json['amount']),
      totalAmount: JsonHelpers.toDouble(json['total_amount']),
      currency: json['currency']?.toString(),
      status: json['status']?.toString(),
      category: json['category']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      invoiceDate: JsonHelpers.tryParseDate(json['invoice_date']),
      dueDate: JsonHelpers.tryParseDate(json['due_date']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      updatedAt: JsonHelpers.tryParseDate(json['updated_at']),
      projectName: projects?['name']?.toString() ?? json['project_name']?.toString(),
      submittedByName: users?['full_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'account_id': accountId,
    'submitted_by': submittedBy,
    'vendor_name': vendorName,
    'invoice_number': invoiceNumber,
    'description': description,
    'amount': amount,
    'total_amount': totalAmount,
    'currency': currency,
    'status': status,
    'category': category,
    'attachment_url': attachmentUrl,
    'invoice_date': invoiceDate?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';
  bool get isRejected => status == 'rejected';

  Invoice copyWith({
    String? id,
    String? projectId,
    String? accountId,
    String? submittedBy,
    String? vendorName,
    String? invoiceNumber,
    String? description,
    double? amount,
    double? totalAmount,
    String? currency,
    String? status,
    String? category,
    String? attachmentUrl,
    DateTime? invoiceDate,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectName,
    String? submittedByName,
  }) {
    return Invoice(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      submittedBy: submittedBy ?? this.submittedBy,
      vendorName: vendorName ?? this.vendorName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      category: category ?? this.category,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectName: projectName ?? this.projectName,
      submittedByName: submittedByName ?? this.submittedByName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Invoice && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Invoice(id: $id, vendor: $vendorName, amount: $amount, status: $status)';
}
