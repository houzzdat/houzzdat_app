import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/core/services/connectivity_service.dart';

/// Queues voice note uploads when offline and processes them when connectivity returns.
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const _queueKey = 'pending_voice_note_uploads';
  final _recorder = AudioRecorderService();
  final _connectivity = ConnectivityService();
  bool _isProcessing = false;

  /// Initialize: listen for connectivity changes and process queue when online.
  void initialize() {
    _connectivity.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline) {
      processPendingUploads();
    }
  }

  /// Queue a voice note for upload when offline.
  Future<void> queueUpload({
    required Uint8List bytes,
    required String projectId,
    required String userId,
    required String accountId,
    String? parentId,
    String? recipientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];

    // Store metadata (audio bytes are base64 encoded)
    final entry = jsonEncode({
      'audio_base64': base64Encode(bytes),
      'project_id': projectId,
      'user_id': userId,
      'account_id': accountId,
      'parent_id': parentId,
      'recipient_id': recipientId,
      'queued_at': DateTime.now().toIso8601String(),
    });

    queue.add(entry);
    await prefs.setStringList(_queueKey, queue);
    debugPrint('Queued voice note for offline upload. Queue size: ${queue.length}');
  }

  /// Get the count of pending uploads.
  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    return queue.length;
  }

  /// Process all pending uploads.
  Future<void> processPendingUploads() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? [];

      if (queue.isEmpty) {
        _isProcessing = false;
        return;
      }

      debugPrint('Processing ${queue.length} pending voice note uploads...');

      final remaining = <String>[];

      for (final entryJson in queue) {
        try {
          final entry = jsonDecode(entryJson) as Map<String, dynamic>;
          final bytes = base64Decode(entry['audio_base64'] as String);

          final result = await _recorder.uploadAudio(
            bytes: Uint8List.fromList(bytes),
            projectId: entry['project_id'] as String,
            userId: entry['user_id'] as String,
            accountId: entry['account_id'] as String,
            parentId: entry['parent_id'] as String?,
            recipientId: entry['recipient_id'] as String?,
          );

          if (result != null) {
            debugPrint('Successfully uploaded queued voice note: ${result['id']}');
          } else {
            // Upload returned null but didn't throw — keep in queue
            remaining.add(entryJson);
          }
        } catch (e) {
          debugPrint('Failed to upload queued voice note: $e');
          remaining.add(entryJson);
        }
      }

      await prefs.setStringList(_queueKey, remaining);
      debugPrint('Queue processing complete. Remaining: ${remaining.length}');
    } finally {
      _isProcessing = false;
    }
  }

  /// Clear all pending uploads.
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
  }
}
