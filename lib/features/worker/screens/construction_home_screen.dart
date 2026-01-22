import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';

// Updated Import pointing to Core Service
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/auth/screens/login_screen.dart';

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
          });
        }
      }
    } catch (e) {
      debugPrint("Context Error: $e");
    }
  }

  // Resolves UUIDs into human-readable Email and Project names
  Future<Map<String, dynamic>> _fetchNoteDetails(Map<String, dynamic> note) async {
    try {
      final project = await _supabase.from('projects').select('name').eq('id', note['project_id']).single();
      final user = await _supabase.from('users').select('email').eq('id', note['user_id']).single();
      final createdAt = DateTime.tryParse(note['created_at'] ?? '') ?? DateTime.now();
      return {
        'email': user['email'] ?? 'Worker',
        'project_name': project['name'] ?? 'Site',
        'created_at': DateFormat('MMM d, h:mm a').format(createdAt),
      };
    } catch (e) {
      return {'email': 'Worker', 'project_name': 'Site', 'created_at': ''};
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
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('voice_notes')
          .stream(primaryKey: ['id'])
          .eq('account_id', _accountId ?? '')
          .order('created_at', ascending: false)
          .limit(10),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final notes = snapshot.data!;
            
        return ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, i) => FutureBuilder<Map<String, dynamic>>(
            future: _fetchNoteDetails(notes[i]),
            builder: (context, snap) {
              final d = snap.data ?? {'email': '...', 'project_name': '...', 'created_at': ''};
              
              // Handle Translations
              final translations = notes[i]['translated_transcription'];
              String displayText = notes[i]['transcription'] ?? '';
              
              if (translations != null && translations is Map && translations.containsKey(_userLanguage)) {
                displayText = translations[_userLanguage];
              }

              // Category Badge Logic
              final category = notes[i]['category'];
              Color? categoryColor;
              String? categoryText;

              if (category == 'action_required') {
                categoryColor = Colors.red[900];
                categoryText = '🔴 Action Required';
              } else if (category == 'approval') {
                categoryColor = Colors.orange[900];
                categoryText = '🟡 Approval Needed';
              } else if (category == 'update') {
                categoryColor = Colors.green[900];
                categoryText = '🟢 Update';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      if (categoryText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor!.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoryText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ),

                      ListTile(
                        leading: const Icon(Icons.mic, color: Color(0xFF1A237E)),
                        title: Text("${d['email']} - ${d['project_name']}"),
                        subtitle: Text(d['created_at']),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Colors.blue, size: 30),
                          onPressed: () => _playVoiceNote(notes[i]['audio_url']),
                        ),
                      ),

                      // Transcription Text
                      if (displayText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            displayText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                        )
                      else if (notes[i]['status'] == 'processing')
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text("Transcribing...", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}