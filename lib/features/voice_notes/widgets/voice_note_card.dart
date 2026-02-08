import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';

/// Feed voice note card — mirrors ActionCardWidget's two-tier design.
///
/// Collapsed: 4-line compact layout
///   Line 1: Category icon + Category pill + badges + relative time
///   Line 2: Transcript preview (2 lines) or progress indicator
///   Line 3: Avatar + Sender · Project
///   Line 4: Action buttons (ACK / ADD NOTE / CREATE ACTION / REPLY)
///
/// Expanded: audio player, full transcript, translation
class VoiceNoteCard extends StatefulWidget {
  final Map<String, dynamic> note;
  final bool isReplying;
  final VoidCallback onReply;

  // Pre-resolved lookup data (from FeedTab cache)
  final String? senderName;
  final String? projectName;

  // Manager ambient update actions
  final VoidCallback? onAcknowledge;
  final VoidCallback? onAddNote;
  final VoidCallback? onCreateAction;
  final bool isAcknowledged;

  const VoiceNoteCard({
    super.key,
    required this.note,
    required this.isReplying,
    required this.onReply,
    this.senderName,
    this.projectName,
    this.onAcknowledge,
    this.onAddNote,
    this.onCreateAction,
    this.isAcknowledged = false,
  });

  @override
  State<VoiceNoteCard> createState() => _VoiceNoteCardState();
}

class _VoiceNoteCardState extends State<VoiceNoteCard> {
  bool _isExpanded = false;

  // ─── Data Accessors ──────────────────────────────────────────

  String get _noteId => widget.note['id']?.toString() ?? '';
  String get _audioUrl => widget.note['audio_url']?.toString() ?? '';
  String get _status => widget.note['status']?.toString() ?? 'processing';
  String get _category =>
      widget.note['category']?.toString() ??
      widget.note['ai_suggested_category']?.toString() ??
      '';

  bool get _isProcessing => _status == 'processing';
  bool get _isTranscribed => _status == 'transcribed';
  bool get _isTranslated => _status == 'translated';
  bool get _isCompleted => _status == 'completed';
  bool get _hasTranscript => _isTranscribed || _isTranslated || _isCompleted;
  bool get _isEdited => widget.note['is_edited'] == true;
  bool get _isReply => widget.note['parent_id'] != null;

  bool get _isEnglish {
    final lang = widget.note['detected_language_code']?.toString() ??
        widget.note['detected_language']?.toString() ??
        'en';
    return lang.toLowerCase() == 'en' || lang.toLowerCase() == 'english';
  }

  String get _languageCode {
    return (widget.note['detected_language_code']?.toString() ??
            widget.note['detected_language']?.toString() ??
            'EN')
        .toUpperCase();
  }

  /// Get best available transcript text
  String get _transcript {
    return widget.note['transcript_final']?.toString() ??
        widget.note['transcription']?.toString() ??
        widget.note['transcript_en_current']?.toString() ??
        widget.note['transcript_raw_current']?.toString() ??
        widget.note['transcript_raw']?.toString() ??
        '';
  }

  /// Get native/original language transcription text
  String get _nativeTranscript {
    if (_isEnglish) return _transcript;
    return widget.note['transcript_raw_current']?.toString() ??
        widget.note['transcript_raw']?.toString() ??
        '';
  }

  /// Get English translation (only relevant for non-English notes)
  String get _englishTranslation {
    return widget.note['transcript_en_current']?.toString() ??
        widget.note['transcript_final']?.toString() ??
        '';
  }

  // ─── Category / Color Config ────────────────────────────────

  static const _categoryConfig = <String, ({String label, Color color, IconData icon})>{
    'action_required': (label: 'ACTION', color: AppTheme.errorRed, icon: Icons.priority_high),
    'approval': (label: 'APPROVAL', color: AppTheme.warningOrange, icon: Icons.approval),
    'update': (label: 'UPDATE', color: AppTheme.successGreen, icon: Icons.update),
    'information': (label: 'INFO', color: AppTheme.infoBlue, icon: Icons.info_outline),
  };

  ({String label, Color color, IconData icon}) get _categoryDisplay {
    if (_category.isNotEmpty && _categoryConfig.containsKey(_category)) {
      return _categoryConfig[_category]!;
    }
    if (_isProcessing) {
      return (label: 'TRANSCRIBING', color: AppTheme.textSecondary, icon: Icons.hourglass_empty);
    }
    if (_isTranscribed) {
      return (label: 'TRANSLATING', color: AppTheme.infoBlue, icon: Icons.translate);
    }
    if (_isTranslated) {
      return (label: 'ANALYSING', color: AppTheme.infoBlue, icon: Icons.auto_awesome);
    }
    return (label: 'NOTE', color: AppTheme.textSecondary, icon: Icons.mic);
  }

  Color get _leftBorderColor => _categoryDisplay.color;

  // ─── Time Formatting ────────────────────────────────────────

  String get _relativeTime {
    final raw = widget.note['created_at'];
    if (raw == null) return '';
    try {
      final created = DateTime.parse(raw.toString());
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

  // ─── Action Button (same pattern as ActionCardWidget) ───────

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

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: _isExpanded ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4px left category border bar
            Container(width: 4, color: _leftBorderColor),
            // Card content
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
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

  // ─── Collapsed Content ─────────────────────────────────────

  Widget _buildCollapsedContent() {
    final cat = _categoryDisplay;
    final senderName = widget.senderName ?? 'User';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: Category icon + pill + badges + time
          Row(
            children: [
              Icon(cat.icon, size: 14, color: cat.color),
              const SizedBox(width: 6),
              CategoryBadge(text: cat.label, color: cat.color),
              if (_isReply) ...[
                const SizedBox(width: 6),
                const CategoryBadge(
                  text: 'REPLY',
                  color: AppTheme.infoBlue,
                  icon: Icons.reply,
                ),
              ],
              if (widget.isAcknowledged) ...[
                const SizedBox(width: 6),
                const CategoryBadge(
                  text: 'ACK\'D',
                  color: AppTheme.successGreen,
                  icon: Icons.check_circle,
                ),
              ],
              if (_isEdited) ...[
                const SizedBox(width: 6),
                const CategoryBadge(
                  text: 'EDITED',
                  color: AppTheme.warningOrange,
                  icon: Icons.edit,
                ),
              ],
              const Spacer(),
              Text(_relativeTime, style: AppTheme.caption),
            ],
          ),
          const SizedBox(height: 6),

          // Line 2: Transcript preview (2 lines) or progress indicator
          _buildTranscriptPreview(),
          const SizedBox(height: 6),

          // Line 3: Avatar + Sender · Project
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryIndigo,
                child: Text(
                  senderName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  [
                    senderName,
                    if (widget.projectName != null) widget.projectName!,
                  ].join(' \u00b7 '),
                  style: AppTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Language badge for non-English
              if (!_isEnglish && _hasTranscript)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _languageCode,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ─── Transcript Preview (collapsed) ─────────────────────────

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

    final text = _transcript;
    if (text.isEmpty) {
      return Text(
        'No transcription available',
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Typewriter for freshly transcribed, plain text otherwise
        if (_isTranscribed && !_isExpanded)
          _TypewriterText(
            text: text,
            maxLines: 2,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          )
        else
          Text(
            text,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        // Inline progress for translation/analysis
        if (!_isCompleted && _hasTranscript) ...[
          const SizedBox(height: 4),
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

  // ─── Action Row (Line 4) ────────────────────────────────────

  Widget _buildActionRow() {
    final actions = <Widget>[];

    // Manager ambient actions
    if (widget.onAcknowledge != null && !widget.isAcknowledged) {
      actions.add(_actionBtn('ACK', AppTheme.successGreen, widget.onAcknowledge!));
      actions.add(const SizedBox(width: 6));
    }

    if (widget.onAddNote != null) {
      actions.add(_actionBtn('ADD NOTE', AppTheme.infoBlue, widget.onAddNote!));
      actions.add(const SizedBox(width: 6));
    }

    if (widget.onCreateAction != null) {
      actions.add(_actionBtn('CREATE ACTION', AppTheme.primaryIndigo, widget.onCreateAction!));
      actions.add(const SizedBox(width: 6));
    }

    // Reply button
    actions.add(
      _actionBtn(
        widget.isReplying ? 'STOP & SEND' : 'REPLY',
        widget.isReplying ? AppTheme.errorRed : AppTheme.textSecondary,
        widget.onReply,
      ),
    );

    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
      child: Row(children: actions),
    );
  }

  // ─── Expanded Content ──────────────────────────────────────

  Widget _buildExpandedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),

        // Audio Player
        if (_audioUrl.isNotEmpty && _audioUrl.startsWith('http'))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: VoiceNoteAudioPlayer(audioUrl: _audioUrl),
            ),
          ),

        // Processing shimmer
        if (_isProcessing)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const ShimmerLoadingCard(height: 60),
                const SizedBox(height: 8),
                Text(
                  'AI is processing your voice note...',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

        // Full transcript section
        if (_hasTranscript || _isCompleted)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Non-English: show original + translation
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                  const SizedBox(height: 12),
                ],

                // Translation in-progress indicator
                if (!_isEnglish && _isTranscribed && _englishTranslation.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBlue.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border(
                        left: BorderSide(
                          color: AppTheme.infoBlue.withValues(alpha: 0.3),
                          width: 3,
                        ),
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
                  const SizedBox(height: 12),
                ],

                // English translation (non-English notes)
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
                ],

                // English notes: show full transcript
                if (_isEnglish && _transcript.isNotEmpty)
                  Text(
                    _transcript,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Typewriter Animation Widget ──────────────────────────────

/// Reveals text character-by-character like a typewriter.
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
