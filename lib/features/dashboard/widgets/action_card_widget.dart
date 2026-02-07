import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';
import 'package:image_picker/image_picker.dart';
import 'package:houzzdat_app/features/dashboard/widgets/instruct_voice_dialog.dart';

/// Enhanced Action Card implementing full SiteVoice Manager Action Lifecycle
/// - Contextual surface actions based on category
/// - Proof-of-Work verification flow
/// - Complete interaction history tracking
/// - State machine enforcement
class ActionCardWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;

  const ActionCardWidget({
    super.key,
    required this.item,
    required this.onRefresh,
  });

  @override
  State<ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends State<ActionCardWidget> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  bool _isExpanded = false;
  Map<String, dynamic>? _voiceNote;
  List<Map<String, dynamic>> _interactionHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.item['interaction_history'] != null) {
      _interactionHistory = List<Map<String, dynamic>>.from(
        widget.item['interaction_history'] as List
      );
    }
  }

  Color _getCategoryColor() {
    switch (widget.item['category']) {
      case 'action_required': return AppTheme.errorRed;
      case 'approval': return AppTheme.warningOrange;
      case 'update': return AppTheme.successGreen;
      default: return AppTheme.textSecondary;
    }
  }

  String _getCategoryLabel() {
    switch (widget.item['category']) {
      case 'action_required': return 'ACTION REQUIRED';
      case 'approval': return 'APPROVAL';
      case 'update': return 'UPDATE';
      default: return 'OTHER';
    }
  }

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

  /// Add interaction to history and update database
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

  /// Enforce state machine transitions
  /// Set [bypassProofGate] to true for actions that don't require proof (deny, acknowledge)
  Future<bool> _updateStatus(String newStatus, {bool bypassProofGate = false}) async {
    final currentStatus = widget.item['status'] ?? 'pending';

    // Define valid transitions
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
            content: Text('Invalid transition: $currentStatus → $newStatus'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return false;
    }

    // Proof gate: block completion if proof is required but not uploaded
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

  /// APPROVE action
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

  /// DENY action — bypasses proof gate (denial doesn't need evidence)
  Future<void> _handleDeny() async {
    await _recordInteraction('denied', 'Manager denied this request');
    await _updateStatus('completed', bypassProofGate: true);
    widget.onRefresh();
  }

  /// INSTRUCT action - record voice note back to original sender
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

  /// FORWARD action - delegate to another user with optional note
  Future<void> _handleForward() async {
    final selectedUser = await _showForwardSheet();
    if (selectedUser == null) return;

    // Show optional note dialog
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

    // User cancelled the note dialog entirely
    if (forwardNote == null) return;

    // Update action item
    await _supabase
        .from('action_items')
        .update({
          'assigned_to': selectedUser,
          'status': 'in_progress',
        })
        .eq('id', widget.item['id']);

    // Record in voice_note_forwards for forwarding chain
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

    // Create notification for the forwarded user
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

  /// RESOLVE action - for Action Required items
  Future<void> _handleResolve() async {
    await _recordInteraction('resolved', 'Manager marked as resolved');
    await _updateStatus('completed');
    widget.onRefresh();
  }

  /// ACKNOWLEDGE action - for Updates (bypasses proof gate — updates never need proof)
  Future<void> _handleAcknowledge() async {
    await _recordInteraction('acknowledged', 'Manager acknowledged this update');
    await _updateStatus('completed', bypassProofGate: true);
    widget.onRefresh();
  }

  /// INQUIRE action - request more information via voice recording
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

  /// ADD NOTE action - for Update category items (no status change)
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

  /// Proof-of-Work upload
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

  /// Complete & Log - final archival
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

  /// Update priority
  Future<void> _handlePriorityChange(String priority) async {
    await _supabase
        .from('action_items')
        .update({'priority': priority})
        .eq('id', widget.item['id']);

    await _recordInteraction('priority_changed', 'Priority set to $priority');
    widget.onRefresh();
  }

  /// Edit summary text
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

        await _recordInteraction('summary_edited', 'Summary updated');
        widget.onRefresh();
      } catch (e) {
        debugPrint('Error updating summary: $e');
      }
    }
  }

  /// Escalate to Owner - creates an owner_approvals entry
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
      // 1. Look up owner for this project
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

      // 2. Show category selection dialog
      final category = await _showEscalationCategoryDialog();
      if (category == null) return;

      // 3. Create owner_approvals entry
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

      // 4. Record interaction
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
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  /// Show dialog to pick escalation category
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

  /// Show secondary actions menu (Double Burger)
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

  /// Show stakeholder trail (interaction history)
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

  /// Get contextual surface actions based on category
  List<Widget> _getSurfaceActions() {
    final status = widget.item['status'] ?? 'pending';
    final category = widget.item['category'];

    // If in verification phase, show verify/reject actions
    if (status == 'verifying') {
      return [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('VERIFY & COMPLETE', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: _handleCompleteAndLog,
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('REJECT', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _recordInteraction('proof_rejected', 'Proof rejected, sent back to in_progress');
              await _updateStatus('in_progress');
              widget.onRefresh();
            },
          ),
        ),
      ];
    }

    // If in progress and assigned, show proof upload option
    if (status == 'in_progress' && widget.item['assigned_to'] != null) {
      return [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('UPLOAD PROOF', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: _handleProofUpload,
          ),
        ),
      ];
    }

    // Show contextual actions for pending items based on category
    if (status == 'pending') {
      switch (category) {
        case 'approval':
          return [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('APPROVE', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleApprove,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text('INQUIRE', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.infoBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleInquire,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('DENY', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleDeny,
              ),
            ),
          ];

        case 'action_required':
          return [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.mic, size: 16),
                label: const Text('INSTRUCT', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.infoBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleInstruct,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.forward, size: 16),
                label: const Text('FORWARD', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleForward,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('RESOLVE', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleResolve,
              ),
            ),
          ];

        case 'update':
          return [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('ACK', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleAcknowledge,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.note_add, size: 16),
                label: const Text('ADD NOTE', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.infoBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleAddNote,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.forward, size: 16),
                label: const Text('FORWARD', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleForward,
              ),
            ),
          ];

        default:
          return [];
      }
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item['status'] ?? 'pending';
    final priority = widget.item['priority']?.toString() ?? 'Med';
    final aiSummary = widget.item['summary'] ?? 'Action Item';
    final aiAnalysis = widget.item['ai_analysis'];
    final proofPhotoUrl = widget.item['proof_photo_url'];
    final isDependencyLocked = widget.item['is_dependency_locked'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          if (_isExpanded && _voiceNote == null) _loadVoiceNote();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PriorityIndicator(priority: priority),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aiSummary,
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            Wrap(
                              spacing: AppTheme.spacingS,
                              runSpacing: AppTheme.spacingS,
                              children: [
                                CategoryBadge(
                                  text: _getCategoryLabel(),
                                  color: _getCategoryColor(),
                                ),
                                CategoryBadge(
                                  text: status.toUpperCase(),
                                  color: status == 'completed'
                                      ? AppTheme.successGreen
                                      : status == 'verifying'
                                          ? AppTheme.warningOrange
                                          : AppTheme.textSecondary,
                                  icon: status == 'completed'
                                      ? Icons.check_circle
                                      : status == 'verifying'
                                          ? Icons.verified
                                          : Icons.pending,
                                ),
                                if (isDependencyLocked)
                                  const CategoryBadge(
                                    text: 'BLOCKED',
                                    color: AppTheme.errorRed,
                                    icon: Icons.lock,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.menu_open_rounded,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: _showSecondaryActions,
                        tooltip: 'Secondary Actions',
                      ),
                    ],
                  ),
                  if (aiAnalysis != null && aiAnalysis.toString().isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: AppTheme.infoBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: AppTheme.infoBlue.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: AppTheme.infoBlue,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: Text(
                              aiAnalysis.toString(),
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.infoBlue,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isExpanded) ...[
              const Divider(height: 1),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: CircularProgressIndicator(),
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
              if (proofPhotoUrl != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROOF OF WORK',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
            ],
            if (isDependencyLocked) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                color: AppTheme.errorRed.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 16, color: AppTheme.errorRed),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Blocked by dependency — a parent task must be completed first',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.errorRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_getSurfaceActions().isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Row(
                  children: _getSurfaceActions(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
