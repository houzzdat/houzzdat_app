import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Reusable audio player component for voice notes
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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
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

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint("Playback Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }
}