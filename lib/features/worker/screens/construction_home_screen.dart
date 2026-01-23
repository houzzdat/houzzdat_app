import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'package:houzzdat_app/features/dashboard/widgets/voice_note_card.dart';

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
  String _userLanguage = 'en';
  bool _isInitializing = true; // ✅ ADD THIS

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
            .select('account_id, preferred_language')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _accountId = userData['account_id']?.toString();
            _userLanguage = userData['preferred_language'] ?? 'en';
            _isInitializing = false; // ✅ SET TO FALSE
          });
        }
      }
    } catch (e) {
      debugPrint("Context Error: $e");
      if (mounted) {
        setState(() => _isInitializing = false); // ✅ ALSO SET ON ERROR
      }
    }
  }

  void _playVoiceNote(String url) async {
    try {
      await _audioPlayer.play(UrlSource(url)); 
    } catch (e) {
      debugPrint("Playback Error: $e");
    }
  }

  Future<void> _handleRecording() async {
    bool hasPermission = await _recorderService.checkPermission();
    if (!hasPermission) return;

    if (!_isRecording) {
      await _recorderService.startRecording();
      setState(() => _isRecording = true);
    } else {
      setState(() => _isRecording = false);
      Uint8List? audioBytes = await _recorderService.stopRecording();

      if (audioBytes != null) {
        setState(() => _isUploading = true);
        try {
          final user = _supabase.auth.currentUser;
          final userData = await _supabase
              .from('users')
              .select('current_project_id, account_id')
              .eq('id', user!.id)
              .single();

          if (userData['current_project_id'] == null) throw "No project assigned";

          await _recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: userData['current_project_id'],
            userId: user.id,
            accountId: userData['account_id'],
          );
          
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note uploaded!')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        } finally {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
    // AuthWrapper will handle navigation automatically
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CRITICAL FIX: Show loading spinner until accountId is loaded
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

    // ✅ Now we can safely render the UI with a valid accountId
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
            child: Align(alignment: Alignment.centerLeft, child: Text("COMPANY FEED", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          ),
          Expanded(child: _buildLiveVoiceNotesList()),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      color: Colors.white,
      child: Column(
        children: [
          Text(_isUploading ? "Uploading..." : "Tap to Record Site Note", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isUploading ? null : _handleRecording,
            child: CircleAvatar(
              radius: 50, 
              backgroundColor: _isRecording ? Colors.red : const Color(0xFFFFC107),
              child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 40, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVoiceNotesList() {
    // ✅ accountId is guaranteed to be non-null here
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('voice_notes')
          .stream(primaryKey: ['id'])
          .eq('account_id', _accountId!) // ✅ Safe to use non-null assertion
          .order('created_at', ascending: false)
          .limit(10),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final notes = snapshot.data!;
            
        if (notes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No voice notes yet", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text("Tap the mic button above to create your first note", 
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, i) {
                return VoiceNoteCard(
                note: notes[i],
                isReplying: false, // Workers don't reply in this view
                onReply: () {}, // Empty callback for worker view
            );
           },
        );
      },
    );
  }
}