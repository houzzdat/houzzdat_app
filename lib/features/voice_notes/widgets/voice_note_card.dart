import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';
import 'package:houzzdat_app/features/worker/models/voice_note_card_view_model.dart';

/// Main voice note card - supports both ViewModel and Map patterns
/// COMPLETE: Works with VoiceNoteCardViewModel and legacy Map<String, dynamic>
class VoiceNoteCard extends StatefulWidget {
  final VoiceNoteCardViewModel? viewModel;
  final Map<String, dynamic>? note;
  final bool isReplying;
  final VoidCallback onReply;

  // Manager ambient update actions (Step 6)
  final VoidCallback? onAcknowledge;
  final VoidCallback? onAddNote;
  final VoidCallback? onCreateAction;
  final bool isAcknowledged;

  const VoiceNoteCard({
    super.key,
    this.viewModel,
    this.note,
    required this.isReplying,
    required this.onReply,
    this.onAcknowledge,
    this.onAddNote,
    this.onCreateAction,
    this.isAcknowledged = false,
  }) : assert(viewModel != null || note != null,
               'Either viewModel or note must be provided');

  @override
  State<VoiceNoteCard> createState() => _VoiceNoteCardState();
}

class _VoiceNoteCardState extends State<VoiceNoteCard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  bool _isExpanded = false;

  // Determine which pattern is being used
  bool get _usingViewModel => widget.viewModel != null;

  @override
  void initState() {
    super.initState();
    _fetchNoteDetails();
  }

  Future<void> _fetchNoteDetails() async {
    try {
      // Get IDs based on which pattern is being used
      final projectId = _usingViewModel 
          ? null // ViewModel doesn't have project/user IDs
          : widget.note!['project_id'];
      
      final userId = _usingViewModel 
          ? null 
          : widget.note!['user_id'];

      String? email = 'User';
      String? projectName = 'Site';
      String? createdAtStr = '';

      // Only fetch from DB if using Map pattern
      if (!_usingViewModel && projectId != null && userId != null) {
        final project = await _supabase
            .from('projects')
            .select('name')
            .eq('id', projectId)
            .maybeSingle();
        
        final user = await _supabase
            .from('users')
            .select('email')
            .eq('id', userId)
            .maybeSingle();

        email = user?['email'] ?? 'User';
        projectName = project?['name'] ?? 'Site';

        if (widget.note!['created_at'] != null) {
          try {
            DateTime utcTime = DateTime.parse(widget.note!['created_at']);
            DateTime istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
            createdAtStr = DateFormat('MMM d, h:mm a').format(istTime);
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _details = {
            'email': email,
            'project_name': projectName,
            'created_at': createdAtStr,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching note details: $e');
      if (mounted) {
        setState(() {
          _details = {
            'email': 'User',
            'project_name': 'Site',
            'created_at': ''
          };
          _isLoading = false;
        });
      }
    }
  }

  // Get transcription based on pattern
  String? _getTranscription() {
    if (_usingViewModel) {
      return _buildTranscriptionFromViewModel();
    } else {
      return widget.note!['transcript_final'] 
          ?? widget.note!['transcription']
          ?? widget.note!['transcript_en_current']
          ?? widget.note!['transcript_raw_current'];
    }
  }

  String _buildTranscriptionFromViewModel() {
    final vm = widget.viewModel!;
    
    if (vm.originalLanguageLabel.toLowerCase() == 'en' ||
        vm.originalLanguageLabel.toLowerCase() == 'english') {
      return vm.originalTranscript;
    }
    
    if (vm.translatedTranscript != null) {
      return '[${vm.originalLanguageLabel}] ${vm.originalTranscript}\n\n[English] ${vm.translatedTranscript}';
    }
    
    return vm.originalTranscript;
  }

  String _getAudioUrl() {
    if (_usingViewModel) {
      return widget.viewModel!.audioUrl;
    } else {
      return widget.note!['audio_url'] ?? '';
    }
  }

  String _getNoteId() {
    if (_usingViewModel) {
      return widget.viewModel!.id;
    } else {
      return widget.note!['id'] ?? '';
    }
  }

  bool _isEdited() {
    if (_usingViewModel) {
      return !widget.viewModel!.isEditable;
    } else {
      return widget.note!['is_edited'] == true;
    }
  }

  String _getStatus() {
    if (_usingViewModel) {
      return widget.viewModel!.isProcessing ? 'processing' : 'completed';
    } else {
      return widget.note!['status'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_usingViewModel) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingM),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isThreadedReply = _usingViewModel 
        ? false 
        : (widget.note!['parent_id'] != null);
    
    final isEdited = _isEdited();
    final status = _getStatus();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(
                isThreadedReply: isThreadedReply,
                isEdited: isEdited,
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Audio Player
              _buildAudioSection(),

              // Transcription
              if (_isExpanded)
                _buildExpandedTranscription(status, isEdited)
              else
                _buildCollapsedTranscription(),

              // Manager ambient actions (ACK / ADD NOTE / CREATE ACTION)
              if (widget.onAcknowledge != null ||
                  widget.onAddNote != null ||
                  widget.onCreateAction != null)
                _buildManagerActions(),

              // Reply Button
              _buildReplyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool isThreadedReply,
    required bool isEdited,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: isThreadedReply
              ? AppTheme.infoBlue.withValues(alpha:0.2)
              : AppTheme.primaryIndigo,
          child: Icon(
            isThreadedReply ? Icons.reply : Icons.mic,
            color: isThreadedReply ? AppTheme.infoBlue : Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _details?['email'] ?? 'User',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isThreadedReply) ...[
                    const SizedBox(width: AppTheme.spacingS),
                    const CategoryBadge(
                      text: 'REPLY',
                      color: AppTheme.infoBlue,
                    ),
                  ],
                  if (widget.note?['intent'] == 'update') ...[
                    const SizedBox(width: AppTheme.spacingS),
                    const CategoryBadge(
                      text: 'UPDATE',
                      color: AppTheme.successGreen,
                    ),
                  ],
                  if (widget.isAcknowledged) ...[
                    const SizedBox(width: AppTheme.spacingS),
                    const CategoryBadge(
                      text: 'ACK\'D',
                      color: AppTheme.successGreen,
                      icon: Icons.check_circle,
                    ),
                  ],
                  if (isEdited) ...[
                    const SizedBox(width: AppTheme.spacingS),
                    const CategoryBadge(
                      text: 'EDITED',
                      color: AppTheme.warningOrange,
                      icon: Icons.edit,
                    ),
                  ],
                ],
              ),
              Text(
                _details?['project_name'] ?? 'Site',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (!_usingViewModel) // Only show date for Map pattern
          Text(
            _details?['created_at'] ?? '',
            style: AppTheme.caption,
          ),
      ],
    );
  }

  Widget _buildAudioSection() {
    final audioUrl = _getAudioUrl();
    
    if (audioUrl.isEmpty || !audioUrl.startsWith('http')) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Text(
                'Audio file not available',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.errorRed),
              ),
            ),
          ],
        ),
      );
    }

    return VoiceNoteAudioPlayer(audioUrl: audioUrl);
  }

  Widget _buildCollapsedTranscription() {
    if (_getStatus() == 'processing') {
      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacingM),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Processing transcription...',
              style: AppTheme.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final transcription = _getTranscription();
    if (transcription == null || transcription.isEmpty) {
      return const SizedBox.shrink();
    }

    // For ViewModel pattern, show original language
    if (_usingViewModel) {
      final vm = widget.viewModel!;
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (vm.originalLanguageLabel.toLowerCase() != 'en' &&
                    vm.originalLanguageLabel.toLowerCase() != 'english') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      vm.originalLanguageLabel.toUpperCase(),
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.warningOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                ],
                Text(
                  'Tap to expand',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              vm.originalTranscript,
              style: AppTheme.bodyMedium.copyWith(
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // For Map pattern, show preview
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap to expand',
            style: AppTheme.caption.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            transcription,
            style: AppTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedTranscription(String status, bool isEdited) {
    return TranscriptionDisplay(
      noteId: _getNoteId(),
      transcription: _getTranscription(),
      status: status,
      isEdited: isEdited,
    );
  }

  Widget _buildManagerActions() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingM),
      child: Row(
        children: [
          if (widget.onAcknowledge != null && !widget.isAcknowledged)
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('ACK', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.successGreen,
                  side: const BorderSide(color: AppTheme.successGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onPressed: widget.onAcknowledge,
              ),
            ),
          if (widget.onAcknowledge != null && !widget.isAcknowledged)
            const SizedBox(width: AppTheme.spacingS),
          if (widget.onAddNote != null)
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.note_add, size: 16),
                label: const Text('ADD NOTE', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.infoBlue,
                  side: const BorderSide(color: AppTheme.infoBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onPressed: widget.onAddNote,
              ),
            ),
          if (widget.onAddNote != null)
            const SizedBox(width: AppTheme.spacingS),
          if (widget.onCreateAction != null)
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.add_task, size: 16),
                label: const Text('CREATE ACTION', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryIndigo,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onPressed: widget.onCreateAction,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyButton() {
    return Column(
      children: [
        const SizedBox(height: AppTheme.spacingM),
        const Divider(height: 1),
        const SizedBox(height: AppTheme.spacingS),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: Icon(
              widget.isReplying ? Icons.stop : Icons.reply,
              size: 18,
            ),
            label: Text(
              widget.isReplying ? "Stop & Send Reply" : "Record Reply",
              style: const TextStyle(fontSize: 13),
            ),
            style: TextButton.styleFrom(
              foregroundColor: widget.isReplying
                  ? AppTheme.errorRed
                  : AppTheme.infoBlue,
            ),
            onPressed: widget.onReply,
          ),
        ),
      ],
    );
  }
}