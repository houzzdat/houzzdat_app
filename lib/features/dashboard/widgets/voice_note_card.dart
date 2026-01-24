import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchNoteDetails();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _fetchNoteDetails() async {
    try {
      final supabase = Supabase.instance.client;
      final project = await supabase
          .from('projects')
          .select('name')
          .eq('id', widget.note['project_id'])
          .single();
      final user = await supabase
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
          _details = {'email': 'User', 'project_name': 'Site', 'created_at': ''};
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(UrlSource(widget.note['audio_url']));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint("Playback Error: $e");
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Get the validated transcription (user-edited or original)
  String? _getValidatedTranscript() {
    if (widget.note['transcript_final'] != null && 
        widget.note['transcript_final'].toString().isNotEmpty) {
      return widget.note['transcript_final'];
    }
    return widget.note['transcription'];
  }

  bool _isEdited() {
    return widget.note['is_edited'] == true;
  }

  Map<String, String> _parseTranscription(String? transcription) {
    if (transcription == null || transcription.isEmpty) {
      return {'original': '', 'translated': '', 'language': ''};
    }

    // Pattern: [LANGUAGE] original text \n\n [English] translated text
    final languagePattern = RegExp(
      r'\[(.*?)\]\s*(.*?)(?:\n\n\[English\]\s*(.*))?$',
      dotAll: true,
    );
    final match = languagePattern.firstMatch(transcription);

    if (match != null) {
      final language = match.group(1) ?? '';
      final original = match.group(2) ?? '';
      final translated = match.group(3) ?? '';

      return {
        'language': language,
        'original': original.trim(),
        'translated': translated.trim(),
      };
    }

    return {
      'language': 'English',
      'original': transcription,
      'translated': '',
    };
  }

  Widget _buildLanguageBadge(String language) {
    if (language.isEmpty || language.toLowerCase() == 'english') {
      return const SizedBox.shrink();
    }

    final flagEmojis = {
      'Spanish': '🇪🇸', 'French': '🇫🇷', 'German': '🇩🇪',
      'Italian': '🇮🇹', 'Portuguese': '🇵🇹', 'Russian': '🇷🇺',
      'Japanese': '🇯🇵', 'Korean': '🇰🇷', 'Chinese': '🇨🇳',
      'Arabic': '🇸🇦', 'Hindi': '🇮🇳', 'Telugu': '🇮🇳',
      'Tamil': '🇮🇳', 'Marathi': '🇮🇳', 'Bengali': '🇮🇳',
      'Urdu': '🇵🇰', 'Kannada': '🇮🇳', 'Malayalam': '🇮🇳',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            flagEmojis[language] ?? '🌍',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            language.toUpperCase(),
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.warningOrange,
            ),
          ),
        ],
      ),
    );
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
    final transcription = _getValidatedTranscript();
    final parsedTranscription = _parseTranscription(transcription);
    final status = widget.note['status'] ?? '';
    final isEdited = _isEdited();

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
            // Header
            Row(
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
                            CategoryBadge(
                              text: 'REPLY',
                              color: AppTheme.infoBlue,
                            ),
                          ],
                          if (isEdited) ...[
                            const SizedBox(width: AppTheme.spacingS),
                            CategoryBadge(
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
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Audio Player
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 40,
                    ),
                    color: AppTheme.primaryIndigo,
                    onPressed: _togglePlayback,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value: _position.inSeconds.toDouble(),
                            max: _duration.inSeconds.toDouble() > 0
                                ? _duration.inSeconds.toDouble()
                                : 1.0,
                            onChanged: (value) async {
                              await _audioPlayer.seek(Duration(seconds: value.toInt()));
                            },
                            activeColor: AppTheme.primaryIndigo,
                            inactiveColor: AppTheme.textSecondary.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(_position), style: AppTheme.caption),
                              Text(_formatDuration(_duration), style: AppTheme.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Transcription Section
            if (transcription != null && transcription.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingM),
              
              _buildLanguageBadge(parsedTranscription['language']!),

              // Original Language (if not English)
              if (parsedTranscription['original']!.isNotEmpty &&
                  parsedTranscription['language']!.toLowerCase() != 'english') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
                  ),
                  child: Text(
                    parsedTranscription['original']!,
                    style: AppTheme.bodyLarge.copyWith(
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              // English Translation (if available)
              if (parsedTranscription['translated']!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.infoBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: AppTheme.infoBlue.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.translate, size: 14, color: AppTheme.infoBlue),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'ENGLISH',
                            style: AppTheme.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.infoBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        parsedTranscription['translated']!,
                        style: AppTheme.bodyMedium.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (parsedTranscription['original']!.isNotEmpty &&
                         parsedTranscription['language']!.toLowerCase() == 'english') ...[
                // English-only transcription
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
                  ),
                  child: Text(
                    parsedTranscription['original']!,
                    style: AppTheme.bodyMedium.copyWith(height: 1.5),
                  ),
                ),
              ],
            ] else if (status == 'processing' || status == 'validating') ...[
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    status == 'validating'
                        ? 'Awaiting validation...'
                        : 'Processing...',
                    style: AppTheme.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],

            // Reply Button
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
        ),
      ),
    );
  }
}