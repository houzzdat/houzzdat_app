import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/services/error_logging_service.dart';

/// Represents a single review item from any domain (materials, payments, milestones).
class ReviewItem {
  final String id;
  final String table;
  final String domain; // 'material', 'payment', 'invoice'
  final String title;
  final String? subtitle;
  final double? amount;
  final String? voiceNoteId;
  final String? audioUrl;
  final String? transcriptSnippet;
  final double? confidence;
  final bool needsConfirmation;
  final String? possibleDuplicateOf;
  final String completenessStatus;
  final List<String> missingFields;
  final DateTime createdAt;
  final String projectId;

  ReviewItem({
    required this.id,
    required this.table,
    required this.domain,
    required this.title,
    this.subtitle,
    this.amount,
    this.voiceNoteId,
    this.audioUrl,
    this.transcriptSnippet,
    this.confidence,
    required this.needsConfirmation,
    this.possibleDuplicateOf,
    this.completenessStatus = 'complete',
    this.missingFields = const [],
    required this.createdAt,
    required this.projectId,
  });

  bool get isPossibleDuplicate => possibleDuplicateOf != null;
  bool get isIncomplete => completenessStatus == 'incomplete';
}

class ReviewQueueService {
  final _supabase = Supabase.instance.client;

  /// Get total count of unreviewed items across all domains.
  Future<int> getUnreviewedCount(String accountId) async {
    try {
      final results = await Future.wait([
        _supabase
            .from('material_specs')
            .select('id')
            .eq('account_id', accountId)
            .eq('auto_created', true)
            .or('needs_confirmation.eq.true,possible_duplicate_of.not.is.null'),
        _supabase
            .from('payments')
            .select('id')
            .eq('account_id', accountId)
            .eq('auto_created', true)
            .or('needs_confirmation.eq.true,possible_duplicate_of.not.is.null'),
        _supabase
            .from('invoices')
            .select('id')
            .eq('account_id', accountId)
            .eq('auto_created', true)
            .not('possible_duplicate_of', 'is', null),
      ]);

      int total = 0;
      for (final result in results) {
        total += (result as List).length;
      }
      return total;
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: 'ReviewQueueService.getUnreviewedCount');
      return 0;
    }
  }

  /// Get all review items for a given account, optionally filtered by domain.
  Future<List<ReviewItem>> getItemsForReview(
    String accountId, {
    String? domain,
    String? projectId,
  }) async {
    final items = <ReviewItem>[];

    if (domain == null || domain == 'material') {
      items.addAll(await _getMaterialReviewItems(accountId, projectId));
    }
    if (domain == null || domain == 'payment') {
      items.addAll(await _getPaymentReviewItems(accountId, projectId));
      items.addAll(await _getInvoiceReviewItems(accountId, projectId));
    }

    // Sort by created_at descending
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<ReviewItem>> _getMaterialReviewItems(
    String accountId,
    String? projectId,
  ) async {
    try {
      var query = _supabase
          .from('material_specs')
          // Use source_voice_note_id (the canonical FK for AI-created records)
          .select('*, voice_notes:source_voice_note_id(audio_url, transcript_raw)')
          .eq('account_id', accountId)
          .eq('auto_created', true)
          .or('needs_confirmation.eq.true,possible_duplicate_of.not.is.null');

      if (projectId != null) {
        query = query.eq('project_id', projectId);
      }

      final data = await query.order('created_at', ascending: false).limit(50);
      return (data as List).map((row) {
        final vn = row['voice_notes'] as Map<String, dynamic>?;
        return ReviewItem(
          id: row['id'],
          table: 'material_specs',
          domain: 'material',
          title: row['material_name'] ?? 'Unknown material',
          subtitle: '${row['quantity'] ?? '?'} ${row['unit'] ?? ''}'.trim(),
          voiceNoteId: row['source_voice_note_id'],
          audioUrl: vn?['audio_url'],
          transcriptSnippet: _truncate(vn?['transcript_raw'], 100),
          needsConfirmation: row['needs_confirmation'] == true,
          possibleDuplicateOf: row['possible_duplicate_of'],
          completenessStatus: row['completeness_status'] ?? 'complete',
          missingFields: List<String>.from(row['missing_fields'] ?? []),
          createdAt: DateTime.parse(row['created_at']),
          projectId: row['project_id'],
        );
      }).toList();
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: 'ReviewQueueService._getMaterialReviewItems');
      return [];
    }
  }

  Future<List<ReviewItem>> _getPaymentReviewItems(
    String accountId,
    String? projectId,
  ) async {
    try {
      var query = _supabase
          .from('payments')
          .select('*, voice_notes:source_voice_note_id(audio_url, transcript_raw)')
          .eq('account_id', accountId)
          .eq('auto_created', true)
          .or('needs_confirmation.eq.true,possible_duplicate_of.not.is.null');

      if (projectId != null) {
        query = query.eq('project_id', projectId);
      }

      final data = await query.order('created_at', ascending: false).limit(50);
      return (data as List).map((row) {
        final vn = row['voice_notes'] as Map<String, dynamic>?;
        return ReviewItem(
          id: row['id'],
          table: 'payments',
          domain: 'payment',
          title: 'Payment to ${row['paid_to'] ?? 'Unknown'}',
          subtitle: row['description'],
          amount: (row['amount'] as num?)?.toDouble(),
          voiceNoteId: row['source_voice_note_id'],
          audioUrl: vn?['audio_url'],
          transcriptSnippet: _truncate(vn?['transcript_raw'], 100),
          needsConfirmation: row['needs_confirmation'] == true,
          possibleDuplicateOf: row['possible_duplicate_of'],
          completenessStatus: row['completeness_status'] ?? 'complete',
          missingFields: List<String>.from(row['missing_fields'] ?? []),
          createdAt: DateTime.parse(row['created_at']),
          projectId: row['project_id'],
        );
      }).toList();
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: 'ReviewQueueService._getPaymentReviewItems');
      return [];
    }
  }

  Future<List<ReviewItem>> _getInvoiceReviewItems(
    String accountId,
    String? projectId,
  ) async {
    try {
      var query = _supabase
          .from('invoices')
          .select('*, voice_notes:source_voice_note_id(audio_url, transcript_raw)')
          .eq('account_id', accountId)
          .eq('auto_created', true)
          .not('possible_duplicate_of', 'is', null);

      if (projectId != null) {
        query = query.eq('project_id', projectId);
      }

      final data = await query.order('created_at', ascending: false).limit(50);
      return (data as List).map((row) {
        final vn = row['voice_notes'] as Map<String, dynamic>?;
        return ReviewItem(
          id: row['id'],
          table: 'invoices',
          domain: 'payment',
          title: 'Invoice from ${row['vendor'] ?? 'Unknown vendor'}',
          subtitle: row['description'],
          amount: (row['amount'] as num?)?.toDouble(),
          voiceNoteId: row['source_voice_note_id'],
          audioUrl: vn?['audio_url'],
          transcriptSnippet: _truncate(vn?['transcript_raw'], 100),
          needsConfirmation: true,
          possibleDuplicateOf: row['possible_duplicate_of'],
          createdAt: DateTime.parse(row['created_at']),
          projectId: row['project_id'],
        );
      }).toList();
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: 'ReviewQueueService._getInvoiceReviewItems');
      return [];
    }
  }

  /// Confirm a record — mark as reviewed and accepted.
  ///
  /// [isDuplicate] should be true when the record was flagged as a possible
  /// duplicate (i.e. [ReviewItem.isPossibleDuplicate] == true), so that we
  /// also clear the `possible_duplicate_of` field.  For records that only had
  /// `needs_confirmation == true` (no duplicate flag) we leave
  /// `possible_duplicate_of` untouched to avoid an unnecessary write.
  Future<void> confirmRecord(
    String table,
    String id, {
    bool isDuplicate = false,
  }) async {
    final payload = <String, dynamic>{
      'needs_confirmation': false,
    };
    // Only clear the duplicate pointer when the item was actually flagged as one.
    if (isDuplicate) {
      payload['possible_duplicate_of'] = null;
    }
    await _supabase.from(table).update(payload).eq('id', id);
  }

  /// Dismiss a record — delete it and log an AI correction.
  Future<void> dismissRecord(
    String table,
    String id, {
    required String voiceNoteId,
    String correctionType = 'review_dismissed',
  }) async {
    // Log correction for AI feedback
    await _supabase.from('ai_corrections').insert({
      'voice_note_id': voiceNoteId,
      'correction_type': correctionType,
      'original_value': '$table:$id',
      'corrected_value': 'dismissed',
      'corrected_by': _supabase.auth.currentUser?.id,
    });

    // Delete the auto-created record
    await _supabase.from(table).delete().eq('id', id);
  }

  /// Merge a duplicate record into the original.
  /// Keeps the original, deletes the duplicate, logs the correction.
  Future<void> mergeRecords(
    String table,
    String keepId,
    String deleteId, {
    required String voiceNoteId,
  }) async {
    // Log correction
    await _supabase.from('ai_corrections').insert({
      'voice_note_id': voiceNoteId,
      'correction_type': 'review_dismissed',
      'original_value': '$table:$deleteId',
      'corrected_value': 'merged_into:$keepId',
      'corrected_by': _supabase.auth.currentUser?.id,
    });

    // Delete the duplicate
    await _supabase.from(table).delete().eq('id', deleteId);

    // Clear duplicate flag on the original if it had one
    await _supabase.from(table).update({
      'possible_duplicate_of': null,
    }).eq('id', keepId);
  }

  String? _truncate(String? text, int maxLength) {
    if (text == null) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
