import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Native (Android / iOS) audio player controller.
///
/// Wraps the `audioplayers` [AudioPlayer] which works reliably on native
/// platforms but has known issues on iOS Safari / mobile web.
class AudioPlayerController {
  final String url;
  final void Function(Duration) onDurationChanged;
  final void Function(Duration) onPositionChanged;
  final void Function() onComplete;
  final void Function(String) onError;

  late final AudioPlayer _player;
  final List<StreamSubscription> _subs = [];

  AudioPlayerController({
    required this.url,
    required this.onDurationChanged,
    required this.onPositionChanged,
    required this.onComplete,
    required this.onError,
  }) {
    _player = AudioPlayer();
    _setupListeners();
  }

  void _setupListeners() {
    _subs.add(
      _player.onDurationChanged.listen(
        onDurationChanged,
        onError: (e) => debugPrint('Duration stream error: $e'),
      ),
    );

    _subs.add(
      _player.onPositionChanged.listen(
        onPositionChanged,
        onError: (e) => debugPrint('Position stream error: $e'),
      ),
    );

    _subs.add(
      _player.onPlayerComplete.listen(
        (_) => onComplete(),
        onError: (e) => debugPrint('Complete stream error: $e'),
      ),
    );

    _subs.add(
      _player.onLog.listen(
        (msg) => debugPrint('AudioPlayer log: $msg'),
      ),
    );
  }

  Future<void> play() async {
    try {
      await _player.play(UrlSource(url));
    } catch (e) {
      onError('Native playback error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Native pause error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Native seek error: $e');
    }
  }

  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _player.dispose();
  }
}
