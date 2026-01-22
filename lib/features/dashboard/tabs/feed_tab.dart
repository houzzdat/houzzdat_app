import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_player_card.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'dart:typed_data';

class FeedTab extends StatefulWidget {
  final String? accountId;
  const FeedTab({super.key, required this.accountId});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  
  // Filter State
  String? _selectedProjectId;
  String? _selectedUserId;
  DateTime? _selectedDate;

  // Threaded Reply State
  bool _isReplying = false;
  String? _replyToId;

  Future<Map<String, dynamic>> _fetchNoteDetails(Map<String, dynamic> note) async {
    try {
      final project = await _supabase.from('projects').select('name').eq('id', note['project_id']).single();
      final user = await _supabase.from('users').select('email').eq('id', note['user_id']).single();
      
      // Parse the UTC time from Supabase
      DateTime utcTime = DateTime.parse(note['created_at']);
    
      // Convert to IST (UTC + 5 hours, 30 minutes)
      DateTime istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
      
      return {
        'email': user['email'] ?? 'User',
        'project_name': project['name'] ?? 'Site',
        'created_at': DateFormat('MMM d, h:mm a').format(istTime),
      };
    } catch (e) {
      return {'email': 'User', 'project_name': 'Site', 'created_at': ''};
    }
  }

  void _handleReply(Map<String, dynamic> note) async {
    if (!_isReplying) {
      await _recorderService.startRecording();
      setState(() { _isReplying = true; _replyToId = note['id']; });
    } else {
      setState(() => _isReplying = false);
      Uint8List? bytes = await _recorderService.stopRecording();
      if (bytes != null) {
        await _recorderService.uploadAudio(
          bytes: bytes, 
          projectId: note['project_id'], 
          userId: _supabase.auth.currentUser!.id, 
          accountId: widget.accountId!,
          parentId: note['id'],
          recipientId: note['user_id'],
        );
        setState(() { _replyToId = null; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterHeader(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('voice_notes')
              .stream(primaryKey: ['id'])
              .eq('account_id', widget.accountId ?? '')
              .order('created_at', ascending: false),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              
              // Client-side filtering
              final notes = snap.data!.where((n) {
                if (_selectedProjectId != null && n['project_id'] != _selectedProjectId) return false;
                if (_selectedUserId != null && n['user_id'] != _selectedUserId) return false;
                if (_selectedDate != null) {
                  final noteDate = DateTime.parse(n['created_at']);
                  if (noteDate.year != _selectedDate!.year ||
                      noteDate.month != _selectedDate!.month ||
                      noteDate.day != _selectedDate!.day) {
                    return false;
                  }
                }
                return true;
              }).toList();

              if (notes.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.voice_over_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No voice notes found", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: notes.length, 
                itemBuilder: (context, i) => FutureBuilder<Map<String, dynamic>>(
                  future: _fetchNoteDetails(notes[i]),
                  builder: (context, detailsSnap) {
                    if (!detailsSnap.hasData) return const SizedBox.shrink();
                    return Column(
                      children: [
                        VoiceNotePlayerCard(note: notes[i], details: detailsSnap.data!),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextButton.icon(
                            icon: Icon(
                              _replyToId == notes[i]['id'] ? Icons.stop : Icons.reply, 
                              color: Colors.blue
                            ),
                            label: Text(
                              _replyToId == notes[i]['id'] 
                                ? "Stop & Send Reply" 
                                : "Record Threaded Reply"
                            ),
                            onPressed: () => _handleReply(notes[i]),
                          ),
                        ),
                        const Divider(),
                      ],
                    );
                  },
                )
              );
            },
          )
        ),
      ],
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(12), 
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase.from('projects').select().eq('account_id', widget.accountId ?? ''),
                  builder: (context, snap) => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Filter by Site", 
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    value: _selectedProjectId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All Sites")),
                      ...?snap.data?.map((p) => DropdownMenuItem(
                        value: p['id'].toString(), 
                        child: Text(p['name'])
                      )),
                    ],
                    onChanged: (val) => setState(() => _selectedProjectId = val),
                  ),
                )
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase.from('users').select().eq('account_id', widget.accountId ?? ''),
                  builder: (context, snap) => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Filter by User", 
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    value: _selectedUserId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All Users")),
                      ...?snap.data?.map((u) => DropdownMenuItem(
                        value: u['id'].toString(), 
                        child: Text(u['email'] ?? 'User')
                      )),
                    ],
                    onChanged: (val) => setState(() => _selectedUserId = val),
                  ),
                )
              ),
            ]
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 16), 
                label: Text(
                  _selectedDate == null 
                    ? "All Dates" 
                    : DateFormat('yMMMd').format(_selectedDate!)
                ), 
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context, 
                    initialDate: DateTime.now(), 
                    firstDate: DateTime(2024), 
                    lastDate: DateTime.now()
                  );
                  setState(() => _selectedDate = date);
                }
              ),
              if (_selectedProjectId != null || _selectedUserId != null || _selectedDate != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text("Clear Filters"),
                  onPressed: () => setState(() { 
                    _selectedProjectId = null; 
                    _selectedUserId = null; 
                    _selectedDate = null; 
                  }),
                ),
            ]
          ),
        ]
      ),
    );
  }
}