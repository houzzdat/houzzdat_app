import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; 
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:web/web.dart' as web;
import 'dart:js_interop';

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final _supabase = Supabase.instance.client;

  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  final List<web.Blob> _recordedChunks = [];
  Completer<Uint8List>? _completer;

  /// MIME type actually used for web recording (detected at record time).
  /// Prefer MP4/AAC (Safari + Chrome 121+) over WebM (Chrome-only playback).
  String _webMimeType = 'audio/webm';

  Future<bool> checkPermission() async {
    if (kIsWeb) {
      try {
        final jsAnyStream = await web.window.navigator.mediaDevices
            .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
            .toDart;
        
        if (jsAnyStream != null) {
          final stream = jsAnyStream as web.MediaStream;
          final tracks = stream.getTracks().toDart;
          for (var track in tracks) {
            (track as web.MediaStreamTrack).stop();
          }
          return true;
        }
        return false;
      } catch (e) { 
        debugPrint("Web Permission Error: $e");
        return false; 
      }
    }
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording() async {
    if (kIsWeb) {
      try {
        final jsAnyStream = await web.window.navigator.mediaDevices
            .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
            .toDart;
            
        if (jsAnyStream != null) {
          _mediaStream = jsAnyStream as web.MediaStream;

          // Detect best recording format — prefer MP4 for universal playback
          if (web.MediaRecorder.isTypeSupported('audio/mp4')) {
            _webMimeType = 'audio/mp4';
          } else if (web.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
            _webMimeType = 'audio/webm;codecs=opus';
          } else {
            _webMimeType = 'audio/webm';
          }
          debugPrint('Recording format: $_webMimeType');

          _mediaRecorder = web.MediaRecorder(
            _mediaStream!,
            web.MediaRecorderOptions(mimeType: _webMimeType),
          );
          _recordedChunks.clear();
          _completer = Completer<Uint8List>();

          _mediaRecorder!.ondataavailable = (web.BlobEvent event) {
            if (event.data.size > 0) {
              _recordedChunks.add(event.data);
            }
          }.toJS;

          _mediaRecorder!.onstop = (web.Event event) {
            try {
              final blobParts = _recordedChunks.map((e) => e as JSAny).toList().toJS;
              final blob = web.Blob(blobParts, web.BlobPropertyBag(type: _webMimeType));
              final reader = web.FileReader();
              
              reader.onloadend = (web.ProgressEvent e) {
                final result = reader.result;
                if (result != null && result.isA<JSArrayBuffer>()) {
                  final buffer = (result as JSArrayBuffer).toDart;
                  _completer!.complete(buffer.asUint8List());
                }
              }.toJS;
              
              reader.readAsArrayBuffer(blob);
            } catch (e) {
              _completer?.completeError(e);
            }
          }.toJS;
          
          _mediaRecorder!.start();
        }
      } catch (e) { 
        debugPrint("Web Record Error: $e");
      }
    } else {
      if (await checkPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = p.join(directory.path, 'log_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      }
    }
  }

  Future<Uint8List?> stopRecording() async {
    if (kIsWeb) {
      if (_mediaRecorder != null && _mediaRecorder!.state != 'inactive') {
        _mediaRecorder!.stop();
        if (_mediaStream != null) {
          final tracks = _mediaStream!.getTracks().toDart;
          for (var track in tracks) {
            (track as web.MediaStreamTrack).stop();
          }
          _mediaStream = null;
        }
      }
      return _completer?.future;
    }
    final path = await _audioRecorder.stop();
    return path != null ? await File(path).readAsBytes() : null;
  }

  /// Upload audio and create voice note record
  /// Transcription will be triggered automatically via database trigger
  Future<String?> uploadAudio({
    required Uint8List bytes, 
    required String projectId, 
    required String userId, 
    required String accountId,
    String? parentId,
    String? recipientId,
  }) async {
    try {
      // Use the format detected during recording (MP4 on Safari/Chrome 121+, WebM fallback)
      final isMP4 = !kIsWeb || _webMimeType.contains('mp4');
      final ext = isMP4 ? 'm4a' : 'webm';
      final contentType = isMP4 ? 'audio/mp4' : 'audio/webm';
      final path = 'log_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload to storage with correct MIME type
      await _supabase.storage.from('voice-notes').uploadBinary(
        path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: true)
      );
      
      final String url = _supabase.storage.from('voice-notes').getPublicUrl(path);
      
      // Create voice note record with status 'processing'
      // The database trigger will automatically call the edge function
      // DO NOT manually call the edge function - it causes duplicate processing
      final res = await _supabase.from('voice_notes').insert({
        'user_id': userId, 
        'project_id': projectId, 
        'account_id': accountId, 
        'audio_url': url, 
        'parent_id': parentId, 
        'recipient_id': recipientId, 
        'status': 'processing'  // ✅ Correct - let edge function handle rest
      }).select().single();
      
      debugPrint("✅ Voice note created: ${res['id']}");
      debugPrint("   Database trigger will handle transcription automatically");
      
      // REMOVED: Manual edge function call
      // The database trigger 'transcribe_on_insert' handles this
      
      return url;
    } catch (e) { 
      debugPrint("Upload Error: $e");
      return null; 
    }
  }
}