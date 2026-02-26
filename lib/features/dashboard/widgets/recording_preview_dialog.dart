import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// UX-audit TL-03: Dialog shown after recording stops, allowing playback
/// preview before submit. Now includes audio playback so managers can listen
/// before deciding to submit or discard.
///
/// Returns `true` if the user confirms, `false`/null if discarded.
class RecordingPreviewDialog extends StatefulWidget {
  final Uint8List audioBytes;
  final Duration recordingDuration;
  final String? contextLabel;

  const RecordingPreviewDialog({
    super.key,
    required this.audioBytes,
    required this.recordingDuration,
    this.contextLabel,
  });

  @override
  State<RecordingPreviewDialog> createState() => _RecordingPreviewDialogState();
}

class _RecordingPreviewDialogState extends State<RecordingPreviewDialog> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isPlayerReady = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  Future<void> _setupPlayer() async {
    try {
      // Write bytes to temp file for playback
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await tempFile.writeAsBytes(widget.audioBytes);
      _tempFilePath = tempFile.path;

      // Set up listeners
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      // Set the source
      await _player.setSource(DeviceFileSource(tempFile.path));

      if (mounted) {
        setState(() => _isPlayerReady = true);
      }
    } catch (e) {
      debugPrint('Error setting up audio preview: $e');
      // Player setup failed — dialog still works, just no playback
      if (mounted) setState(() => _isPlayerReady = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    // Clean up temp file
    if (_tempFilePath != null) {
      File(_tempFilePath!).delete().catchError((e) {
        debugPrint('Error cleaning temp preview file: $e');
        return File('');
      });
    }
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _player.resume();
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Playback toggle error: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    // Use known recording duration if player hasn't reported one yet
    final displayDuration = _duration > Duration.zero ? _duration : widget.recordingDuration;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              color: AppTheme.successGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Recording Complete',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          if (widget.contextLabel != null) ...[
            Text(
              widget.contextLabel!,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],

          // Audio playback section — UX-audit TL-03
          if (_isPlayerReady) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  // Play button + slider
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          size: 40,
                          color: AppTheme.primaryIndigo,
                        ),
                        onPressed: _togglePlayback,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: _isPlaying ? 'Pause' : 'Play preview',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: AppTheme.primaryIndigo,
                            inactiveTrackColor: AppTheme.textSecondary.withValues(alpha: 0.2),
                            thumbColor: AppTheme.primaryIndigo,
                          ),
                          child: Slider(
                            value: _position.inMilliseconds.toDouble().clamp(
                              0.0,
                              displayDuration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                            ),
                            max: displayDuration.inMilliseconds.toDouble() > 0
                                ? displayDuration.inMilliseconds.toDouble()
                                : 1.0,
                            onChanged: (value) {
                              _seekTo(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Time labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                        ),
                        Text(
                          _formatDuration(displayDuration),
                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Info card (duration + size)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoItem(
                  icon: Icons.timer,
                  label: 'Duration',
                  value: _formatDuration(widget.recordingDuration),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.textSecondary.withValues(alpha: 0.2),
                ),
                _InfoItem(
                  icon: Icons.storage,
                  label: 'Size',
                  value: _formatBytes(widget.audioBytes.length),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _isPlayerReady
                ? 'Listen to your recording, then submit or discard.'
                : 'Submit this voice note or discard and re-record?',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
            Navigator.pop(context, false);
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Discard'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorRed,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
            Navigator.pop(context, true);
          },
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Submit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
