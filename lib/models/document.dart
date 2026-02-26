import 'package:houzzdat_app/models/json_helpers.dart';

class Document {
  final String id;
  final String projectId;
  final String accountId;
  final String? uploadedBy;
  final String name;
  final DocumentCategory category;
  final String? subcategory;
  final String filePath;
  final String fileUrl;
  final int? fileSizeBytes;
  final String? mimeType;
  final int versionNumber;
  final String? parentDocumentId;
  final String? versionNotes;
  final bool requiresOwnerApproval;
  final DocumentApprovalStatus approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? expiresAt;
  final bool expiryNotified;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Document({
    required this.id,
    required this.projectId,
    required this.accountId,
    this.uploadedBy,
    required this.name,
    required this.category,
    this.subcategory,
    required this.filePath,
    required this.fileUrl,
    this.fileSizeBytes,
    this.mimeType,
    required this.versionNumber,
    this.parentDocumentId,
    this.versionNotes,
    required this.requiresOwnerApproval,
    required this.approvalStatus,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.expiresAt,
    required this.expiryNotified,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Document.fromMap(Map<String, dynamic> map) {
    final tagList = map['tags'];
    List<String> tags = [];
    if (tagList is List) {
      tags = tagList.map((e) => e.toString()).toList();
    }

    return Document(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      accountId: map['account_id'] as String,
      uploadedBy: map['uploaded_by'] as String?,
      name: map['name'] as String,
      category: DocumentCategory.fromString(map['category'] as String? ?? 'other'),
      subcategory: map['subcategory'] as String?,
      filePath: map['file_path'] as String,
      fileUrl: map['file_url'] as String,
      fileSizeBytes: JsonHelpers.toInt(map['file_size_bytes']),
      mimeType: map['mime_type'] as String?,
      versionNumber: JsonHelpers.toInt(map['version_number']) ?? 1,
      parentDocumentId: map['parent_document_id'] as String?,
      versionNotes: map['version_notes'] as String?,
      requiresOwnerApproval: JsonHelpers.toBool(map['requires_owner_approval']) ?? false,
      approvalStatus: DocumentApprovalStatus.fromString(map['approval_status'] as String? ?? 'draft'),
      approvedBy: map['approved_by'] as String?,
      approvedAt: JsonHelpers.tryParseDate(map['approved_at']),
      rejectionReason: map['rejection_reason'] as String?,
      expiresAt: JsonHelpers.tryParseDate(map['expires_at']),
      expiryNotified: JsonHelpers.toBool(map['expiry_notified']) ?? false,
      tags: tags,
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
      updatedAt: JsonHelpers.tryParseDate(map['updated_at']) ?? DateTime.now(),
    );
  }

  /// Returns formatted file size for display
  String get fileSizeDisplay {
    if (fileSizeBytes == null) return '';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// True if document expires within the next 30 days
  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    final daysToExpiry = expiresAt!.difference(DateTime.now()).inDays;
    return daysToExpiry >= 0 && daysToExpiry <= 30;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get isPendingApproval => approvalStatus == DocumentApprovalStatus.pendingApproval;
  bool get isApproved => approvalStatus == DocumentApprovalStatus.approved;
  bool get isDraft => approvalStatus == DocumentApprovalStatus.draft;

  bool get isPdf => mimeType == 'application/pdf' ||
      filePath.toLowerCase().endsWith('.pdf');
  bool get isImage => mimeType?.startsWith('image/') == true ||
      filePath.toLowerCase().endsWith('.jpg') ||
      filePath.toLowerCase().endsWith('.jpeg') ||
      filePath.toLowerCase().endsWith('.png');

  bool get isFirstVersion => parentDocumentId == null;
}

enum DocumentCategory {
  legalStatutory,
  technicalDrawings,
  qualityCertificates,
  contractsFinancial,
  progressReports,
  other;

  static DocumentCategory fromString(String s) {
    switch (s) {
      case 'legal_statutory': return legalStatutory;
      case 'technical_drawings': return technicalDrawings;
      case 'quality_certificates': return qualityCertificates;
      case 'contracts_financial': return contractsFinancial;
      case 'progress_reports': return progressReports;
      default: return other;
    }
  }

  String get dbValue {
    switch (this) {
      case legalStatutory: return 'legal_statutory';
      case technicalDrawings: return 'technical_drawings';
      case qualityCertificates: return 'quality_certificates';
      case contractsFinancial: return 'contracts_financial';
      case progressReports: return 'progress_reports';
      default: return 'other';
    }
  }

  String get label {
    switch (this) {
      case legalStatutory: return 'Legal & Statutory';
      case technicalDrawings: return 'Technical Drawings';
      case qualityCertificates: return 'Quality Certificates';
      case contractsFinancial: return 'Contracts & Finance';
      case progressReports: return 'Progress Reports';
      default: return 'Other';
    }
  }

  String get shortLabel {
    switch (this) {
      case legalStatutory: return 'Legal';
      case technicalDrawings: return 'Drawings';
      case qualityCertificates: return 'Quality';
      case contractsFinancial: return 'Contracts';
      case progressReports: return 'Reports';
      default: return 'Other';
    }
  }

  List<String> get subcategories {
    switch (this) {
      case legalStatutory:
        return ['Sale Deed', 'Khata Certificate', 'Encumbrance Certificate',
          'Building Plan Approval', 'RERA Registration', 'Fire NOC',
          'Pollution NOC', 'BESCOM Connection', 'BWSSB Connection', 'Other'];
      case technicalDrawings:
        return ['Architectural Plan', 'Structural Drawing', 'MEP Layout',
          'Bar Bending Schedule', 'Site Plan', 'Other'];
      case qualityCertificates:
        return ['Soil Test Report', 'Concrete Cube Test', 'Steel Test Certificate',
          'Anti-termite Certificate', 'Waterproofing Warranty', 'Other'];
      case contractsFinancial:
        return ['Contractor Agreement', 'Material Invoice', 'Running Bill',
          'Work Order', 'Purchase Order', 'Other'];
      case progressReports:
        return ['Daily Report', 'Weekly Report', 'Monthly Report',
          'Site Photos', 'AI Report', 'Inspection Report', 'Other'];
      default:
        return ['Other'];
    }
  }
}

enum DocumentApprovalStatus {
  draft,
  pendingApproval,
  approved,
  rejected,
  changesRequested;

  static DocumentApprovalStatus fromString(String s) {
    switch (s) {
      case 'pending_approval': return pendingApproval;
      case 'approved': return approved;
      case 'rejected': return rejected;
      case 'changes_requested': return changesRequested;
      default: return draft;
    }
  }

  String get dbValue {
    switch (this) {
      case pendingApproval: return 'pending_approval';
      case approved: return 'approved';
      case rejected: return 'rejected';
      case changesRequested: return 'changes_requested';
      default: return 'draft';
    }
  }

  String get label {
    switch (this) {
      case pendingApproval: return 'Pending Approval';
      case approved: return 'Approved';
      case rejected: return 'Rejected';
      case changesRequested: return 'Changes Requested';
      default: return 'Draft';
    }
  }
}

class DocumentComment {
  final String id;
  final String documentId;
  final String? userId;
  final String comment;
  final DateTime createdAt;

  const DocumentComment({
    required this.id,
    required this.documentId,
    this.userId,
    required this.comment,
    required this.createdAt,
  });

  factory DocumentComment.fromMap(Map<String, dynamic> map) {
    return DocumentComment(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      userId: map['user_id'] as String?,
      comment: map['comment'] as String,
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
    );
  }
}

class DocumentAccessLog {
  final String id;
  final String documentId;
  final String? userId;
  final String action;
  final Map<String, dynamic> metadata;
  final DateTime accessedAt;

  const DocumentAccessLog({
    required this.id,
    required this.documentId,
    this.userId,
    required this.action,
    required this.metadata,
    required this.accessedAt,
  });

  factory DocumentAccessLog.fromMap(Map<String, dynamic> map) {
    return DocumentAccessLog(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      userId: map['user_id'] as String?,
      action: map['action'] as String,
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
      accessedAt: JsonHelpers.tryParseDate(map['accessed_at']) ?? DateTime.now(),
    );
  }
}
