import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class VoiceNotePlayerCard extends StatefulWidget {
  final Map<String, dynamic> note;
  final Map<String, dynamic> details;

  const VoiceNotePlayerCard({
    super.key,
    required this.note,
    required this.details,
  });

  @override
  State<VoiceNotePlayerCard> createState() => _VoiceNotePlayerCardState();
}

class _VoiceNotePlayerCardState extends State<VoiceNotePlayerCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
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
      debugPrint('Playback error: $e');
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Map<String, String> _parseTranscription(String? transcription) {
    if (transcription == null || transcription.isEmpty) {
      return {'original': '', 'translated': '', 'language': ''};
    }

    final languagePattern = RegExp(
      r'\[(.*?)\]\s*(.*?)(?:\n\n\[English\]\s*(.*))?$',
      dotAll: true
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
      'Spanish': '🇪🇸',
      'French': '🇫🇷',
      'German': '🇩🇪',
      'Italian': '🇮🇹',
      'Portuguese': '🇵🇹',
      'Russian': '🇷🇺',
      'Japanese': '🇯🇵',
      'Korean': '🇰🇷',
      'Chinese': '🇨🇳',
      'Arabic': '🇸🇦',
      'Hindi': '🇮🇳',
      'Telugu': '🇮🇳',
      'Tamil': '🇮🇳',
      'Marathi': '🇮🇳',
      'Bengali': '🇮🇳',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            flagEmojis[language] ?? '🌐',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            language,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThreadedReply = widget.note['parent_id'] != null;
    final transcription = widget.note['transcription'];
    final parsedTranscription = _parseTranscription(transcription);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isThreadedReply ? Colors.blue.shade100 : AppTheme.primaryIndigo,
                  child: Icon(
                    isThreadedReply ? Icons.reply : Icons.mic,
                    color: isThreadedReply ? Colors.blue : Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.details['email'] ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (isThreadedReply) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'REPLY',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        widget.details['project_name'] ?? 'Site',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.details['created_at'] ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
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
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _position.inSeconds.toDouble(),
                            max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                            onChanged: (value) async {
                              await _audioPlayer.seek(Duration(seconds: value.toInt()));
                            },
                            activeColor: AppTheme.primaryIndigo,
                            inactiveColor: Colors.grey[300],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(_position), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              Text(_formatDuration(_duration), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (transcription != null && transcription.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildLanguageBadge(parsedTranscription['language']!),
              
              if (parsedTranscription['original']!.isNotEmpty && 
                  parsedTranscription['language']!.toLowerCase() != 'english') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha:0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha:0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.translate, size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            "ORIGINAL (${parsedTranscription['language']})",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parsedTranscription['original']!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (parsedTranscription['translated']!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha:0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha:0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            "ENGLISH TRANSLATION",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parsedTranscription['translated']!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (parsedTranscription['original']!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha:0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha:0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TRANSCRIPTION",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parsedTranscription['original']!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (widget.note['status'] == 'processing')
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12, 
                      height: 12, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Transcribing and detecting language...',
                      style: TextStyle(
                        fontSize: 11, 
                        color: Colors.grey[600], 
                        fontStyle: FontStyle.italic
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}