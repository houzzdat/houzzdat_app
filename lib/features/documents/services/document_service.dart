import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/models/models.dart';

class DocumentService {
  final _supabase = Supabase.instance.client;
  static const _bucket = 'construction-documents';

  // ---------------------------------------------------------------------------
  // QUERIES
  // ---------------------------------------------------------------------------

  Future<List<Document>> getDocuments({
    required String projectId,
    DocumentCategory? category,
    DocumentApprovalStatus? status,
    String? search,
  }) async {
    try {
      var query = _supabase
          .from('documents')
          .select()
          .eq('project_id', projectId);

      if (category != null) {
        query = query.eq('category', category.dbValue);
      }
      if (status != null) {
        query = query.eq('approval_status', status.dbValue);
      }

      final data = await query.order('created_at', ascending: false);
      var docs = (data as List)
          .map((row) => Document.fromMap(row as Map<String, dynamic>))
          .toList();

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        docs = docs.where((d) =>
          d.name.toLowerCase().contains(q) ||
          (d.subcategory?.toLowerCase().contains(q) ?? false) ||
          d.tags.any((t) => t.toLowerCase().contains(q))
        ).toList();
      }

      return docs;
    } catch (e) {
      debugPrint('[DocumentService] getDocuments error: $e');
      return [];
    }
  }

  /// Get documents pending owner approval for an account
  Future<List<Document>> getPendingApprovals(String accountId) async {
    try {
      final data = await _supabase
          .from('documents')
          .select()
          .eq('account_id', accountId)
          .eq('requires_owner_approval', true)
          .eq('approval_status', 'pending_approval')
          .order('created_at', ascending: false);

      return (data as List)
          .map((row) => Document.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DocumentService] getPendingApprovals error: $e');
      return [];
    }
  }

  /// Get version history for a document (chain of versions)
  Future<List<Document>> getVersionHistory(String documentId) async {
    try {
      // Fetch the root document first
      final docData = await _supabase
          .from('documents')
          .select()
          .eq('id', documentId)
          .maybeSingle();

      if (docData == null) return [];

      final doc = Document.fromMap(docData);

      // Find root (walk up parent chain)
      String rootId = documentId;
      if (doc.parentDocumentId != null) {
        // Get all docs with same name in the project to form the chain
        final allVersions = await _supabase
            .from('documents')
            .select()
            .eq('project_id', doc.projectId)
            .eq('name', doc.name)
            .order('version_number', ascending: true);

        return (allVersions as List)
            .map((row) => Document.fromMap(row as Map<String, dynamic>))
            .toList();
      }

      // Check if this is the root — find all documents with this as parent
      final versions = await _supabase
          .from('documents')
          .select()
          .eq('project_id', doc.projectId)
          .eq('name', doc.name)
          .order('version_number', ascending: true);

      return (versions as List)
          .map((row) => Document.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DocumentService] getVersionHistory error: $e');
      return [];
    }
  }

  Future<List<DocumentComment>> getComments(String documentId) async {
    try {
      final data = await _supabase
          .from('document_comments')
          .select()
          .eq('document_id', documentId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((row) => DocumentComment.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DocumentService] getComments error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // UPLOAD
  // ---------------------------------------------------------------------------

  Future<Document> uploadDocument({
    required File file,
    required String projectId,
    required String accountId,
    required String name,
    required DocumentCategory category,
    String? subcategory,
    String? versionNotes,
    bool requiresOwnerApproval = false,
    DateTime? expiresAt,
    List<String> tags = const [],
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    final ext = file.path.split('.').last.toLowerCase();
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;

    // Detect if a previous version exists
    final existingData = await _supabase
        .from('documents')
        .select('id, version_number')
        .eq('project_id', projectId)
        .eq('name', name)
        .order('version_number', ascending: false)
        .limit(1)
        .maybeSingle();

    final prevId = existingData?['id'] as String?;
    final prevVersion = existingData?['version_number'] as int? ?? 0;
    final newVersion = prevVersion + 1;

    // Build storage path
    final safeName = name.replaceAll(RegExp(r'[^\w.-]'), '_');
    final filePath = '$accountId/$projectId/${category.dbValue}/${safeName}_v$newVersion.$ext';

    // Upload to Supabase Storage
    await _supabase.storage.from(_bucket).uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(upsert: true),
    );

    final fileUrl = _supabase.storage.from(_bucket).getPublicUrl(filePath);

    // Determine MIME type
    String? mimeType;
    if (ext == 'pdf') mimeType = 'application/pdf';
    else if (['jpg', 'jpeg'].contains(ext)) mimeType = 'image/jpeg';
    else if (ext == 'png') mimeType = 'image/png';
    else if (ext == 'dwg') mimeType = 'application/acad';

    // Insert DB record
    final approvalStatus = requiresOwnerApproval ? 'pending_approval' : 'draft';

    final inserted = await _supabase.from('documents').insert({
      'project_id': projectId,
      'account_id': accountId,
      'uploaded_by': userId,
      'name': name,
      'category': category.dbValue,
      'subcategory': subcategory,
      'file_path': filePath,
      'file_url': fileUrl,
      'file_size_bytes': fileSize,
      'mime_type': mimeType,
      'version_number': newVersion,
      'parent_document_id': prevId,
      'version_notes': versionNotes,
      'requires_owner_approval': requiresOwnerApproval,
      'approval_status': approvalStatus,
      'expires_at': expiresAt?.toIso8601String().split('T')[0],
      'tags': tags,
    }).select().single();

    final doc = Document.fromMap(inserted);

    // Log the upload action
    await _logAccess(doc.id, 'upload');

    // Trigger notification edge function for owner approval
    if (requiresOwnerApproval) {
      try {
        await _supabase.functions.invoke('process-document-upload', body: {
          'document_id': doc.id,
          'account_id': accountId,
          'project_id': projectId,
        });
      } catch (e) {
        debugPrint('[DocumentService] process-document-upload edge fn error: $e');
      }
    }

    return doc;
  }

  // ---------------------------------------------------------------------------
  // APPROVAL WORKFLOW
  // ---------------------------------------------------------------------------

  Future<void> approveDocument(String documentId, {String? comment}) async {
    final userId = _supabase.auth.currentUser?.id;

    await _supabase.from('documents').update({
      'approval_status': 'approved',
      'approved_by': userId,
      'approved_at': DateTime.now().toIso8601String(),
      'rejection_reason': null,
    }).eq('id', documentId);

    if (comment != null && comment.trim().isNotEmpty) {
      await addComment(documentId, comment.trim());
    }

    await _logAccess(documentId, 'approve');
  }

  Future<void> rejectDocument(String documentId, String reason) async {
    final userId = _supabase.auth.currentUser?.id;

    await _supabase.from('documents').update({
      'approval_status': 'rejected',
      'rejection_reason': reason,
      'approved_by': userId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', documentId);

    await _logAccess(documentId, 'reject', metadata: {'reason': reason});
  }

  Future<void> requestChanges(String documentId, String comment) async {
    await _supabase.from('documents').update({
      'approval_status': 'changes_requested',
      'rejection_reason': comment,
    }).eq('id', documentId);

    await addComment(documentId, 'Changes requested: $comment');
    await _logAccess(documentId, 'reject', metadata: {'type': 'changes_requested'});
  }

  // ---------------------------------------------------------------------------
  // COMMENTS
  // ---------------------------------------------------------------------------

  Future<DocumentComment> addComment(String documentId, String text) async {
    final userId = _supabase.auth.currentUser?.id;
    final inserted = await _supabase.from('document_comments').insert({
      'document_id': documentId,
      'user_id': userId,
      'comment': text,
    }).select().single();

    return DocumentComment.fromMap(inserted);
  }

  // ---------------------------------------------------------------------------
  // EXPIRY
  // ---------------------------------------------------------------------------

  Future<List<Document>> getExpiringDocuments(String accountId) async {
    try {
      final threshold = DateTime.now().add(const Duration(days: 30));
      final data = await _supabase
          .from('documents')
          .select()
          .eq('account_id', accountId)
          .not('expires_at', 'is', null)
          .lte('expires_at', threshold.toIso8601String().split('T')[0])
          .order('expires_at', ascending: true);

      return (data as List)
          .map((row) => Document.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DocumentService] getExpiringDocuments error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _logAccess(String documentId, String action,
      {Map<String, dynamic>? metadata}) async {
    try {
      await _supabase.from('document_access_log').insert({
        'document_id': documentId,
        'user_id': _supabase.auth.currentUser?.id,
        'action': action,
        'metadata': metadata ?? {},
      });
    } catch (_) {
      // Non-critical; don't throw
    }
  }

  Future<void> logView(String documentId) async {
    await _logAccess(documentId, 'view');
  }

  Future<void> logDownload(String documentId) async {
    await _logAccess(documentId, 'download');
  }

  /// Check if a document name already exists in the project (for version detection)
  Future<int> getExistingVersionCount(String projectId, String name) async {
    try {
      final result = await _supabase
          .from('documents')
          .select()
          .eq('project_id', projectId)
          .eq('name', name)
          .count(CountOption.exact);
      return result.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
