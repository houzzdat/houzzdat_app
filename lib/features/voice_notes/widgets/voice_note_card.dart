import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';

/// Main voice note card - orchestrates all components
class VoiceNoteCard extends StatefulWidget {
  final Map<String, dynamic> note;
  final bool isReplying;
  final VoidCallback onReply;

  const VoiceNoteCard({
    super.key,
    required this.note,
    required this.isReplying,
    required this.onReply,
  });

  @override
  State<VoiceNoteCard> createState() => _VoiceNoteCardState();
}

class _VoiceNoteCardState extends State<VoiceNoteCard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNoteDetails();
  }

  Future<void> _fetchNoteDetails() async {
    try {
      final project = await _supabase
          .from('projects')
          .select('name')
          .eq('id', widget.note['project_id'])
          .single();
      
      final user = await _supabase
          .from('users')
          .select('email')
          .eq('id', widget.note['user_id'])
          .single();

      DateTime utcTime = DateTime.parse(widget.note['created_at']);
      DateTime istTime = utcTime.add(const Duration(hours: 5, minutes: 30));

      if (mounted) {
        setState(() {
          _details = {
            'email': user['email'] ?? 'User',
            'project_name': project['name'] ?? 'Site',
            'created_at': DateFormat('MMM d, h:mm a').format(istTime),
          };
          _isLoading = false;
        });
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingM),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isThreadedReply = widget.note['parent_id'] != null;
    final isEdited = widget.note['is_edited'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(
              isThreadedReply: isThreadedReply,
              isEdited: isEdited,
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Audio Player Section
            VoiceNoteAudioPlayer(audioUrl: widget.note['audio_url']),

            // Transcription Section
            TranscriptionDisplay(
              noteId: widget.note['id'],
              transcription: widget.note['transcription'],
              status: widget.note['status'] ?? '',
            ),

            // Reply Button Section
            _buildReplyButton(),
          ],
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
              ? AppTheme.infoBlue.withOpacity(0.2)
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
                    _details!['email'],
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
                _details!['project_name'],
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          _details!['created_at'],
          style: AppTheme.caption,
        ),
      ],
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