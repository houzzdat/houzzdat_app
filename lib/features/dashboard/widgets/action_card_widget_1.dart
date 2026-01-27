import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';
import 'package:image_picker/image_picker.dart';

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
          .select('audio_url, transcription, is_edited, status')
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
  Future<bool> _updateStatus(String newStatus) async {
    final currentStatus = widget.item['status'] ?? 'pending';
    
    // Define valid transitions
    final validTransitions = {
      'pending': ['in_progress', 'completed'],
      'in_progress': ['verifying', 'completed'],
      'verifying': ['completed', 'in_progress'],
      'completed': [],
    };

    if (!validTransitions[currentStatus]?.contains(newStatus) ?? true) {
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

  /// DENY action
  Future<void> _handleDeny() async {
    await _recordInteraction('denied', 'Manager denied this request');
    await _updateStatus('completed');
    widget.onRefresh();
  }

  /// INSTRUCT action - record voice note back to original sender
  Future<void> _handleInstruct() async {
    // TODO: Implement voice recording dialog
    await _recordInteraction('instructed', 'Manager sent instruction to original sender');
    await _updateStatus('in_progress');
    widget.onRefresh();
  }

  /// FORWARD action - delegate to another user
  Future<void> _handleForward() async {
    final selectedUser = await _showForwardSheet();
    if (selectedUser != null) {
      await _supabase
          .from('action_items')
          .update({
            'assigned_to': selectedUser,
            'status': 'in_progress',
          })
          .eq('id', widget.item['id']);
      
      await _recordInteraction('forwarded', 'Forwarded to user: $selectedUser');
      widget.onRefresh();
    }
  }

  /// RESOLVE action - for Action Required items
  Future<void> _handleResolve() async {
    await _recordInteraction('resolved', 'Manager marked as resolved');
    await _updateStatus('completed');
    widget.onRefresh();
  }

  /// ACKNOWLEDGE action - for Updates
  Future<void> _handleAcknowledge() async {
    await _recordInteraction('acknowledged', 'Manager acknowledged this update');
    await _updateStatus('completed');
    widget.onRefresh();
  }

  /// INQUIRE action - request more information
  Future<void> _handleInquire() async {
    await _recordInteraction('inquired', 'Manager requested more information');
    // TODO: Implement voice recording for inquiry
    widget.onRefresh();
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
            content: Text('✅ Proof uploaded! Moved to verification.'),
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
          content: Text('✅ Action completed and logged to archive'),
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
                '⚙️ SECONDARY ACTIONS',
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
              leading: const Icon(Icons.history, color: AppTheme.infoBlue),
              title: const Text('View Stakeholder Trail'),
              onTap: () {
                Navigator.pop(context);
                _showStakeholderTrail();
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
              '📋 STAKEHOLDER TRAIL',
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
                label: const Text('ACKNOWLEDGE', style: TextStyle(fontSize: 12)),
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
                icon: const Icon(Icons.forward, size: 16),
                label: const Text('FORWARD', style: TextStyle(fontSize: 12)),
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
                        color: AppTheme.infoBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: AppTheme.infoBlue.withOpacity(0.1),
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
                              aiAnalysis,
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
                        transcription: _voiceNote!['transcription'],
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
                        '📸 PROOF OF WORK',
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
            if (_getSurfaceActions().isNotEmpty) ...[
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
            '🔀 FORWARD TO STAKEHOLDER',
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