import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Reusable audio player component for voice notes
/// UPDATED: Enhanced error handling, validation, and user feedback
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _validateAudioUrl();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Validate audio URL before attempting playback
  void _validateAudioUrl() {
    if (widget.audioUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Audio URL is empty';
      });
      return;
    }

    if (!widget.audioUrl.startsWith('http://') && 
        !widget.audioUrl.startsWith('https://')) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Invalid audio URL format';
      });
      return;
    }

    // Check if URL has a valid audio extension
    final validExtensions = ['.mp3', '.m4a', '.wav', '.webm', '.ogg', '.aac'];
    final hasValidExtension = validExtensions.any(
      (ext) => widget.audioUrl.toLowerCase().contains(ext)
    );

    if (!hasValidExtension) {
      debugPrint('Warning: Audio URL may not have a valid audio extension: ${widget.audioUrl}');
      // Don't set error - just log warning, as some URLs might still work
    }
  }

  /// Setup audio player event listeners
  void _setupAudioPlayer() {
    // Duration changed - total length of audio
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    // Position changed - current playback position
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    // Player state changed
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
      }
    });

    // Playback completed
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _playerState = PlayerState.completed;
        });
      }
    });
  }

  /// Toggle play/pause
  Future<void> _togglePlayback() async {
    // If there's an error, don't attempt playback
    if (_hasError) {
      _showErrorSnackbar();
      return;
    }

    try {
      if (_isPlaying) {
        // Pause playback
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        // Start or resume playback
        if (_playerState == PlayerState.completed) {
          // Restart from beginning if completed
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        } else if (_playerState == PlayerState.paused) {
          // Resume from current position
          await _audioPlayer.resume();
        } else {
          // Start fresh playback
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        }
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to play audio';
        _isPlaying = false;
      });

      if (mounted) {
        _showErrorSnackbar();
      }
    }
  }

  /// Seek to specific position
  Future<void> _seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  /// Show error message to user
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
            _togglePlayback();
          },
        ),
      ),
    );
  }

  /// Format duration as MM:SS
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Build error state UI
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorRed,
            size: 20,
          ),
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
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.errorRed,
                    ),
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
              _validateAudioUrl();
            },
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error state if validation failed
    if (_hasError) {
      return _buildErrorState();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        children: [
          // Play/Pause Button
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 40,
            ),
            color: AppTheme.primaryIndigo,
            onPressed: _togglePlayback,
            tooltip: _isPlaying ? 'Pause' : 'Play',
          ),
          
          // Playback Controls
          Expanded(
            child: Column(
              children: [
                // Progress Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: AppTheme.primaryIndigo,
                    inactiveTrackColor: AppTheme.textSecondary.withOpacity(0.3),
                    thumbColor: AppTheme.primaryIndigo,
                    overlayColor: AppTheme.primaryIndigo.withOpacity(0.2),
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
                
                // Time Labels
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      // Show loading indicator if duration not yet loaded
                      if (_duration == Duration.zero && _isPlaying)
                        SizedBox(
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
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Speed Control (Optional - can be added later)
          // IconButton(
          //   icon: const Icon(Icons.speed, size: 20),
          //   color: AppTheme.textSecondary,
          //   onPressed: () {
          //     // Implement playback speed control
          //   },
          //   tooltip: 'Playback speed',
          // ),
        ],
      ),
    );
  }
}