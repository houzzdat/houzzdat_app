import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';
import 'package:image_picker/image_picker.dart';
import 'package:houzzdat_app/features/dashboard/widgets/instruct_voice_dialog.dart';

/// Two-Tier Action Card implementing full SiteVoice Manager Action Lifecycle
/// - Collapsed 4-line card with priority border, pills, summary, sender, actions
/// - Expanded detail view with audio, transcript, AI analysis, confidence, proof
/// - Accordion support (max 1 expanded) via expandedCardId/onExpandChanged
/// - Needs-review variant for AI-suggested items (CONFIRM/EDIT/DISMISS)
/// - Structured approval card with extracted data + APPROVE WITH NOTE
class ActionCardWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;
  final Color? stageColor;
  final String? expandedCardId;
  final ValueChanged<String?>? onExpandChanged;

  const ActionCardWidget({
    super.key,
    required this.item,
    required this.onRefresh,
    this.stageColor,
    this.expandedCardId,
    this.onExpandChanged,
  });

  @override
  State<ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends State<ActionCardWidget> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  // Voice note + interaction state (preserved)
  Map<String, dynamic>? _voiceNote;
  List<Map<String, dynamic>> _interactionHistory = [];
  bool _isLoading = false;

  // Two-tier state
  bool _localExpanded = false;
  String? _senderName;
  String? _projectName;

  // Approval details (Step 4)
  Map<String, dynamic>? _approvalDetails;
  List<Map<String, dynamic>> _materialRequests = [];

  bool get _isExpanded => widget.onExpandChanged != null
      ? widget.expandedCardId == widget.item['id']
      : _localExpanded;

  @override
  void initState() {
    super.initState();
    if (widget.item['interaction_history'] != null) {
      _interactionHistory = List<Map<String, dynamic>>.from(
        widget.item['interaction_history'] as List,
      );
    }
    _loadSenderInfo();
    _loadProjectName();
    if (widget.item['category'] == 'approval') _loadApprovalDetails();
  }

  @override
  void didUpdateWidget(covariant ActionCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Load voice note when accordion-expanding via external control
    if (widget.expandedCardId == widget.item['id'] &&
        oldWidget.expandedCardId != widget.item['id'] &&
        _voiceNote == null) {
      _loadVoiceNote();
    }
  }

  // ─── Helper Methods ───────────────────────────────────────────

  String _getRelativeTime() {
    final createdAt = widget.item['created_at'];
    if (createdAt == null) return '';
    try {
      final created = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(created);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${created.day}/${created.month}';
    } catch (_) {
      return '';
    }
  }

  Color _getPriorityColor() {
    switch ((widget.item['priority'] ?? 'Med').toString().toLowerCase()) {
      case 'high':
        return AppTheme.errorRed;
      case 'med':
      case 'medium':
        return AppTheme.warningOrange;
      case 'low':
        return AppTheme.successGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  double? _getConfidenceScore() {
    final score = widget.item['confidence_score'];
    if (score != null) return double.tryParse(score.toString());
    final analysis = widget.item['ai_analysis'];
    if (analysis is Map && analysis['confidence_score'] != null) {
      return double.tryParse(analysis['confidence_score'].toString());
    }
    return null;
  }

  Color _getCategoryColor() {
    switch (widget.item['category']) {
      case 'action_required':
        return AppTheme.errorRed;
      case 'approval':
        return AppTheme.warningOrange;
      case 'update':
        return AppTheme.successGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getCategoryLabel() {
    switch (widget.item['category']) {
      case 'action_required':
        return 'ACTION REQUIRED';
      case 'approval':
        return 'APPROVAL';
      case 'update':
        return 'UPDATE';
      default:
        return 'OTHER';
    }
  }

  IconData _getInteractionIcon(String? action) {
    switch (action) {
      case 'approved':
      case 'approved_with_note':
        return Icons.check_circle;
      case 'denied':
        return Icons.cancel;
      case 'instructed':
        return Icons.mic;
      case 'forwarded':
        return Icons.forward;
      case 'resolved':
        return Icons.done_all;
      case 'acknowledged':
        return Icons.check;
      case 'proof_uploaded':
        return Icons.camera_alt;
      case 'note_added':
        return Icons.note_add;
      case 'review_confirmed':
        return Icons.verified;
      case 'review_dismissed':
        return Icons.remove_circle;
      default:
        return Icons.history;
    }
  }

  // ─── Data Loading ─────────────────────────────────────────────

  Future<void> _loadVoiceNote() async {
    if (_voiceNote != null || widget.item['voice_note_id'] == null) return;
    setState(() => _isLoading = true);
    try {
      final note = await _supabase
          .from('voice_notes')
          .select('audio_url, transcription, transcript_final, transcript_en_current, is_edited, status')
          .eq('id', widget.item['voice_note_id'])
          .single();
      if (mounted) setState(() { _voiceNote = note; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading voice note: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSenderInfo() async {
    final userId = widget.item['user_id'];
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .single();
      if (mounted) setState(() => _senderName = data['full_name']?.toString() ?? 'Unknown');
    } catch (_) {}
  }

  Future<void> _loadProjectName() async {
    final projectId = widget.item['project_id'];
    if (projectId == null) return;
    try {
      final data = await _supabase
          .from('projects')
          .select('name')
          .eq('id', projectId)
          .single();
      if (mounted) setState(() => _projectName = data['name']?.toString() ?? 'Unknown');
    } catch (_) {}
  }

  Future<void> _loadApprovalDetails() async {
    final voiceNoteId = widget.item['voice_note_id'];
    if (voiceNoteId == null) return;
    try {
      final approval = await _supabase
          .from('voice_note_approvals')
          .select()
          .eq('voice_note_id', voiceNoteId)
          .maybeSingle();
      final materials = await _supabase
          .from('voice_note_material_requests')
          .select()
          .eq('voice_note_id', voiceNoteId);
      if (mounted) {
        setState(() {
          _approvalDetails = approval;
          _materialRequests = List<Map<String, dynamic>>.from(materials);
        });
      }
    } catch (_) {}
  }

  // ─── AI Correction Recording ─────────────────────────────────

  /// Records a correction signal to the ai_corrections table.
  /// This data feeds the self-improving AI feedback loop (Phase A).
  Future<void> _recordCorrection({
    required String correctionType,
    String? originalValue,
    String? correctedValue,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('ai_corrections').insert({
        'voice_note_id': widget.item['voice_note_id'],
        'action_item_id': widget.item['id'],
        'project_id': widget.item['project_id'],
        'account_id': widget.item['account_id'],
        'correction_type': correctionType,
        'original_value': originalValue,
        'corrected_value': correctedValue,
        'corrected_by': userId,
        'confidence_at_time': _getConfidenceScore(),
      });
    } catch (e) {
      debugPrint('Error recording correction: $e');
    }
  }

  // ─── Interaction Recording (preserved) ────────────────────────

  Future<void> _recordInteraction(String action, String details) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final interaction = {
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId,
      'action': action,
      'details': details,
    };

    final updatedHistory = [..._interactionHistory, interaction];

    try {
      await _supabase
          .from('action_items')
          .update({
            'interaction_history': updatedHistory,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.item['id']);

      setState(() => _interactionHistory = updatedHistory);
    } catch (e) {
      debugPrint('Error recording interaction: $e');
    }
  }

  // ─── Status Transitions (preserved) ───────────────────────────

  Future<bool> _updateStatus(String newStatus, {bool bypassProofGate = false}) async {
    final currentStatus = widget.item['status'] ?? 'pending';

    final validTransitions = {
      'pending': ['in_progress', 'completed'],
      'in_progress': ['verifying', 'completed'],
      'verifying': ['completed', 'in_progress'],
      'completed': <String>[],
    };

    if (!(validTransitions[currentStatus]?.contains(newStatus) ?? false)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid transition: $currentStatus \u2192 $newStatus'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return false;
    }

    if (newStatus == 'completed' &&
        !bypassProofGate &&
        widget.item['requires_proof'] == true &&
        (widget.item['proof_photo_url'] == null ||
            widget.item['proof_photo_url'].toString().isEmpty)) {
      if (mounted) {
        final uploadNow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Proof Required'),
            content: const Text(
              'This action requires proof of work before it can be completed. Would you like to upload proof now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Upload Proof'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.infoBlue,
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );

        if (uploadNow == true) {
          await _handleProofUpload();
        }
      }
      return false;
    }

    try {
      await _supabase
          .from('action_items')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.item['id']);
      return true;
    } catch (e) {
      debugPrint('Error updating status: $e');
      return false;
    }
  }

  // ─── Action Handlers ──────────────────────────────────────────

  Future<void> _handleApprove() async {
    await _recordInteraction('approved', 'Manager approved this action');
    final success = await _updateStatus('in_progress');
    if (success) {
      await _supabase
          .from('action_items')
          .update({
            'manager_approval': true,
            'approved_by': _supabase.auth.currentUser?.id,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.item['id']);
      widget.onRefresh();
    }
  }

  /// APPROVE WITH NOTE — approval with conditions (Step 4D)
  Future<void> _handleApproveWithNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve with Conditions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add conditions or notes for this approval:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. Approved for max Rs 40,000 only...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (note != null && note.isNotEmpty) {
      await _recordInteraction('approved_with_note', 'Approved with note: $note');
      final success = await _updateStatus('in_progress');
      if (success) {
        await _supabase
            .from('action_items')
            .update({
              'manager_approval': true,
              'approved_by': _supabase.auth.currentUser?.id,
              'approved_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.item['id']);
        widget.onRefresh();
      }
    }
  }

  /// DENY action — mandatory reason (Step 4E)
  Future<void> _handleDeny() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deny Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for denial:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Reason for denial (required)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('A reason is required to deny')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Deny', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      await _recordCorrection(
        correctionType: 'denied_with_reason',
        originalValue: widget.item['summary']?.toString(),
        correctedValue: reason,
      );
      await _recordInteraction('denied', 'Denied with reason: $reason');
      await _updateStatus('completed', bypassProofGate: true);
      widget.onRefresh();
    }
  }

  Future<void> _handleInstruct() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => InstructVoiceDialog(actionItem: widget.item),
      ),
    );

    if (result == true) {
      await _recordInteraction('instructed', 'Manager sent voice instruction to original sender');
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instruction sent successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _handleForward() async {
    final selectedUser = await _showForwardSheet();
    if (selectedUser == null) return;

    final noteController = TextEditingController();
    final forwardNote = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Forward Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optionally add a note for the person you\'re forwarding to:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Add context or instructions...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noteController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Forward', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (forwardNote == null) return;

    await _supabase
        .from('action_items')
        .update({
          'assigned_to': selectedUser,
          'status': 'in_progress',
        })
        .eq('id', widget.item['id']);

    if (widget.item['voice_note_id'] != null) {
      try {
        await _supabase.from('voice_note_forwards').insert({
          'voice_note_id': widget.item['voice_note_id'],
          'forwarded_by': _supabase.auth.currentUser?.id,
          'forwarded_to': selectedUser,
          'forward_note': forwardNote.isNotEmpty ? forwardNote : null,
        });
      } catch (e) {
        debugPrint('Warning: Could not record forward chain: $e');
      }
    }

    try {
      await _supabase.from('notifications').insert({
        'user_id': selectedUser,
        'account_id': widget.item['account_id'],
        'project_id': widget.item['project_id'],
        'type': 'action_forwarded',
        'title': 'Action item forwarded to you',
        'body': forwardNote.isNotEmpty
            ? forwardNote
            : (widget.item['summary'] ?? 'An action has been forwarded to you'),
        'reference_id': widget.item['id'],
        'reference_type': 'action_item',
      });
    } catch (e) {
      debugPrint('Warning: Could not create notification: $e');
    }

    final noteDetail = forwardNote.isNotEmpty
        ? 'Forwarded to user: $selectedUser with note: $forwardNote'
        : 'Forwarded to user: $selectedUser';
    await _recordInteraction('forwarded', noteDetail);
    widget.onRefresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action forwarded successfully'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _handleResolve() async {
    await _recordInteraction('resolved', 'Manager marked as resolved');
    await _updateStatus('completed');
    widget.onRefresh();
  }

  Future<void> _handleAcknowledge() async {
    await _recordInteraction('acknowledged', 'Manager acknowledged this update');
    await _updateStatus('completed', bypassProofGate: true);
    widget.onRefresh();
  }

  Future<void> _handleInquire() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => InstructVoiceDialog(actionItem: widget.item),
      ),
    );

    if (result == true) {
      await _recordInteraction('inquired', 'Manager requested more information via voice note');
      widget.onRefresh();
    }
  }

  Future<void> _handleAddNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter your note...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Save Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (note != null && note.isNotEmpty) {
      await _recordInteraction('note_added', note);
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note added to interaction history'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _handleProofUpload() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final fileName = 'proof_${widget.item['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('proof-photos')
          .uploadBinary(fileName, bytes);

      final proofUrl = _supabase.storage
          .from('proof-photos')
          .getPublicUrl(fileName);

      await _supabase
          .from('action_items')
          .update({
            'proof_photo_url': proofUrl,
            'status': 'verifying',
          })
          .eq('id', widget.item['id']);

      await _recordInteraction('proof_uploaded', 'Uploaded proof of work');
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof uploaded! Moved to verification.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading proof: $e');
    }
  }

  Future<void> _handleCompleteAndLog() async {
    await _recordInteraction('completed_and_logged', 'Manager archived this action');
    await _updateStatus('completed');
    widget.onRefresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action completed and logged to archive'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _handlePriorityChange(String priority) async {
    final oldPriority = widget.item['priority']?.toString() ?? 'Med';
    await _supabase
        .from('action_items')
        .update({'priority': priority})
        .eq('id', widget.item['id']);

    if (oldPriority != priority) {
      await _recordCorrection(
        correctionType: 'priority',
        originalValue: oldPriority,
        correctedValue: priority,
      );
    }
    await _recordInteraction('priority_changed', 'Priority set to $priority');
    widget.onRefresh();
  }

  Future<void> _handleEditSummary() async {
    final controller = TextEditingController(text: widget.item['summary'] ?? '');
    final newSummary = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Summary'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter action item summary...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newSummary != null && newSummary.isNotEmpty && newSummary != widget.item['summary']) {
      try {
        await _supabase
            .from('action_items')
            .update({'summary': newSummary})
            .eq('id', widget.item['id']);

        await _recordCorrection(
          correctionType: 'summary',
          originalValue: widget.item['summary']?.toString(),
          correctedValue: newSummary,
        );
        await _recordInteraction('summary_edited', 'Summary updated');
        widget.onRefresh();
      } catch (e) {
        debugPrint('Error updating summary: $e');
      }
    }
  }

  Future<void> _handleEscalateToOwner() async {
    final projectId = widget.item['project_id'];
    final accountId = widget.item['account_id'];
    final userId = _supabase.auth.currentUser?.id;

    if (projectId == null || accountId == null || userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing project or account information'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    try {
      final ownerResult = await _supabase
          .from('project_owners')
          .select('owner_id')
          .eq('project_id', projectId)
          .limit(1)
          .maybeSingle();

      if (ownerResult == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No owner assigned to this project'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }

      final ownerId = ownerResult['owner_id'] as String;
      final category = await _showEscalationCategoryDialog();
      if (category == null) return;

      await _supabase.from('owner_approvals').insert({
        'project_id': projectId,
        'account_id': accountId,
        'requested_by': userId,
        'owner_id': ownerId,
        'title': widget.item['summary'] ?? 'Escalated Action Item',
        'description': widget.item['details'] ?? '',
        'category': category,
        'status': 'pending',
        'action_item_id': widget.item['id'],
      });

      await _recordInteraction(
        'escalated_to_owner',
        'Escalated to owner for $category review',
      );

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escalated to owner for approval'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error escalating to owner: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ─── Review Handlers (Step 3E) ────────────────────────────────

  Future<void> _handleConfirmReview() async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase.from('action_items').update({
      'needs_review': false,
      'review_status': 'confirmed',
      'reviewed_by': userId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.item['id']);
    await _recordCorrection(
      correctionType: 'review_confirmed',
      originalValue: '${widget.item['category']}/${widget.item['priority']}',
      correctedValue: 'confirmed_as_correct',
    );
    await _recordInteraction('review_confirmed', 'Manager confirmed AI-suggested action');
    widget.onRefresh();
  }

  Future<void> _handleDismissReview() async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase.from('action_items').update({
      'needs_review': false,
      'review_status': 'dismissed',
      'reviewed_by': userId,
      'reviewed_at': DateTime.now().toIso8601String(),
      'status': 'completed',
    }).eq('id', widget.item['id']);
    await _recordCorrection(
      correctionType: 'review_dismissed',
      originalValue: '${widget.item['category']}/${widget.item['priority']}',
      correctedValue: 'dismissed_as_incorrect',
    );
    await _recordInteraction('review_dismissed', 'Manager dismissed AI-suggested action');
    widget.onRefresh();
  }

  // ─── UI Dialogs (preserved) ───────────────────────────────────

  Future<String?> _showEscalationCategoryDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escalation Category'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'spending'),
            child: const ListTile(
              leading: Icon(Icons.attach_money, color: AppTheme.warningOrange),
              title: Text('Spending Approval'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'design_change'),
            child: const ListTile(
              leading: Icon(Icons.design_services, color: AppTheme.infoBlue),
              title: Text('Design Change'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'material_change'),
            child: const ListTile(
              leading: Icon(Icons.inventory, color: AppTheme.primaryIndigo),
              title: Text('Material Change'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'schedule_change'),
            child: const ListTile(
              leading: Icon(Icons.schedule, color: AppTheme.errorRed),
              title: Text('Schedule Change'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'other'),
            child: const ListTile(
              leading: Icon(Icons.more_horiz, color: AppTheme.textSecondary),
              title: Text('Other'),
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  void _showSecondaryActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacingM),
              child: Text(
                'SECONDARY ACTIONS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.priority_high, color: AppTheme.errorRed),
              title: const Text('Set Priority: HIGH'),
              onTap: () {
                Navigator.pop(context);
                _handlePriorityChange('High');
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove, color: AppTheme.warningOrange),
              title: const Text('Set Priority: MEDIUM'),
              onTap: () {
                Navigator.pop(context);
                _handlePriorityChange('Med');
              },
            ),
            ListTile(
              leading: const Icon(Icons.low_priority, color: AppTheme.successGreen),
              title: const Text('Set Priority: LOW'),
              onTap: () {
                Navigator.pop(context);
                _handlePriorityChange('Low');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_note, color: AppTheme.primaryIndigo),
              title: const Text('Edit Summary'),
              onTap: () {
                Navigator.pop(context);
                _handleEditSummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppTheme.infoBlue),
              title: const Text('View Stakeholder Trail'),
              onTap: () {
                Navigator.pop(context);
                _showStakeholderTrail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.escalator_warning, color: AppTheme.warningOrange),
              title: const Text('Escalate to Owner'),
              subtitle: const Text('Send for owner approval', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _handleEscalateToOwner();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: AppTheme.primaryIndigo),
              title: const Text('Mark Completed & Logged', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _handleCompleteAndLog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStakeholderTrail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STAKEHOLDER TRAIL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacingM),
            const Divider(),
            Expanded(
              child: _interactionHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No interactions yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _interactionHistory.length,
                      itemBuilder: (context, index) {
                        final interaction = _interactionHistory[index];
                        final timestamp = DateTime.parse(interaction['timestamp']);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.infoBlue,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            interaction['action'].toString().toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${interaction['details']}\n${_formatTimestamp(timestamp)}',
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _showForwardSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (context) => ForwardSelectionSheet(
        accountId: widget.item['account_id'],
        onUserSelected: (userId) => Navigator.pop(context, userId),
      ),
    );
  }

  // ─── Surface Actions ──────────────────────────────────────────

  // Compact outlined button matching the design mockup (text-only, no icon)
  Widget _actionBtn(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  List<Widget> _getSurfaceActions() {
    final status = widget.item['status'] ?? 'pending';
    final category = widget.item['category'];

    // Verification phase
    if (status == 'verifying') {
      return [
        _actionBtn('VERIFY', AppTheme.successGreen, _handleCompleteAndLog),
        const SizedBox(width: 6),
        _actionBtn('REJECT', AppTheme.errorRed, () async {
          await _recordInteraction('proof_rejected', 'Proof rejected, sent back to in_progress');
          await _updateStatus('in_progress');
          widget.onRefresh();
        }),
      ];
    }

    // In progress with assignment — proof upload
    if (status == 'in_progress' && widget.item['assigned_to'] != null) {
      return [
        _actionBtn('UPLOAD PROOF', AppTheme.infoBlue, _handleProofUpload),
      ];
    }

    // Pending items — category-specific actions
    if (status == 'pending') {
      switch (category) {
        case 'approval':
          return [
            _actionBtn('APPROVE', AppTheme.successGreen, _handleApprove),
            const SizedBox(width: 6),
            _actionBtn('WITH NOTE', AppTheme.infoBlue, _handleApproveWithNote),
            const SizedBox(width: 6),
            _actionBtn('DENY', AppTheme.errorRed, _handleDeny),
          ];

        case 'action_required':
          return [
            _actionBtn('INSTRUCT', AppTheme.infoBlue, _handleInstruct),
            const SizedBox(width: 6),
            _actionBtn('FORWARD', AppTheme.warningOrange, _handleForward),
            const SizedBox(width: 6),
            _actionBtn('RESOLVE', AppTheme.successGreen, _handleResolve),
          ];

        case 'update':
          return [
            _actionBtn('ACK', AppTheme.successGreen, _handleAcknowledge),
            const SizedBox(width: 6),
            _actionBtn('ADD NOTE', AppTheme.infoBlue, _handleAddNote),
            const SizedBox(width: 6),
            _actionBtn('FORWARD', AppTheme.warningOrange, _handleForward),
          ];

        default:
          return [];
      }
    }

    return [];
  }

  /// Review actions for AI-suggested items (Step 3E)
  List<Widget> _getReviewActions() {
    return [
      _actionBtn('CONFIRM', AppTheme.successGreen, _handleConfirmReview),
      const SizedBox(width: 6),
      _actionBtn('EDIT', AppTheme.infoBlue, _handleEditSummary),
      const SizedBox(width: 6),
      _actionBtn('DISMISS', AppTheme.textSecondary, _handleDismissReview),
    ];
  }

  // ─── Build Helpers ────────────────────────────────────────────

  /// Collapsed card content — 4-line layout
  Widget _buildCollapsedContent() {
    final status = widget.item['status'] ?? 'pending';
    final aiSummary = widget.item['summary'] ?? 'Action Item';
    final isCritical = widget.item['is_critical_flag'] == true;
    final needsReview = widget.item['needs_review'] == true &&
        widget.item['review_status'] != 'confirmed';

    // For approval cards, append extracted amount to summary
    String summaryText = aiSummary;
    if (widget.item['category'] == 'approval' && _approvalDetails != null) {
      final amount = _approvalDetails!['estimated_amount'];
      if (amount != null) {
        summaryText = '$aiSummary \u2014 Rs $amount';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: Priority dot + label, Category pill, badges, time
          Row(
            children: [
              // Priority: colored dot + text
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _getPriorityColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                (widget.item['priority'] ?? 'MED').toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getPriorityColor(),
                ),
              ),
              const SizedBox(width: 12),
              // Category: colored text
              Text(
                _getCategoryLabel(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(),
                ),
              ),
              if (isCritical) ...[
                const SizedBox(width: 8),
                const CategoryBadge(
                  text: 'CRITICAL',
                  color: AppTheme.errorRed,
                  icon: Icons.warning,
                ),
              ],
              if (needsReview) ...[
                const SizedBox(width: 8),
                const CategoryBadge(
                  text: 'AI-SUGGESTED',
                  color: Color(0xFF9E9E9E),
                  icon: Icons.auto_awesome,
                ),
              ],
              const Spacer(),
              Text(_getRelativeTime(), style: AppTheme.caption),
            ],
          ),
          const SizedBox(height: 6),
          // Line 2: AI summary (2 lines max)
          Text(
            summaryText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          // Line 3: Avatar + Sender + Project + Status
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryIndigo,
                child: Text(
                  (_senderName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  [
                    _senderName ?? 'Loading...',
                    if (_projectName != null) _projectName!,
                  ].join(' \u00b7 '),
                  style: AppTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status != 'pending')
                CategoryBadge(
                  text: status.toUpperCase(),
                  color: status == 'completed'
                      ? AppTheme.successGreen
                      : status == 'verifying'
                          ? AppTheme.warningOrange
                          : AppTheme.infoBlue,
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// Action button row — Line 4 of collapsed card
  Widget _buildActionRow() {
    final isDependencyLocked = widget.item['is_dependency_locked'] == true;
    final needsReview = widget.item['needs_review'] == true &&
        widget.item['review_status'] != 'confirmed';

    if (isDependencyLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppTheme.errorRed.withValues(alpha: 0.05),
        child: Row(
          children: [
            const Icon(Icons.lock, size: 14, color: AppTheme.errorRed),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Blocked by dependency',
                style: AppTheme.caption.copyWith(color: AppTheme.errorRed),
              ),
            ),
          ],
        ),
      );
    }

    final actions = needsReview ? _getReviewActions() : _getSurfaceActions();
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
      child: Row(
        children: [
          ...actions,
          const SizedBox(width: 4),
          InkWell(
            onTap: _showSecondaryActions,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.more_horiz, size: 20, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Expanded detail content — shown below collapsed card
  Widget _buildExpandedContent() {
    final aiAnalysis = widget.item['ai_analysis'];
    final proofPhotoUrl = widget.item['proof_photo_url'];
    final confidenceScore = _getConfidenceScore();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        // Audio player + transcript
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(AppTheme.spacingL),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_voiceNote != null)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                if (_voiceNote!['audio_url'] != null)
                  VoiceNoteAudioPlayer(audioUrl: _voiceNote!['audio_url']),
                TranscriptionDisplay(
                  noteId: widget.item['voice_note_id'],
                  transcription: _voiceNote!['transcript_final'] ??
                      _voiceNote!['transcription'] ??
                      _voiceNote!['transcript_en_current'],
                  status: _voiceNote!['status'] ?? '',
                  isEdited: _voiceNote!['is_edited'],
                ),
              ],
            ),
          ),
        // AI Analysis + Confidence bar
        if (aiAnalysis != null && aiAnalysis.toString().isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: AppTheme.infoBlue),
                      const SizedBox(width: AppTheme.spacingS),
                      const Text(
                        'AI Analysis',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.infoBlue,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (confidenceScore != null)
                        _buildConfidenceBar(confidenceScore),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    aiAnalysis.toString(),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.infoBlue,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Structured approval details (Step 4C)
        if (widget.item['category'] == 'approval')
          _buildApprovalDetailsSection(),
        // Proof photo
        if (proofPhotoUrl != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROOF OF WORK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: AppTheme.spacingS),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Image.network(
                    proofPhotoUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Mini stakeholder trail (last 3)
        if (_interactionHistory.isNotEmpty) _buildMiniStakeholderTrail(),
      ],
    );
  }

  /// Confidence bar — 60px wide, 4px tall, colored by score (Step 3F)
  Widget _buildConfidenceBar(double score) {
    Color barColor;
    if (score >= 0.85) {
      barColor = AppTheme.successGreen;
    } else if (score >= 0.70) {
      barColor = AppTheme.warningOrange;
    } else {
      barColor = AppTheme.textSecondary;
    }

    return Tooltip(
      message: 'AI confidence: ${(score * 100).toStringAsFixed(0)}%',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(score * 100).toStringAsFixed(0)}%',
            style: AppTheme.caption.copyWith(
              color: barColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 60,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Structured approval details section (Step 4C)
  Widget _buildApprovalDetailsSection() {
    if (_approvalDetails == null && _materialRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: AppTheme.warningOrange.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'APPROVAL DETAILS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.warningOrange,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                if (_approvalDetails != null) ...[
                  _buildDetailRow(
                    'Category',
                    _approvalDetails!['category']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    'Estimated Amount',
                    _approvalDetails!['estimated_amount'] != null
                        ? 'Rs ${_approvalDetails!['estimated_amount']}'
                        : '-',
                  ),
                  _buildDetailRow('Requested By', _senderName ?? '-'),
                  _buildDetailRow('Project', _projectName ?? '-'),
                ],
                if (_materialRequests.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  const Text(
                    'Materials:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  ..._materialRequests.map((m) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                          '\u2022 ${m['material_name'] ?? ''} \u2014 ${m['quantity'] ?? ''} ${m['unit'] ?? ''}',
                          style: AppTheme.bodySmall,
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value, style: AppTheme.bodySmall)),
        ],
      ),
    );
  }

  /// Mini stakeholder trail — last 3 interactions
  Widget _buildMiniStakeholderTrail() {
    final lastThree = _interactionHistory.length > 3
        ? _interactionHistory.sublist(_interactionHistory.length - 3)
        : _interactionHistory;

    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'RECENT ACTIVITY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (_interactionHistory.length > 3)
                    GestureDetector(
                      onTap: _showStakeholderTrail,
                      child: Text(
                        'View all (${_interactionHistory.length})',
                        style: AppTheme.caption.copyWith(color: AppTheme.infoBlue),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              ...lastThree.map((interaction) {
                final timestamp = DateTime.parse(interaction['timestamp']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        _getInteractionIcon(interaction['action']),
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${interaction['action'].toString().toUpperCase()} \u2014 ${interaction['details']}',
                          style: AppTheme.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: AppTheme.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Main Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final needsReview = widget.item['needs_review'] == true &&
        widget.item['review_status'] != 'confirmed';
    final isCritical = widget.item['is_critical_flag'] == true;

    // Left border color: critical > needs-review > priority
    Color leftBorderColor;
    if (isCritical) {
      leftBorderColor = AppTheme.errorRed;
    } else if (needsReview) {
      leftBorderColor = const Color(0xFFBDBDBD);
    } else {
      leftBorderColor = widget.stageColor ?? _getPriorityColor();
    }

    // Needs-review cards get amber tint background
    Color? cardBackground;
    if (needsReview) {
      cardBackground = const Color(0xFFFFF8E1);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: _isExpanded ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      clipBehavior: Clip.hardEdge,
      color: cardBackground,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4px left priority/status border bar
            Container(width: 4, color: leftBorderColor),
            // Card content
            Expanded(
              child: InkWell(
                onTap: () {
                  if (widget.onExpandChanged != null) {
                    final willExpand = !_isExpanded;
                    widget.onExpandChanged!(
                      willExpand ? widget.item['id'] : null,
                    );
                    if (willExpand && _voiceNote == null) _loadVoiceNote();
                  } else {
                    setState(() => _localExpanded = !_localExpanded);
                    if (_localExpanded && _voiceNote == null) _loadVoiceNote();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCollapsedContent(),
                    _buildActionRow(),
                    if (_isExpanded) _buildExpandedContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Forward Selection Sheet (preserved) ──────────────────────────

class ForwardSelectionSheet extends StatelessWidget {
  final String accountId;
  final Function(String userId) onUserSelected;

  const ForwardSelectionSheet({
    super.key,
    required this.accountId,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FORWARD TO STAKEHOLDER',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingM),
          const Divider(),
          Expanded(
            child: FutureBuilder(
              future: supabase
                  .from('users')
                  .select('id, email, full_name')
                  .eq('account_id', accountId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data as List;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryIndigo,
                        child: Text(
                          (user['full_name'] ?? user['email'])[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(user['full_name'] ?? user['email']),
                      subtitle: Text(user['email']),
                      onTap: () => onUserSelected(user['id']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
