import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

/// Full-screen dialog for recording voice instructions
/// Used by the INSTRUCT action to record a manager's voice note
/// directed back to the original sender of the action item.
class InstructVoiceDialog extends StatefulWidget {
  final Map<String, dynamic> actionItem;

  const InstructVoiceDialog({
    super.key,
    required this.actionItem,
  });

  @override
  State<InstructVoiceDialog> createState() => _InstructVoiceDialogState();
}

class _InstructVoiceDialogState extends State<InstructVoiceDialog> {
  final _recorder = AudioRecorderService();
  final _supabase = Supabase.instance.client;

  bool _isRecording = false;
  bool _isUploading = false;
  bool _hasRecorded = false;
  Uint8List? _recordedBytes;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.checkPermission();
    if (!hasPermission) {
      setState(() => _error = 'Microphone permission denied');
      return;
    }

    await _recorder.startRecording();
    setState(() {
      _isRecording = true;
      _hasRecorded = false;
      _recordedBytes = null;
      _recordingDuration = Duration.zero;
      _error = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final bytes = await _recorder.stopRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedBytes = bytes;
        _hasRecorded = bytes != null;
      });
    }
  }

  Future<void> _uploadAndSend() async {
    if (_recordedBytes == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final projectId = widget.actionItem['project_id'] as String;
      final accountId = widget.actionItem['account_id'] as String;

      // Find the original voice note's user_id (the person who needs the instruction)
      String? recipientId;
      final voiceNoteId = widget.actionItem['voice_note_id'];
      if (voiceNoteId != null) {
        try {
          final vn = await _supabase
              .from('voice_notes')
              .select('user_id')
              .eq('id', voiceNoteId)
              .single();
          recipientId = vn['user_id'] as String?;
        } catch (_) {}
      }

      // Upload voice note using AudioRecorderService
      // parentId links this instruction back to the original voice note
      // recipientId targets the original sender
      final url = await _recorder.uploadAudio(
        bytes: _recordedBytes!,
        projectId: projectId,
        userId: currentUser.id,
        accountId: accountId,
        parentId: voiceNoteId?.toString(),
        recipientId: recipientId,
      );

      if (url == null) throw Exception('Upload failed');

      // Get the created voice note ID for linking
      final recentNote = await _supabase
          .from('voice_notes')
          .select('id')
          .eq('user_id', currentUser.id)
          .eq('project_id', projectId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      // Link the instruction voice note to the action item
      await _supabase
          .from('action_items')
          .update({
            'delegation_voice_note_id': recentNote['id'],
            'status': 'in_progress',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.actionItem['id']);

      // Create notification for the recipient
      if (recipientId != null) {
        try {
          await _supabase.from('notifications').insert({
            'user_id': recipientId,
            'account_id': accountId,
            'project_id': projectId,
            'type': 'action_instructed',
            'title': 'New instruction received',
            'body': widget.actionItem['summary'] ?? 'Manager sent you an instruction',
            'reference_id': widget.actionItem['id'],
            'reference_type': 'action_item',
          });
        } catch (e) {
          debugPrint('Warning: Could not create notification: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error uploading instruction: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = 'Failed to send instruction: $e';
        });
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Record Instruction'),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isUploading ? null : () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              // Context card showing the action item being instructed on
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INSTRUCTING ON:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        widget.actionItem['summary'] ?? 'Action Item',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.actionItem['details'] != null &&
                          widget.actionItem['details'].toString().isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          widget.actionItem['details'].toString(),
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Recording indicator
              if (_isRecording) ...[
                const Icon(
                  Icons.mic,
                  size: 80,
                  color: AppTheme.errorRed,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                const Text(
                  'Recording your instruction...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ] else if (_hasRecorded) ...[
                const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppTheme.successGreen,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'Recorded: ${_formatDuration(_recordingDuration)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                const Text(
                  'Tap send to deliver your instruction',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.mic_none,
                  size: 80,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: AppTheme.spacingM),
                const Text(
                  'Tap to start recording',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                const Text(
                  'Record a voice instruction for the team member',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Action buttons
              if (_isUploading)
                const Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryIndigo),
                    SizedBox(height: AppTheme.spacingM),
                    Text(
                      'Sending instruction...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_hasRecorded) ...[
                      // Re-record button
                      FloatingActionButton(
                        heroTag: 'rerecord',
                        onPressed: _startRecording,
                        backgroundColor: AppTheme.textSecondary,
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                      const SizedBox(width: AppTheme.spacingXL),
                    ],

                    // Main record/stop button
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: FloatingActionButton(
                        heroTag: 'record',
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                        backgroundColor:
                            _isRecording ? AppTheme.errorRed : AppTheme.primaryIndigo,
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),

                    if (_hasRecorded) ...[
                      const SizedBox(width: AppTheme.spacingXL),
                      // Send button
                      FloatingActionButton(
                        heroTag: 'send',
                        onPressed: _uploadAndSend,
                        backgroundColor: AppTheme.successGreen,
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: AppTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }
}
