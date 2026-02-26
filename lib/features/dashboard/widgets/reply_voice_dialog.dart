import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

/// Dedicated dialog for replying to a voice note.
/// Shows original note context, records reply, and allows preview before send.
/// Returns a Map with 'audioBytes' and optional 'textReply', or null if cancelled.
class ReplyVoiceDialog extends StatefulWidget {
  final String senderName;
  final String? transcriptPreview;
  final String? projectName;
  final DateTime? originalDate;

  const ReplyVoiceDialog({
    super.key,
    required this.senderName,
    this.transcriptPreview,
    this.projectName,
    this.originalDate,
  });

  @override
  State<ReplyVoiceDialog> createState() => _ReplyVoiceDialogState();
}

class _ReplyVoiceDialogState extends State<ReplyVoiceDialog> {
  final _recorder = AudioRecorderService();
  final _textController = TextEditingController();

  bool _isRecording = false;
  bool _hasRecorded = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  Uint8List? _recordedBytes;
  bool _useTextReply = false;

  // UX-audit TL-11: Playback of recorded reply before sending
  AudioPlayer? _player;
  bool _isPlayingPreview = false;
  String? _tempFilePath;

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    _player?.dispose();
    // Clean up temp file
    if (_tempFilePath != null) {
      File(_tempFilePath!).delete().catchError((e) {
        debugPrint('Error cleaning temp reply file: $e');
        return File('');
      });
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
    final hasPermission = await _recorder.checkPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied. Please enable it in Settings.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    await _recorder.startRecording();
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _hasRecorded = false;
      _recordedBytes = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordingDuration = Duration(seconds: timer.tick));
      }
    });
  }

  Future<void> _stopRecording() async {
    HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
    _timer?.cancel();
    final bytes = await _recorder.stopRecording();
    setState(() {
      _isRecording = false;
      _recordedBytes = bytes;
      _hasRecorded = bytes != null;
    });

    // UX-audit TL-11: Prepare playback after recording
    if (bytes != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/reply_preview_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await tempFile.writeAsBytes(bytes);
        _tempFilePath = tempFile.path;
        _player?.dispose();
        _player = AudioPlayer();
        await _player!.setSource(DeviceFileSource(tempFile.path));
        _player!.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlayingPreview = false);
        });
      } catch (e) {
        debugPrint('Error preparing reply playback: $e');
      }
    }
  }

  // UX-audit TL-11: Toggle playback of recorded reply
  Future<void> _togglePreviewPlayback() async {
    if (_player == null) return;
    try {
      if (_isPlayingPreview) {
        await _player!.pause();
        if (mounted) setState(() => _isPlayingPreview = false);
      } else {
        await _player!.resume();
        if (mounted) setState(() => _isPlayingPreview = true);
      }
    } catch (e) {
      debugPrint('Reply playback error: $e');
    }
  }

  void _handleSend() {
    if (_useTextReply) {
      final text = _textController.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a reply message')),
        );
        return;
      }
      Navigator.pop(context, {
        'textReply': text,
      });
    } else {
      if (_recordedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please record a voice reply first')),
        );
        return;
      }
      Navigator.pop(context, {
        'audioBytes': _recordedBytes,
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.reply, color: AppTheme.primaryIndigo),
                  const SizedBox(width: 8),
                  const Text(
                    'Reply to Voice Note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close', // UX-audit #21
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Original note context
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border(
                    left: BorderSide(
                      color: AppTheme.primaryIndigo,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          widget.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (widget.projectName != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${widget.projectName}',
                            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    if (widget.transcriptPreview != null && widget.transcriptPreview!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.transcriptPreview!.length > 120
                            ? '${widget.transcriptPreview!.substring(0, 120)}...'
                            : widget.transcriptPreview!,
                        style: AppTheme.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Toggle: Voice / Text reply (#30)
              Row(
                children: [
                  Expanded(
                    child: _ToggleButton(
                      icon: Icons.mic,
                      label: 'Voice Reply',
                      isSelected: !_useTextReply,
                      onTap: () => setState(() => _useTextReply = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToggleButton(
                      icon: Icons.text_fields,
                      label: 'Text Reply',
                      isSelected: _useTextReply,
                      onTap: () => setState(() => _useTextReply = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Voice recording section
              if (!_useTextReply) ...[
                Center(
                  child: Column(
                    children: [
                      // Timer display
                      Text(
                        _formatDuration(_recordingDuration),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          color: _isRecording ? AppTheme.errorRed : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_isRecording) ...[
                        // Stop button
                        ElevatedButton.icon(
                          onPressed: _stopRecording,
                          icon: const Icon(Icons.stop, size: 24),
                          label: const Text('Stop Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                        ),
                      ] else if (_hasRecorded) ...[
                        // Preview after recording
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Recording ready (${_formatDuration(_recordingDuration)})',
                                style: const TextStyle(
                                  color: AppTheme.successGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // UX-audit TL-11: Play/Re-record row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_player != null)
                              TextButton.icon(
                                onPressed: _togglePreviewPlayback,
                                icon: Icon(
                                  _isPlayingPreview ? Icons.pause : Icons.play_arrow,
                                  size: 18,
                                ),
                                label: Text(_isPlayingPreview ? 'Pause' : 'Play'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryIndigo,
                                ),
                              ),
                            if (_player != null) const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _startRecording,
                              icon: const Icon(Icons.replay, size: 18),
                              label: const Text('Re-record'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Start button
                        ElevatedButton.icon(
                          onPressed: _startRecording,
                          icon: const Icon(Icons.mic, size: 24),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryIndigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Text reply section
              if (_useTextReply) ...[
                TextField(
                  controller: _textController,
                  maxLines: 4,
                  maxLength: 500, // UX-audit TL-12: character limit with counter
                  decoration: InputDecoration(
                    hintText: 'Type your reply...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_useTextReply || _hasRecorded) ? _handleSend : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text('Send Reply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryIndigo.withValues(alpha: 0.1)
              : AppTheme.backgroundGrey,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? AppTheme.primaryIndigo : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primaryIndigo : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryIndigo : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
