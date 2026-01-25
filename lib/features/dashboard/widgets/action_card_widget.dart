import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';

/// Expandable Action Card for Manager Dashboard
/// Shows AI summary prominently, expands to show audio and transcriptions
class ActionCardWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onInstruct;
  final VoidCallback onForward;

  const ActionCardWidget({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onInstruct,
    required this.onForward,
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

  Future<void> _loadVoiceNote() async {
    if (_voiceNote != null || widget.item['voice_note_id'] == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final note = await _supabase
          .from('voice_notes')
          .select('audio_url, transcription, is_edited, status')
          .eq('id', widget.item['voice_note_id'])
          .single();
      
      if (mounted) {
        setState(() {
          _voiceNote = note;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading voice note: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded && _voiceNote == null) {
      _loadVoiceNote();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item['status'] ?? 'pending';
    final priority = widget.item['priority']?.toString() ?? 'Med';
    final aiSummary = widget.item['summary'] ?? 'Action Item';
    final aiAnalysis = widget.item['ai_analysis'];

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // COLLAPSED VIEW - Always Visible
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PriorityIndicator(priority: priority),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AI Summary - PROMINENT
                            Text(
                              aiSummary,
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            
                            // Priority Badge
                            Row(
                              children: [
                                CategoryBadge(
                                  text: 'Priority: $priority',
                                  color: _getCategoryColor(),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                CategoryBadge(
                                  text: 'Status: $status',
                                  color: status == 'approved' 
                                      ? AppTheme.successGreen 
                                      : AppTheme.textSecondary,
                                  icon: status == 'approved' 
                                      ? Icons.check_circle 
                                      : Icons.pending,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.primaryIndigo,
                      ),
                    ],
                  ),
                  
                  // AI Analysis - Show if available
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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

            // EXPANDED VIEW - Audio & Transcriptions
            if (_isExpanded) ...[
              const Divider(height: 1),
              
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_voiceNote != null) ...[
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Title
                      Row(
                        children: [
                          const Icon(Icons.mic, size: 16, color: AppTheme.primaryIndigo),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'VOICE NOTE DETAILS',
                            style: AppTheme.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryIndigo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      
                      // Audio Player
                      if (_voiceNote!['audio_url'] != null) ...[
                        VoiceNoteAudioPlayer(
                          audioUrl: _voiceNote!['audio_url'],
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                      ],
                      
                      // Transcription Display
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
              
              const Divider(height: 1),
            ],

            // ACTION BUTTONS - Only if pending
            if (status == 'pending') ...[
              if (!_isExpanded) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 400) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildActionButton(
                            label: 'Approve',
                            icon: Icons.check_circle,
                            color: AppTheme.successGreen,
                            onPressed: widget.onApprove,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildActionButton(
                            label: 'Instruct',
                            icon: Icons.mic,
                            color: AppTheme.infoBlue,
                            onPressed: widget.onInstruct,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildActionButton(
                            label: 'Forward',
                            icon: Icons.forward,
                            color: AppTheme.warningOrange,
                            onPressed: widget.onForward,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'Approve',
                            icon: Icons.check_circle,
                            color: AppTheme.successGreen,
                            onPressed: widget.onApprove,
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Instruct',
                            icon: Icons.mic,
                            color: AppTheme.infoBlue,
                            onPressed: widget.onInstruct,
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Forward',
                            icon: Icons.forward,
                            color: AppTheme.warningOrange,
                            onPressed: widget.onForward,
                            isCompact: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isCompact = false,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: isCompact ? 16 : 18),
      label: Text(
        label,
        style: TextStyle(fontSize: isCompact ? 12 : 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? AppTheme.spacingS : AppTheme.spacingM,
        ),
      ),
      onPressed: onPressed,
    );
  }
}