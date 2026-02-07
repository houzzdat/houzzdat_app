import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/worker/widgets/log_card.dart';

/// My Logs tab — displays the worker's voice notes with LogCard.
/// Includes a record button hero and a realtime-fed list.
class MyLogsTab extends StatefulWidget {
  final String accountId;

  const MyLogsTab({super.key, required this.accountId});

  @override
  State<MyLogsTab> createState() => _MyLogsTabState();
}

class _MyLogsTabState extends State<MyLogsTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  bool _isRecording = false;
  bool _isUploading = false;

  Future<void> _handleRecording() async {
    final hasPermission = await _recorderService.checkPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    if (!_isRecording) {
      await _recorderService.startRecording();
      setState(() => _isRecording = true);
    } else {
      setState(() {
        _isRecording = false;
        _isUploading = true;
      });

      try {
        final audioBytes = await _recorderService.stopRecording();
        if (audioBytes != null) {
          final user = _supabase.auth.currentUser;
          if (user != null) {
            final userData = await _supabase
                .from('users')
                .select('current_project_id')
                .eq('id', user.id)
                .single();

            final projectId = userData['current_project_id'];
            if (projectId != null) {
              await _recorderService.uploadAudio(
                bytes: audioBytes,
                projectId: projectId,
                userId: user.id,
                accountId: widget.accountId,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice note submitted!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  /// Parses a voice_note map into the fields LogCard expects.
  _LogData _parseNote(Map<String, dynamic> note) {
    final transcription = note['transcript_final'] ??
        note['transcription'] ??
        note['transcript_en_current'] ??
        '';

    String englishText = transcription;
    String originalText = '';
    String languageCode = 'EN';
    String? translatedText;

    // Try to parse language markers: [Language] text\n\n[English] translation
    final pattern = RegExp(
      r'\[(.*?)\]\s*(.*?)(?:\n\n\[English\]\s*(.*))?$',
      dotAll: true,
    );
    final match = pattern.firstMatch(transcription);

    if (match != null) {
      languageCode = match.group(1) ?? 'EN';
      originalText = (match.group(2) ?? '').trim();
      final enText = (match.group(3) ?? '').trim();

      if (languageCode.toLowerCase() == 'english' ||
          languageCode.toLowerCase() == 'en') {
        englishText = originalText;
        originalText = '';
      } else {
        englishText = enText.isNotEmpty ? enText : originalText;
        translatedText = enText.isNotEmpty ? enText : null;
      }
    }

    return _LogData(
      englishText: englishText,
      originalText: originalText,
      languageCode: languageCode,
      translatedText: translatedText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Record hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          color: Colors.white,
          child: Column(
            children: [
              Text(
                _isUploading
                    ? 'Uploading note...'
                    : _isRecording
                        ? 'Recording... Tap to stop'
                        : 'Tap to Record Site Note',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isUploading ? null : _handleRecording,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor:
                      _isRecording ? Colors.red : const Color(0xFFFFCA28),
                  child: _isUploading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          _isRecording ? LucideIcons.square : LucideIcons.mic,
                          size: 32,
                          color: Colors.black,
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Logs list
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('voice_notes')
                .stream(primaryKey: ['id'])
                .eq('account_id', widget.accountId)
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1A237E),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.micOff, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No voice notes yet',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Tap the mic above to create your first note',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                );
              }

              final notes = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final note = notes[i];
                    final parsed = _parseNote(note);
                    return LogCard(
                      id: note['id'] ?? '',
                      englishText: parsed.englishText,
                      originalText: parsed.originalText,
                      languageCode: parsed.languageCode,
                      audioUrl: note['audio_url'] ?? '',
                      translatedText: parsed.translatedText,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LogData {
  final String englishText;
  final String originalText;
  final String languageCode;
  final String? translatedText;

  _LogData({
    required this.englishText,
    required this.originalText,
    required this.languageCode,
    this.translatedText,
  });
}
