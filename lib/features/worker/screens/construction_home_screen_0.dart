import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_card.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

class ConstructionHomeScreen extends StatefulWidget {
  const ConstructionHomeScreen({super.key});

  @override
  State<ConstructionHomeScreen> createState() => _ConstructionHomeScreenState();
}

class _ConstructionHomeScreenState extends State<ConstructionHomeScreen> {
  final AudioRecorderService _recorderService = AudioRecorderService();
  final _supabase = Supabase.instance.client;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isUploading = false;
  String? _accountId;
  String? _projectId;
  String _userLanguage = 'en';
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
            .select('account_id, current_project_id, preferred_language')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _accountId = userData['account_id']?.toString();
            _projectId = userData['current_project_id']?.toString();
            _userLanguage = userData['preferred_language'] ?? 'en';
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Context Error: $e");
      if (mounted) {
        setState(() => _isInitializing = false);
      }
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
      // Start recording
      await _recorderService.startRecording();
      setState(() => _isRecording = true);
    } else {
      // Stop recording and upload
      setState(() {
        _isRecording = false;
        _isUploading = true;
      });
      
      try {
        Uint8List? audioBytes = await _recorderService.stopRecording();

        if (audioBytes != null && _projectId != null && _accountId != null) {
          // Upload audio directly - transcription happens automatically via database trigger
          final audioUrl = await _recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: _projectId!,
            userId: _supabase.auth.currentUser!.id,
            accountId: _accountId!,
          );

          if (audioUrl != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Voice note submitted! Processing transcription...'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (_projectId == null || _accountId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile error: Missing project or account data.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _accountId == null || _accountId!.isEmpty) {
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
            onPressed: _handleLogout
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
                  color: Colors.grey
                )
              )
            ),
          ),
          Expanded(child: _buildLiveVoiceNotesList()),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    String statusText;
    if (_isUploading) {
      statusText = "Processing...";
    } else if (_isRecording) {
      statusText = "Recording... Tap to stop";
    } else {
      statusText = "Tap to Record Site Note";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            statusText, 
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isUploading ? null : _handleRecording,
            child: CircleAvatar(
              radius: 50, 
              backgroundColor: _isRecording 
                ? Colors.red 
                : (_isUploading ? Colors.grey : const Color(0xFFFFC107)),
              child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : Icon(
                    _isRecording ? Icons.stop : Icons.mic, 
                    size: 40, 
                    color: Colors.black
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVoiceNotesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('voice_notes')
          .stream(primaryKey: ['id'])
          .eq('account_id', _accountId!)
          .order('created_at', ascending: false)
          .limit(20),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final notes = snapshot.data!;
            
        if (notes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No voice notes yet", 
                  style: TextStyle(color: Colors.grey)
                ),
                SizedBox(height: 8),
                Text(
                  "Tap the mic button above to create your first note", 
                  style: TextStyle(color: Colors.grey, fontSize: 12)
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, i) {
            return VoiceNoteCard(
              note: notes[i],
              isReplying: false,
              onReply: () {},
            );
          },
        );
      },
    );
  }
}