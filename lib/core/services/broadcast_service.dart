import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

/// Service for broadcasting voice messages to multiple team members.
class BroadcastService {
  final _supabase = Supabase.instance.client;
  final _audioService = AudioRecorderService();

  /// Sends a broadcast voice message to selected team members.
  ///
  /// Creates one master voice note and distributes it via voice_note_forwards
  /// table. Sends notifications to all recipients.
  ///
  /// Returns [BroadcastResult] with success status and recipient count.
  Future<BroadcastResult> sendBroadcast({
    required Uint8List audioBytes,
    required String accountId,
    required String projectId,
    required String senderId,
    required List<String> recipientIds,
    String? textNote,
  }) async {
    try {
      // 1. Upload voice note via AudioRecorderService
      debugPrint('Broadcasting to ${recipientIds.length} recipients');

      final url = await _audioService.uploadAudio(
        bytes: audioBytes,
        projectId: projectId,
        userId: senderId,
        accountId: accountId,
        recipientId: null, // Broadcast note - no specific recipient
      );

      if (url == null) {
        throw Exception('Failed to upload voice note');
      }

      debugPrint('Voice note uploaded: $url');

      // 2. Get the created voice note ID
      // Wait a moment for the insert to complete
      await Future.delayed(const Duration(milliseconds: 500));

      final voiceNote = await _supabase
          .from('voice_notes')
          .select('id')
          .eq('audio_url', url)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (voiceNote == null) {
        throw Exception('Voice note not found after upload');
      }

      final voiceNoteId = voiceNote['id'] as String;
      debugPrint('Voice note ID: $voiceNoteId');

      // 3. Create forwards for each recipient (with optional text note)
      final forwards = recipientIds.map((recipientId) {
        final forward = <String, dynamic>{
          'original_note_id': voiceNoteId,
          'forwarded_to': recipientId,
          'forwarded_from': senderId,
        };

        if (textNote != null && textNote.isNotEmpty) {
          forward['forward_note'] = textNote;
        }

        return forward;
      }).toList();

      await _supabase.from('voice_note_forwards').insert(forwards);
      debugPrint('Created ${forwards.length} forwards');

      // 4. Create notifications for each recipient
      final notifications = recipientIds.map((recipientId) => {
        'user_id': recipientId,
        'account_id': accountId,
        'project_id': projectId,
        'type': 'note_added',
        'title': 'Team Broadcast from Manager',
        'body': textNote ?? 'New message for team',
        'reference_id': voiceNoteId,
        'reference_type': 'voice_note',
      }).toList();

      await _supabase.from('notifications').insert(notifications);
      debugPrint('Created ${notifications.length} notifications');

      return BroadcastResult(
        success: true,
        recipientCount: recipientIds.length,
        voiceNoteId: voiceNoteId,
      );
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
      rethrow;
    }
  }
}

/// Result of a broadcast operation.
class BroadcastResult {
  final bool success;
  final int recipientCount;
  final String voiceNoteId;

  BroadcastResult({
    required this.success,
    required this.recipientCount,
    required this.voiceNoteId,
  });
}
