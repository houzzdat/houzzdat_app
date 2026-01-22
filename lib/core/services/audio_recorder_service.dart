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

  Future<bool> checkPermission() async {
    if (kIsWeb) {
      try {
        final jsAnyStream = await web.window.navigator.mediaDevices
            .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
            .toDart;
        
        // FIX: Cast JSAny? to web.MediaStream to access getTracks()
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
            
        // FIX: Cast JSAny? to web.MediaStream
        if (jsAnyStream != null) {
          _mediaStream = jsAnyStream as web.MediaStream;
          _mediaRecorder = web.MediaRecorder(_mediaStream!);
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
              final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'audio/webm'));
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
            // FIX: Cast JSAny? to web.MediaStreamTrack to access stop()
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

  Future<String?> uploadAudio({
    required Uint8List bytes, 
    required String projectId, 
    required String userId, 
    required String accountId,
    String? parentId,
    String? recipientId,
  }) async {
    try {
      const ext = kIsWeb ? 'webm' : 'm4a';
      final path = 'log_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      await _supabase.storage.from('voice-notes').uploadBinary(
        path, bytes, fileOptions: FileOptions(contentType: 'audio/$ext', upsert: true)
      );
      
      final String url = _supabase.storage.from('voice-notes').getPublicUrl(path);
      
      final res = await _supabase.from('voice_notes').insert({
        'user_id': userId, 'project_id': projectId, 'account_id': accountId, 
        'audio_url': url, 'parent_id': parentId, 'recipient_id': recipientId, 'status': 'processing'
      }).select().single();
      
      try {
        await _supabase.functions.invoke('transcribe-audio', body: {'record': res});
      } catch (e) {
        debugPrint("Transcription trigger warning: $e");
      }
      
      return url;
    } catch (e) { 
      debugPrint("Upload Error: $e");
      return null; 
    }
  }
}