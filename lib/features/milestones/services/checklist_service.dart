import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/models/models.dart';

class ChecklistService {
  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // CHECKLIST ITEMS + COMPLETION STATE
  // ---------------------------------------------------------------------------

  /// Loads checklist items for a phase gate, joined with completion state
  Future<List<ChecklistItemWithCompletion>> getChecklistForPhase({
    required String phaseId,
    required String moduleId,
    required ChecklistGateType gateType,
    required String projectId,
    required String accountId,
  }) async {
    try {
      // Fetch template items for this module + gate type
      final itemsData = await _supabase
          .from('milestone_checklists')
          .select()
          .eq('module_id', moduleId)
          .eq('gate_type', gateType.dbValue)
          .eq('is_active', true)
          .order('sequence_order', ascending: true);

      final items = (itemsData as List)
          .map((row) => ChecklistItem.fromMap(row as Map<String, dynamic>))
          .toList();

      if (items.isEmpty) return [];

      // Fetch existing completions for this phase
      final completionsData = await _supabase
          .from('checklist_completions')
          .select()
          .eq('phase_id', phaseId);

      final completionsMap = <String, ChecklistCompletion>{};
      for (final row in (completionsData as List)) {
        final c = ChecklistCompletion.fromMap(row as Map<String, dynamic>);
        completionsMap[c.checklistItemId] = c;
      }

      // Pair each item with its completion state (or null if not started)
      return items.map((item) => ChecklistItemWithCompletion(
        item: item,
        completion: completionsMap[item.id],
      )).toList();
    } catch (e) {
      debugPrint('[ChecklistService] getChecklistForPhase error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // COMPLETION ACTIONS
  // ---------------------------------------------------------------------------

  /// Toggle a checklist item as complete/incomplete
  Future<ChecklistCompletion> toggleItemComplete({
    required String? existingCompletionId,
    required String checklistItemId,
    required String phaseId,
    required String projectId,
    required String accountId,
    required bool isCompleted,
    String? evidenceUrl,
    EvidenceRequiredType? evidenceType,
    String? overrideReason,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    if (existingCompletionId != null) {
      // Update existing record
      final updated = await _supabase
          .from('checklist_completions')
          .update({
            'is_completed': isCompleted,
            'completed_by': isCompleted ? userId : null,
            'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
            'evidence_url': evidenceUrl,
            'evidence_type': evidenceType?.dbValue,
            'override_reason': overrideReason,
          })
          .eq('id', existingCompletionId)
          .select()
          .single();
      return ChecklistCompletion.fromMap(updated);
    } else {
      // Insert new record
      final inserted = await _supabase
          .from('checklist_completions')
          .insert({
            'phase_id': phaseId,
            'checklist_item_id': checklistItemId,
            'project_id': projectId,
            'account_id': accountId,
            'is_completed': isCompleted,
            'completed_by': isCompleted ? userId : null,
            'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
            'evidence_url': evidenceUrl,
            'evidence_type': evidenceType?.dbValue,
            'override_reason': overrideReason,
          })
          .select()
          .single();
      return ChecklistCompletion.fromMap(inserted);
    }
  }

  // ---------------------------------------------------------------------------
  // EVIDENCE UPLOAD
  // ---------------------------------------------------------------------------

  /// Upload a photo as evidence for a checklist item
  /// Returns the public URL of the uploaded file
  Future<String> uploadPhotoEvidence({
    required XFile photo,
    required String phaseId,
    required String itemId,
    required String accountId,
  }) async {
    final bytes = await photo.readAsBytes();
    final ext = photo.path.split('.').last.toLowerCase();
    final fileName = 'checklist-evidence/$accountId/$phaseId/$itemId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from('checklist-evidence')
        .uploadBinary(fileName, bytes,
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
              upsert: true,
            ));

    final url = _supabase.storage
        .from('checklist-evidence')
        .getPublicUrl(fileName);

    return url;
  }

  /// Upload a document as evidence
  Future<String> uploadDocumentEvidence({
    required File file,
    required String phaseId,
    required String itemId,
    required String accountId,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final fileName = 'checklist-evidence/$accountId/$phaseId/$itemId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from('checklist-evidence')
        .uploadBinary(fileName, bytes,
            fileOptions: const FileOptions(upsert: true));

    return _supabase.storage
        .from('checklist-evidence')
        .getPublicUrl(fileName);
  }

  // ---------------------------------------------------------------------------
  // GATE SUBMISSION
  // ---------------------------------------------------------------------------

  /// Submit a phase gate for approval.
  /// Returns null on success, or an error message if critical items are incomplete.
  Future<String?> submitGate({
    required String phaseId,
    required String projectId,
    required String accountId,
    required ChecklistGateType gateType,
    required List<ChecklistItemWithCompletion> items,
  }) async {
    final criticalIncomplete = items
        .where((i) => i.item.isCritical && !i.isCompleted && !i.isOverridden)
        .toList();

    // Cannot submit if critical items remain (with no override)
    if (criticalIncomplete.isNotEmpty) {
      return '${criticalIncomplete.length} critical item(s) must be completed before submitting the gate.';
    }

    final incompleteCriticalCount = items
        .where((i) => i.item.isCritical && !i.isCompleted)
        .length;

    await _supabase.from('phase_gate_approvals').insert({
      'phase_id': phaseId,
      'project_id': projectId,
      'account_id': accountId,
      'gate_type': gateType.dbValue,
      'status': 'approved',  // Auto-approve if all critical items done
      'approved_by': _supabase.auth.currentUser?.id,
      'approved_at': DateTime.now().toIso8601String(),
      'incomplete_critical_items': incompleteCriticalCount,
    });

    // Update phase status based on gate type
    if (gateType == ChecklistGateType.preStart) {
      await _supabase
          .from('milestone_phases')
          .update({'status': 'active'})
          .eq('id', phaseId);
    } else {
      await _supabase
          .from('milestone_phases')
          .update({
            'status': 'completed',
            'actual_end': DateTime.now().toIso8601String(),
          })
          .eq('id', phaseId);
    }

    return null; // success
  }

  /// Get the latest gate approval for a phase
  Future<PhaseGateApproval?> getLatestGateApproval(
    String phaseId,
    ChecklistGateType gateType,
  ) async {
    try {
      final data = await _supabase
          .from('phase_gate_approvals')
          .select()
          .eq('phase_id', phaseId)
          .eq('gate_type', gateType.dbValue)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return PhaseGateApproval.fromMap(data);
    } catch (e) {
      debugPrint('[ChecklistService] getLatestGateApproval error: $e');
      return null;
    }
  }
}
