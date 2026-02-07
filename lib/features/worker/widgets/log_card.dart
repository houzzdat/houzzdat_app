import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

/// LogCard widget for the My Logs tab.
/// - Play button in top-right triggers expand + audio playback.
/// - Tapping the card body only expands/collapses text.
/// - Record Reply uploads audio as a threaded voice_note with parent_id.
class LogCard extends StatefulWidget {
  final String id;
  final String englishText;
  final String originalText;
  final String languageCode;
  final String audioUrl;
  final String? translatedText;
  final String? accountId;
  final String? userId;
  final String? projectId;

  const LogCard({
    super.key,
    required this.id,
    required this.englishText,
    required this.originalText,
    required this.languageCode,
    required this.audioUrl,
    this.translatedText,
    this.accountId,
    this.userId,
    this.projectId,
  });

  @override
  State<LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<LogCard> {
  bool _isTextExpanded = false;
  bool _isAudioExpanded = false;
  bool _isReplying = false;
  bool _isUploadingReply = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorderService _recorderService = AudioRecorderService();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      if (!_isAudioExpanded) {
        setState(() => _isAudioExpanded = true);
      }
      await _audioPlayer.play(UrlSource(widget.audioUrl));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _handleReplyTap() async {
    if (_isReplying) {
      // Stop recording and upload as reply
      setState(() {
        _isReplying = false;
        _isUploadingReply = true;
      });

      try {
        final audioBytes = await _recorderService.stopRecording();
        if (audioBytes != null &&
            widget.projectId != null &&
            widget.userId != null &&
            widget.accountId != null) {
          await _recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: widget.projectId!,
            userId: widget.userId!,
            accountId: widget.accountId!,
            parentId: widget.id,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reply sent!'),
                backgroundColor: Colors.green,
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isExpanded => _isTextExpanded || _isAudioExpanded;

  @override
  Widget build(BuildContext context) {
    final isEnglish = widget.languageCode.toUpperCase() == 'EN' ||
        widget.languageCode.toUpperCase() == 'ENGLISH';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: _isExpanded ? 4 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content area — tapping body expands/collapses text
            InkWell(
              onTap: () => setState(() => _isTextExpanded = !_isTextExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // English text on top
                          Text(
                            widget.englishText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF212121),
                              height: 1.4,
                            ),
                            maxLines: _isTextExpanded ? null : 3,
                            overflow: _isTextExpanded ? null : TextOverflow.ellipsis,
                          ),

                          // Original language below (if not English)
                          if (!isEnglish && widget.originalText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EAF6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.languageCode.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A237E),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.originalText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                    maxLines: _isTextExpanded ? null : 2,
                                    overflow: _isTextExpanded ? null : TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Play button — top right
                    GestureDetector(
                      onTap: _togglePlayback,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8EAF6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? LucideIcons.pause : LucideIcons.play,
                          size: 20,
                          color: const Color(0xFF1A237E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded audio section
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isAudioExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedSection(isEnglish),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSection(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Audio scrubber
          Row(
            children: [
              Text(_formatDuration(_position),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF1A237E)),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDuration(_duration),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),

          const SizedBox(height: 14),

          // Record Reply button
          SizedBox(
            width: double.infinity,
            child: _isUploadingReply
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    icon: Icon(
                      _isReplying ? LucideIcons.square : LucideIcons.mic,
                      size: 16,
                    ),
                    label: Text(_isReplying ? 'STOP & SEND REPLY' : 'RECORD REPLY'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isReplying
                          ? Colors.red
                          : const Color(0xFF1A237E),
                      side: BorderSide(
                        color: _isReplying
                            ? Colors.red
                            : const Color(0xFF1A237E),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _handleReplyTap,
                  ),
          ),

          // Translation section (if non-English and has translation)
          if (!isEnglish && widget.translatedText != null && widget.translatedText!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFFFCA28), width: 3),
                ),
              ),
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRANSLATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    )),
                  const SizedBox(height: 6),
                  Text(widget.translatedText!,
                    style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
