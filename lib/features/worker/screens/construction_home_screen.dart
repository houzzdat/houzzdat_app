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
    if (!hasPermission) return;

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
        final user = _supabase.auth.currentUser;
        
        if (audioBytes != null && user != null) {
          final userData = await _supabase
              .from('users')
              .select('current_project_id, account_id')
              .eq('id', user.id)
              .single();

          await _recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: userData['current_project_id'],
            userId: user.id,
            accountId: userData['account_id'],
          );
        }
      } catch (e) {
        debugPrint("Recording Error: $e");
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  VoiceNoteCardViewModel _createViewModel(Map<String, dynamic> note) {
    return VoiceNoteCardViewModel(
      id: note['id']?.toString() ?? '',
      originalTranscript: note['transcript']?.toString() ?? '',
      originalLanguageLabel: note['language']?.toString() ?? 'EN',
      audioUrl: note['audio_url']?.toString() ?? '',
      translatedTranscript: note['translated_transcript']?.toString(),
      isEditable: false,
      isProcessing: note['status']?.toString() == 'processing',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _accountId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: const Text('SITE LOGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _supabase.auth.signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          _buildHeroSection(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "COMPANY FEED",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12, letterSpacing: 0.5),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final notes = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: notes.length,
          itemBuilder: (context, i) => VoiceNoteCard(
            viewModel: _createViewModel(notes[i]),
          ),
        );
      },
    );
  }
}