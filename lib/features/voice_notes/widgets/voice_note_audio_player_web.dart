import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web (PWA / mobile browser) audio player controller.
///
/// Uses HTML5 `<audio>` element directly, bypassing the `audioplayers`
/// package which has known broken `UrlSource` on iOS Safari
/// (see audioplayers issues #1743 and #1663).
///
/// The `<audio>` element is appended off-screen to the DOM and removed
/// on [dispose]. All event wiring is done through standard DOM events.
class AudioPlayerController {
  final String url;
  final void Function(Duration) onDurationChanged;
  final void Function(Duration) onPositionChanged;
  final void Function() onComplete;
  final void Function(String) onError;

  late final web.HTMLAudioElement _audio;
  Timer? _positionTimer;
  bool _disposed = false;

  AudioPlayerController({
    required this.url,
    required this.onDurationChanged,
    required this.onPositionChanged,
    required this.onComplete,
    required this.onError,
  }) {
    _audio = web.HTMLAudioElement();
    _audio.preload = 'metadata';
    _audio.src = url;

    // Append off-screen so the browser creates a media session for it
    _audio.style.display = 'none';
    web.document.body?.append(_audio);

    _setupListeners();
  }

  // ---- DOM event wiring ----

  void _setupListeners() {
    // Duration is available once metadata has loaded
    _audio.onloadedmetadata = (web.Event _) {
      _reportDuration();
    }.toJS;

    // Also fires when duration info becomes more accurate (streaming)
    _audio.ondurationchange = (web.Event _) {
      _reportDuration();
    }.toJS;

    // Playback ended
    _audio.onended = (web.Event _) {
      _stopPositionTimer();
      onComplete();
    }.toJS;

    // Error handling
    _audio.onerror = (web.Event _) {
      _stopPositionTimer();
      final code = _audio.error?.code ?? 0;
      final message = _audio.error?.message ?? 'Unknown error';
      onError('Audio error (code $code): $message');
    }.toJS;

    // Stall / waiting — not treated as fatal, just logged
    _audio.onstalled = (web.Event _) {
      debugPrint('Web audio stalled for: $url');
    }.toJS;
  }

  void _reportDuration() {
    final dur = _audio.duration;
    if (!dur.isNaN && !dur.isInfinite && dur > 0) {
      onDurationChanged(Duration(milliseconds: (dur * 1000).round()));
    }
  }

  // ---- Position polling ----
  // HTML5 <audio> fires `timeupdate` ~4 times/sec which is too coarse for
  // a smooth slider. Instead we use a 200ms Dart timer while playing.

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) {
        if (_disposed) return;
        final cur = _audio.currentTime;
        if (!cur.isNaN) {
          onPositionChanged(Duration(milliseconds: (cur * 1000).round()));
        }
      },
    );
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  // ---- Public API ----

  Future<void> play() async {
    try {
      // The play() call returns a JS Promise — await it.
      await _audio.play().toDart;
      _startPositionTimer();
    } catch (e) {
      onError('Web playback error: $e');
    }
  }

  Future<void> pause() async {
    try {
      _audio.pause();
      _stopPositionTimer();
    } catch (e) {
      debugPrint('Web pause error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      _audio.currentTime = position.inMilliseconds / 1000.0;
      onPositionChanged(position);
    } catch (e) {
      debugPrint('Web seek error: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _stopPositionTimer();
    try {
      _audio.pause();
      _audio.src = ''; // release network connection
      _audio.remove(); // remove from DOM
    } catch (e) {
      debugPrint('Web audio dispose error: $e');
    }
  }
}
