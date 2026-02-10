import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';

/// Redesigned LogCard with dual collapsed/expanded views.
///
/// Collapsed: header (recipient · type badge · time) + 2-line transcript preview
/// Expanded: full transcript, translation, audio player, delete/reply, manager response
class LogCard extends StatefulWidget {
  final Map<String, dynamic> note;
  final String accountId;
  final String userId;
  final String? projectId;
  final VoidCallback? onDeleted;

  const LogCard({
    super.key,
    required this.note,
    required this.accountId,
    required this.userId,
    this.projectId,
    this.onDeleted,
  });

  @override
  State<LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<LogCard> {
  bool _isExpanded = false;
  bool _isReplying = false;
  bool _isUploadingReply = false;
  bool _isDeleting = false;
  final _recorderService = AudioRecorderService();

  // ─── Category Config ─────────────────────────────────────────

  static const _categoryConfig = <String, ({String label, Color color, IconData icon})>{
    'action_required': (label: 'Action Needed', color: AppTheme.errorRed, icon: Icons.priority_high),
    'approval': (label: 'Approval', color: AppTheme.warningOrange, icon: Icons.approval),
    'update': (label: 'Update', color: AppTheme.successGreen, icon: Icons.update),
    'information': (label: 'Info', color: AppTheme.infoBlue, icon: Icons.info_outline),
  };

  static const _statusConfig = <String, ({String label, Color color})>{
    'pending': (label: 'Pending', color: AppTheme.warningOrange),
    'approved': (label: 'Approved', color: AppTheme.successGreen),
    'rejected': (label: 'Rejected', color: AppTheme.errorRed),
    'in_progress': (label: 'In Progress', color: AppTheme.infoBlue),
    'verifying': (label: 'Verifying', color: AppTheme.warningOrange),
    'completed': (label: 'Completed', color: AppTheme.successGreen),
  };

  // ─── Data Accessors ──────────────────────────────────────────

  String get _noteId => widget.note['id']?.toString() ?? '';
  String get _audioUrl => widget.note['audio_url']?.toString() ?? '';
  String get _status => widget.note['status']?.toString() ?? 'processing';
  String? get _recipientName => widget.note['recipient_name']?.toString();
  Map<String, dynamic>? get _actionItem =>
      widget.note['action_item'] as Map<String, dynamic>?;
  List? get _managerResponses => widget.note['manager_responses'] as List?;

  String get _category =>
      widget.note['category']?.toString() ??
      widget.note['ai_suggested_category']?.toString() ??
      '';

  DateTime? get _createdAt {
    final raw = widget.note['created_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool get _isProcessing => _status == 'processing';
  bool get _isTranscribed => _status == 'transcribed';
  bool get _isTranslated => _status == 'translated';
  bool get _isCompleted => _status == 'completed';
  /// True when we have at least the raw transcript to show
  bool get _hasTranscript => _isTranscribed || _isTranslated || _isCompleted;

  bool get _isEnglish {
    final lang = widget.note['detected_language_code']?.toString() ??
        widget.note['detected_language']?.toString() ??
        'en';
    return lang.toLowerCase() == 'en' || lang.toLowerCase() == 'english';
  }

  /// Get native/original language transcription text.
  String get _nativeTranscript {
    if (_isEnglish) {
      return widget.note['transcript_en_current']?.toString() ??
          widget.note['transcript_final']?.toString() ??
          widget.note['transcription']?.toString() ??
          '';
    }
    return widget.note['transcript_raw_current']?.toString() ??
        widget.note['transcript_raw']?.toString() ??
        '';
  }

  /// Get English translation (only relevant for non-English notes).
  String get _englishTranslation {
    return widget.note['transcript_en_current']?.toString() ??
        widget.note['transcript_final']?.toString() ??
        widget.note['transcription']?.toString() ??
        '';
  }

  String get _languageCode {
    return (widget.note['detected_language_code']?.toString() ??
            widget.note['detected_language']?.toString() ??
            'EN')
        .toUpperCase();
  }

  /// Whether the note can be deleted (< 5 minutes old).
  bool get _canDelete {
    final created = _createdAt;
    if (created == null) return false;
    return DateTime.now().difference(created).inMinutes < 5;
  }

  /// Remaining minutes for delete window.
  int get _deleteMinutesLeft {
    final created = _createdAt;
    if (created == null) return 0;
    final diff = DateTime.now().difference(created).inMinutes;
    return (5 - diff).clamp(0, 5);
  }

  ({String label, Color color, IconData icon}) get _categoryDisplay {
    if (_category.isNotEmpty && _categoryConfig.containsKey(_category)) {
      return _categoryConfig[_category]!;
    }
    if (_isProcessing) {
      return (label: 'Transcribing', color: AppTheme.textSecondary, icon: Icons.hourglass_empty);
    }
    if (_isTranscribed) {
      return (label: 'Translating', color: AppTheme.infoBlue, icon: Icons.translate);
    }
    if (_isTranslated) {
      return (label: 'Analysing', color: AppTheme.infoBlue, icon: Icons.auto_awesome);
    }
    return (label: 'Note', color: AppTheme.textSecondary, icon: Icons.mic);
  }

  Color get _leftBorderColor => _categoryDisplay.color;

  // ─── Time Formatting ─────────────────────────────────────────

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inHours < 48) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(time);
  }

  // ─── Delete Logic ────────────────────────────────────────────

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text(
          'This will remove the message and any linked action items. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final supabase = Supabase.instance.client;

      // Delete linked action items first
      await supabase
          .from('action_items')
          .delete()
          .eq('voice_note_id', _noteId);

      // Delete the voice note
      await supabase.from('voice_notes').delete().eq('id', _noteId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        widget.onDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete voice note. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ─── Reply Logic (preserved from original) ──────────────────

  Future<void> _handleReplyTap() async {
    if (_isReplying) {
      setState(() {
        _isReplying = false;
        _isUploadingReply = true;
      });

      try {
        final audioBytes = await _recorderService.stopRecording();
        if (audioBytes != null &&
            widget.projectId != null) {
          await _recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: widget.projectId!,
            userId: widget.userId,
            accountId: widget.accountId,
            parentId: _noteId,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reply sent'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send reply: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingReply = false);
      }
    } else {
      final hasPermission = await _recorderService.checkPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
        }
        return;
      }
      await _recorderService.startRecording();
      setState(() => _isReplying = true);
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catDisplay = _categoryDisplay;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: _isExpanded ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _leftBorderColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsed content (always visible)
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: recipient · badge · time
                    _buildHeader(catDisplay),
                    const SizedBox(height: 8),
                    // Transcript preview
                    _buildTranscriptPreview(),
                  ],
                ),
              ),
            ),

            // Expanded section
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedSection(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header Row ──────────────────────────────────────────────

  Widget _buildHeader(({String label, Color color, IconData icon}) catDisplay) {
    return Row(
      children: [
        // Category icon
        Icon(catDisplay.icon, size: 16, color: catDisplay.color),
        const SizedBox(width: 6),

        // Recipient name
        Flexible(
          child: Text(
            _recipientName ?? 'Manager',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Dot separator
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('·',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),

        // Category badge
        CategoryBadge(
          text: catDisplay.label,
          color: catDisplay.color,
        ),

        const Spacer(),

        // Relative time
        if (_createdAt != null)
          Text(
            _formatRelativeTime(_createdAt!),
            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
          ),

        const SizedBox(width: 4),

        // Expand/collapse chevron
        Icon(
          _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          size: 20,
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }

  // ─── Transcript Preview (collapsed) ──────────────────────────

  Widget _buildTranscriptPreview() {
    // Still waiting for ASR — show spinner
    if (_isProcessing) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Transcribing...',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    final text = _nativeTranscript;
    if (text.isEmpty) {
      return Text(
        'No transcription available',
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Show transcript with typewriter effect for fresh results,
    // or inline progress indicator if still translating/analysing
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transcript text — use typewriter animation if just transcribed
        if (_isTranscribed && !_isExpanded)
          _TypewriterText(
            text: text,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
          )
        else
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
            maxLines: _isExpanded ? null : 2,
            overflow: _isExpanded ? null : TextOverflow.ellipsis,
          ),

        // Show inline progress for translation/analysis
        if (!_isCompleted && _hasTranscript) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.infoBlue.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isTranscribed ? 'Translating...' : 'Analysing...',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.infoBlue.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── Expanded Section ────────────────────────────────────────

  Widget _buildExpandedSection() {
    // Only show shimmer if ASR hasn't completed yet
    if (_isProcessing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            const ShimmerLoadingCard(height: 60),
            const SizedBox(height: 8),
            Text(
              'AI is processing your voice note...',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Full native transcription with language label
          if (!_isEnglish && _nativeTranscript.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Original',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _languageCode,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryIndigo,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _nativeTranscript,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Translation in progress indicator
          if (!_isEnglish && _isTranscribed && _englishTranslation.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border(
                  left: BorderSide(color: AppTheme.infoBlue.withValues(alpha: 0.3), width: 3),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.infoBlue.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Translating to English...',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.infoBlue,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // English translation (only if not English)
          if (!_isEnglish && _englishTranslation.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: const Border(
                  left: BorderSide(color: AppTheme.infoBlue, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ENGLISH TRANSLATION',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.infoBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _englishTranslation,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // If English: show full transcript (no label needed)
          if (_isEnglish && _nativeTranscript.isNotEmpty) ...[
            Text(
              _nativeTranscript,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Audio Player (lazy loaded only when expanded)
          if (_audioUrl.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: VoiceNoteAudioPlayer(audioUrl: _audioUrl),
            ),

          const SizedBox(height: 12),

          // Action row: Delete + Reply
          _buildActionRow(),

          // Manager response section
          const SizedBox(height: 8),
          _buildManagerResponse(),
        ],
      ),
    );
  }

  // ─── Action Row (Delete + Reply) ─────────────────────────────

  Widget _buildActionRow() {
    return Row(
      children: [
        // Delete button (conditional: < 5 min old)
        if (_canDelete && !_isDeleting)
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text('Delete (${_deleteMinutesLeft}m left)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: const BorderSide(color: AppTheme.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(fontSize: 13),
              ),
              onPressed: _handleDelete,
            ),
          )
        else if (_isDeleting)
          const Expanded(
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          )
        else
          const Spacer(),

        if (_canDelete) const SizedBox(width: 12),

        // Record Reply button
        Expanded(
          child: _isUploadingReply
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : OutlinedButton.icon(
                  icon: Icon(
                    _isReplying ? Icons.stop : Icons.mic,
                    size: 16,
                  ),
                  label: Text(_isReplying ? 'Stop & Send' : 'Record Reply'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isReplying
                        ? AppTheme.errorRed
                        : AppTheme.primaryIndigo,
                    side: BorderSide(
                      color: _isReplying
                          ? AppTheme.errorRed
                          : AppTheme.primaryIndigo,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: _handleReplyTap,
                ),
        ),
      ],
    );
  }

  // ─── Manager Response Section ────────────────────────────────

  Widget _buildManagerResponse() {
    final actionItem = _actionItem;
    final responses = _managerResponses;

    // No action item = awaiting
    if (actionItem == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Awaiting response',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Has action item — show status + latest interaction
    final aiStatus = actionItem['status']?.toString() ?? 'pending';
    final statusDisplay =
        _statusConfig[aiStatus] ?? (label: aiStatus.toUpperCase(), color: AppTheme.textSecondary);

    // Get latest manager interaction (skip worker's own)
    Map<String, dynamic>? latestResponse;
    if (responses != null && responses.isNotEmpty) {
      // Find last interaction that isn't from the current worker
      for (int i = responses.length - 1; i >= 0; i--) {
        final r = responses[i] as Map<String, dynamic>;
        if (r['user_id']?.toString() != widget.userId) {
          latestResponse = r;
          break;
        }
      }
      // If all interactions are from the worker, show the latest anyway
      latestResponse ??=
          Map<String, dynamic>.from(responses.last as Map);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusDisplay.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border(
          left: BorderSide(color: statusDisplay.color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge + action label
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusDisplay.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusDisplay.label,
                  style: TextStyle(
                    color: statusDisplay.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (latestResponse != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'by ${latestResponse['user_name'] ?? 'Manager'}',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Interaction timestamp
                if (latestResponse['timestamp'] != null)
                  Text(
                    _formatRelativeTime(
                      DateTime.parse(latestResponse['timestamp']),
                    ),
                    style:
                        AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
              ],
            ],
          ),

          // Interaction details
          if (latestResponse != null &&
              latestResponse['details'] != null &&
              latestResponse['details'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${latestResponse['action']?.toString().toUpperCase() ?? ''} — ${latestResponse['details']}',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // "View all" link if multiple interactions
          if (responses != null && responses.length > 1) ...[
            const SizedBox(height: 6),
            Text(
              'View all ${responses.length} interactions',
              style: AppTheme.caption.copyWith(
                color: AppTheme.infoBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Typewriter Animation Widget ──────────────────────────────

/// Reveals text character-by-character like a typewriter.
/// Used for fresh transcription results so the user sees text appear
/// progressively instead of all at once.
class _TypewriterText extends StatefulWidget {
  final String text;
  final int? maxLines;
  final TextStyle style;

  const _TypewriterText({
    required this.text,
    required this.style,
    this.maxLines,
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _visibleChars = 0;

  @override
  void initState() {
    super.initState();
    final charCount = widget.text.length;
    // Speed: ~30ms per character, max 3 seconds total
    final durationMs = (charCount * 30).clamp(300, 3000);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    _controller.addListener(() {
      final newVisible = (_controller.value * widget.text.length).round();
      if (newVisible != _visibleChars) {
        setState(() => _visibleChars = newVisible);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.text.substring(0, _visibleChars),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
