import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:convert';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/transcription_display.dart';

/// Enhanced Action Card with stage-aware UI
class ActionCardWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onRefresh;
  final Color? stageColor;

  const ActionCardWidget({
    super.key,
    required this.item,
    this.onRefresh,
    this.stageColor,
  });

  @override
  State<ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends State<ActionCardWidget> {
  final _supabase = Supabase.instance.client;
  bool _isExpanded = false;
  Map<String, dynamic>? _voiceNote;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_isExpanded && widget.item['voice_note_id'] != null) {
      _loadVoiceNote();
    }
  }

  Color _getPriorityColor() {
    switch ((widget.item['priority']?.toString() ?? 'med').toLowerCase()) {
      case 'high': return AppTheme.errorRed;
      case 'medium':
      case 'med': return AppTheme.warningOrange;
      case 'low': return AppTheme.successGreen;
      default: return AppTheme.textSecondary;
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

  Future<void> _loadVoiceNote() async {
    if (_voiceNote != null || widget.item['voice_note_id'] == null) return;

    setState(() => _isLoading = true);

    try {
      final note = await _supabase
          .from('voice_notes')
          .select('audio_url, transcription, transcript_final, transcript_en_current, is_edited, status')
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _parseConfidence() {
    try {
      final analysis = widget.item['ai_analysis'];
      if (analysis is String) {
        final json = jsonDecode(analysis);
        return (json['confidence_score'] ?? 0.5) as double;
      } else if (analysis is Map) {
        return (analysis['confidence_score'] ?? 0.5) as double;
      }
    } catch (e) {
      debugPrint('Error parsing confidence: $e');
    }
    return 0.5;
  }

  Color _getConfidenceColor() {
    final confidence = _parseConfidence();
    if (confidence >= 0.8) return AppTheme.successGreen;
    if (confidence >= 0.6) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }

  String _getTimeAgo() {
    final createdAt = widget.item['created_at'];
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt.toString());
      return timeago.format(date);
    } catch (e) {
      return '';
    }
  }

  Future<void> _handleApprove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Action Item'),
        content: Text('Approve: "${widget.item['summary']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('action_items').update({
          'status': 'approved',
          'approved_by': _supabase.auth.currentUser!.id,
          'approved_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.item['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Action approved!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          widget.onRefresh?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  Future<void> _handleMarkComplete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Action Item'),
        content: Text('Mark "${widget.item['summary']}" as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('action_items').update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.item['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Action completed!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          widget.onRefresh?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  Future<void> _handleReopen() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Action Item'),
        content: Text('Move "${widget.item['summary']}" back to queue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningOrange),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('action_items').update({
          'status': 'pending',
        }).eq('id', widget.item['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Action reopened!'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
          widget.onRefresh?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  void _showSecondaryActions() {
    final status = widget.item['status'] ?? 'pending';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: const Row(
                children: [
                  Icon(Icons.more_horiz, color: AppTheme.primaryIndigo),
                  SizedBox(width: AppTheme.spacingS),
                  Text('MORE ACTIONS',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.arrow_upward, color: AppTheme.errorRed),
              title: const Text('Set Priority: HIGH'),
              onTap: () {
                Navigator.pop(context);
                _updatePriority('High');
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove, color: AppTheme.warningOrange),
              title: const Text('Set Priority: MEDIUM'),
              onTap: () {
                Navigator.pop(context);
                _updatePriority('Med');
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: AppTheme.successGreen),
              title: const Text('Set Priority: LOW'),
              onTap: () {
                Navigator.pop(context);
                _updatePriority('Low');
              },
            ),

            if (status == 'in_progress' || status == 'verifying')
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppTheme.successGreen),
                title: const Text('Mark Completed'),
                onTap: () {
                  Navigator.pop(context);
                  _handleMarkComplete();
                },
              ),

            if (status == 'completed')
              ListTile(
                leading: const Icon(Icons.replay, color: AppTheme.warningOrange),
                title: const Text('Reopen'),
                onTap: () {
                  Navigator.pop(context);
                  _handleReopen();
                },
              ),

            const SizedBox(height: AppTheme.spacingS),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePriority(String priority) async {
    try {
      await _supabase.from('action_items').update({
        'priority': priority,
      }).eq('id', widget.item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Priority updated to $priority'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Widget _buildStageActions(String status) {
    if (status == 'pending') {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('APPROVE ACTION'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
            ),
            onPressed: _handleApprove,
          ),
        ),
      );
    }

    if (status == 'in_progress' || status == 'verifying') {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('MARK COMPLETE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
            ),
            onPressed: _handleMarkComplete,
          ),
        ),
      );
    }

    if (status == 'completed') {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('REOPEN'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.warningOrange,
              side: const BorderSide(color: AppTheme.warningOrange),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
            ),
            onPressed: _handleReopen,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item['status'] ?? 'pending';
    final priority = widget.item['priority']?.toString() ?? 'Med';
    final aiSummary = widget.item['summary'] ?? 'Action Item';
    final aiDetails = widget.item['details'];
    final assignee = widget.item['assigned_to_name'] ?? widget.item['assigned_to_email'];
    final timeAgo = _getTimeAgo();
    final stageColor = widget.stageColor ?? _getPriorityColor();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      elevation: _isExpanded ? AppTheme.elevationMedium : AppTheme.elevationLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: InkWell(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          if (_isExpanded && _voiceNote == null) _loadVoiceNote();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color bar — stage + priority accent
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: stageColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusL),
                    bottomLeft: Radius.circular(AppTheme.radiusL),
                  ),
                ),
              ),
              // Card content
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Priority dot instead of emoji circle
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(aiSummary,
                                      style: AppTheme.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: AppTheme.spacingS),
                                    Wrap(
                                      spacing: AppTheme.spacingS,
                                      runSpacing: AppTheme.spacingXS,
                                      children: [
                                        CategoryBadge(text: priority.toUpperCase(), color: _getPriorityColor()),
                                        CategoryBadge(
                                          text: status.toUpperCase(),
                                          color: status == 'completed' ? AppTheme.successGreen : AppTheme.textSecondary,
                                          icon: status == 'completed' ? Icons.check_circle : Icons.pending),
                                        if (status == 'pending') ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppTheme.spacingS, vertical: AppTheme.spacingXS),
                                            decoration: BoxDecoration(
                                              color: _getConfidenceColor().withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                              border: Border.all(color: _getConfidenceColor().withOpacity(0.3))),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.psychology, size: 12, color: _getConfidenceColor()),
                                                const SizedBox(width: AppTheme.spacingXS),
                                                Text('AI: ${(_parseConfidence() * 100).toStringAsFixed(0)}%',
                                                  style: AppTheme.caption.copyWith(
                                                    color: _getConfidenceColor(), fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                onPressed: _showSecondaryActions,
                                tooltip: 'More actions'),
                            ],
                          ),

                          if (aiDetails != null && aiDetails.toString().isNotEmpty && !_isExpanded) ...[
                            const SizedBox(height: AppTheme.spacingM),
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundGrey,
                                borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                              child: Text(aiDetails,
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],

                          // Timestamp + assignee footer
                          if (timeAgo.isNotEmpty || assignee != null) ...[
                            const SizedBox(height: AppTheme.spacingS),
                            Row(
                              children: [
                                if (timeAgo.isNotEmpty) ...[
                                  Icon(Icons.access_time, size: 13, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text(timeAgo,
                                    style: AppTheme.caption.copyWith(color: Colors.grey.shade400)),
                                ],
                                if (timeAgo.isNotEmpty && assignee != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                                    child: Text('·', style: TextStyle(color: Colors.grey.shade400)),
                                  ),
                                if (assignee != null) ...[
                                  Icon(Icons.person_outline, size: 13, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(assignee.toString(),
                                      style: AppTheme.caption.copyWith(color: Colors.grey.shade400),
                                      overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_isExpanded) ...[
                      const Divider(height: 1),
                      if (_isLoading)
                        const Padding(padding: EdgeInsets.all(AppTheme.spacingL),
                          child: Center(child: CircularProgressIndicator()))
                      else if (_voiceNote != null) ...[
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (aiDetails != null && aiDetails.toString().isNotEmpty) ...[
                                Text('DETAILS', style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(aiDetails, style: AppTheme.bodyMedium),
                                const SizedBox(height: AppTheme.spacingM),
                                const Divider(),
                                const SizedBox(height: AppTheme.spacingM),
                              ],

                              Text('ORIGINAL VOICE NOTE', style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                              const SizedBox(height: AppTheme.spacingM),

                              if (_voiceNote!['audio_url'] != null)
                                VoiceNoteAudioPlayer(audioUrl: _voiceNote!['audio_url']),

                              TranscriptionDisplay(
                                noteId: widget.item['voice_note_id'],
                                transcription: _voiceNote!['transcript_final'] ??
                                    _voiceNote!['transcription'] ??
                                    _voiceNote!['transcript_en_current'],
                                status: _voiceNote!['status'] ?? '',
                                isEdited: _voiceNote!['is_edited']),
                            ],
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Text('No voice note attached',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ],

                    // Contextual stage actions
                    const Divider(height: 1),
                    _buildStageActions(status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
