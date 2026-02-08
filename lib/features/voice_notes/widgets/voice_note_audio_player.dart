import 'dart:async';
import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

// Conditional imports for web vs native
import 'voice_note_audio_player_native.dart'
    if (dart.library.html) 'voice_note_audio_player_web.dart'
    as platform_player;

/// Reusable audio player component for voice notes.
///
/// On web (PWA / mobile browser): uses HTML5 <audio> element directly,
/// bypassing `audioplayers` which has known failures on iOS Safari.
///
/// On native (Android / iOS): uses `audioplayers` package.
class VoiceNoteAudioPlayer extends StatefulWidget {
  final String audioUrl;

  const VoiceNoteAudioPlayer({
    super.key,
    required this.audioUrl,
  });

  @override
  State<VoiceNoteAudioPlayer> createState() => _VoiceNoteAudioPlayerState();
}

class _VoiceNoteAudioPlayerState extends State<VoiceNoteAudioPlayer> {
  late platform_player.AudioPlayerController _controller;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _validateAndInit();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndInit() {
    if (widget.audioUrl.isEmpty ||
        (!widget.audioUrl.startsWith('http://') &&
            !widget.audioUrl.startsWith('https://'))) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Invalid audio URL';
      });
      return;
    }

    _controller = platform_player.AudioPlayerController(
      url: widget.audioUrl,
      onDurationChanged: (d) {
        if (mounted) setState(() => _duration = d);
      },
      onPositionChanged: (p) {
        if (mounted) setState(() => _position = p);
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      },
      onError: (msg) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = msg;
            _isPlaying = false;
          });
        }
      },
    );
  }

  Future<void> _togglePlayback() async {
    if (_hasError) {
      _showErrorSnackbar();
      return;
    }

    try {
      if (_isPlaying) {
        await _controller.pause();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isPlaying = true);
        await _controller.play();
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to play audio';
          _isPlaying = false;
        });
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _controller.seek(position);
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  void _showErrorSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_errorMessage ?? 'Error playing audio'),
        backgroundColor: AppTheme.errorRed,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _hasError = false;
              _errorMessage = null;
            });
            _controller.dispose();
            _validateAndInit();
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Unavailable',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _errorMessage!,
                      style: AppTheme.caption.copyWith(color: AppTheme.errorRed),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.errorRed),
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = null;
                });
                _controller.dispose();
                _validateAndInit();
              },
              tooltip: 'Retry',
            ),
          ],
        ),
      );
    }

    return Container(
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
            tooltip: _isPlaying ? 'Pause' : 'Play',
          ),
          Expanded(
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AppTheme.primaryIndigo,
                    inactiveTrackColor: AppTheme.textSecondary.withValues(alpha: 0.3),
                    thumbColor: AppTheme.primaryIndigo,
                    overlayColor: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(
                      0.0,
                      _duration.inSeconds.toDouble().clamp(1.0, double.infinity),
                    ),
                    max: _duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0,
                    onChanged: (value) async {
                      await _seekTo(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      ),
                      if (_duration == Duration.zero && _isPlaying)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryIndigo,
                          ),
                        )
                      else
                        Text(
                          _formatDuration(_duration),
                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
