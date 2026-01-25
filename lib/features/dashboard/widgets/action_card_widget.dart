import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';

/// Enhanced Action Card for Manager Dashboard
/// Implements the SiteVoice Manager Action Lifecycle
class ActionCardWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onInstruct;
  // Adjusted to dynamic to handle both VoidCallback and Function(String) 
  // to fix compilation errors in legacy tabs
  final dynamic onForward; 
  final Function(String priority)? onUpdatePriority;
  final VoidCallback? onCompleteAndLog;

  const ActionCardWidget({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onInstruct,
    required this.onForward,
    this.onUpdatePriority,
    this.onCompleteAndLog,
  });

  @override
  State<ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends State<ActionCardWidget> {
  final _supabase = Supabase.instance.client;
  bool _isExpanded = false;
  Map<String, dynamic>? _voiceNote;
  bool _isLoading = false;

  Color _getCategoryColor() {
    switch (widget.item['category']) {
      case 'action_required': return AppTheme.errorRed;
      case 'approval': return AppTheme.warningOrange;
      case 'update': return AppTheme.successGreen;
      default: return AppTheme.textSecondary;
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

  void _handleForwardPress() {
    if (widget.onForward is Function(String)) {
      _showForwardSheet();
    } else if (widget.onForward is VoidCallback) {
      widget.onForward();
    }
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
              child: Text('SECONDARY ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ),
            const Divider(),
            if (widget.onUpdatePriority != null) ...[
              ListTile(
                leading: const Icon(Icons.priority_high, color: AppTheme.errorRed),
                title: const Text('Set Priority: HIGH'),
                onTap: () { Navigator.pop(context); widget.onUpdatePriority!('High'); },
              ),
              ListTile(
                leading: const Icon(Icons.low_priority, color: AppTheme.successGreen),
                title: const Text('Set Priority: LOW'),
                onTap: () { Navigator.pop(context); widget.onUpdatePriority!('Low'); },
              ),
            ],
            if (widget.onCompleteAndLog != null)
              ListTile(
                leading: const Icon(Icons.archive, color: AppTheme.infoBlue),
                title: const Text('Mark Completed & Logged', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); widget.onCompleteAndLog!(); },
              ),
          ],
        ),
      ),
    );
  }

  void _showForwardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (context) => ForwardSelectionSheet(
        accountId: widget.item['account_id'],
        onUserSelected: (userId) {
          Navigator.pop(context);
          if (widget.onForward is Function(String)) {
            widget.onForward(userId);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item['status'] ?? 'pending';
    final priority = widget.item['priority']?.toString() ?? 'Med';
    final aiSummary = widget.item['summary'] ?? 'Action Item';
    final aiAnalysis = widget.item['ai_analysis'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
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
                            Text(aiSummary, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: AppTheme.spacingS),
                            Row(
                              children: [
                                CategoryBadge(text: 'Priority: $priority', color: _getCategoryColor()),
                                const SizedBox(width: AppTheme.spacingS),
                                CategoryBadge(
                                  text: status.toUpperCase(),
                                  color: status == 'completed' ? AppTheme.successGreen : AppTheme.textSecondary,
                                  icon: status == 'completed' ? Icons.check_circle : Icons.pending,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu_open_rounded, color: AppTheme.textSecondary),
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
                        border: Border.all(color: AppTheme.infoBlue.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: AppTheme.infoBlue),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(child: Text(aiAnalysis, style: AppTheme.bodyMedium.copyWith(color: AppTheme.infoBlue, fontStyle: FontStyle.italic))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isExpanded) ...[
              const Divider(height: 1),
              if (_isLoading) const Padding(padding: EdgeInsets.all(AppTheme.spacingL), child: CircularProgressIndicator())
              else if (_voiceNote != null) Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  children: [
                    if (_voiceNote!['audio_url'] != null) VoiceNoteAudioPlayer(audioUrl: _voiceNote!['audio_url']),
                    TranscriptionDisplay(
                      noteId: widget.item['voice_note_id'],
                      transcription: _voiceNote!['transcription'],
                      status: _voiceNote!['status'] ?? '',
                      isEdited: _voiceNote!['is_edited'],
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending') Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  Expanded(child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('APPROVE', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
                    onPressed: widget.onApprove,
                  )),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(child: ElevatedButton.icon(
                    icon: const Icon(Icons.mic, size: 16),
                    label: const Text('INSTRUCT', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.infoBlue, foregroundColor: Colors.white),
                    onPressed: widget.onInstruct,
                  )),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(child: ElevatedButton.icon(
                    icon: const Icon(Icons.forward, size: 16),
                    label: const Text('FORWARD', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningOrange, foregroundColor: Colors.white),
                    onPressed: _handleForwardPress,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForwardSelectionSheet extends StatelessWidget {
  final String accountId;
  final Function(String userId) onUserSelected;

  const ForwardSelectionSheet({super.key, required this.accountId, required this.onUserSelected});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FORWARD TO STAKEHOLDER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppTheme.spacingM),
          Expanded(
            child: FutureBuilder(
              future: supabase.from('users').select('id, email, full_name').eq('account_id', accountId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final users = snapshot.data as List;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text((user['full_name'] ?? user['email'])[0].toUpperCase())),
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