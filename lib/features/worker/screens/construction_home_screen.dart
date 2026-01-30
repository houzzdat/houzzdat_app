import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_card.dart';
import 'package:houzzdat_app/features/worker/models/voice_note_card_view_model.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

class ConstructionHomeScreen extends StatefulWidget {
  const ConstructionHomeScreen({super.key});

  @override
  State<ConstructionHomeScreen> createState() => _ConstructionHomeScreenState();
}

class _ConstructionHomeScreenState extends State<ConstructionHomeScreen> {
  final AudioRecorderService _recorderService = AudioRecorderService();
  final _supabase = Supabase.instance.client;
  
  bool _isRecording = false;
  bool _isUploading = false;
  String? _accountId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userData = await _supabase
            .from('users')
            .select('account_id')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _accountId = userData['account_id']?.toString();
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _handleRecording() async {
    bool hasPermission = await _recorderService.checkPermission();
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
        if (audioBytes != null && _accountId != null) {
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
                accountId: _accountId!,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Voice note submitted!'),
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

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
  }

  /// Creates a ViewModel from the note Map for display
  VoiceNoteCardViewModel _createViewModel(Map<String, dynamic> note) {
    // Parse transcription to extract original and translated text
    final transcription = note['transcription'] as String?;
    String originalTranscript = '';
    String? translatedTranscript;
    String languageLabel = 'EN';

    if (transcription != null && transcription.isNotEmpty) {
      // Check if transcription has language marker format: [Language] text
      final languagePattern = RegExp(r'\[(.*?)\]\s*(.*?)(?:\n\n\[English\]\s*(.*))?$', dotAll: true);
      final match = languagePattern.firstMatch(transcription);

      if (match != null) {
        languageLabel = match.group(1) ?? 'EN';
        originalTranscript = (match.group(2) ?? '').trim();
        translatedTranscript = (match.group(3) ?? '').trim();
        
        // If no translation but language is English, use original as both
        if (translatedTranscript?.isEmpty ?? true) {
          if (languageLabel.toLowerCase() == 'english') {
            translatedTranscript = null; // No need for translation
          }
        }
      } else {
        // No language marker, assume English
        originalTranscript = transcription;
        languageLabel = 'EN';
      }
    }

    return VoiceNoteCardViewModel(
      id: note['id'] ?? '',
      originalTranscript: originalTranscript,
      originalLanguageLabel: languageLabel,
      audioUrl: note['audio_url'] ?? '',
      translatedTranscript: translatedTranscript,
      isEditable: !(note['is_edited'] ?? false), // Not editable if already edited
      isProcessing: note['status'] == 'processing',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _accountId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: AppBar(
          title: const Text('SITE LOGS'),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1A237E)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: const Text('SITE LOGS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          )
        ],
      ),
      body: Column(
        children: [
          _buildHeroSection(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "COMPANY FEED",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Expanded(child: _buildVoiceNotesList()),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            _isUploading ? "Uploading note..." : "Tap to Record Site Note",
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isUploading ? null : _handleRecording,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: _isRecording ? Colors.red : const Color(0xFFFFC107),
              child: _isUploading 
                ? const CircularProgressIndicator(color: Colors.black)
                : Icon(_isRecording ? Icons.stop : Icons.mic, size: 40, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNotesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('voice_notes')
          .stream(primaryKey: ['id'])
          .eq('account_id', _accountId!)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No voice notes yet",
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  "Tap the mic button above to create your first note",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final notes = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: notes.length,
          itemBuilder: (context, i) {
            return VoiceNoteCard(
              viewModel: _createViewModel(notes[i]),
              isReplying: false,
              onReply: () {
                // Worker screen doesn't support replies yet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reply feature coming soon!'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}