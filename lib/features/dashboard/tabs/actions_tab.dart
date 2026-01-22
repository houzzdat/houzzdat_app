import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'dart:typed_data';

class ActionsTab extends StatefulWidget {
  final String? accountId;
  const ActionsTab({super.key, required this.accountId});

  @override
  State<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<ActionsTab> {
  final _recorderService = AudioRecorderService();
  final _supabase = Supabase.instance.client;
  bool _isReplying = false;
  String? _replyToId;

  Future<void> _approveAction(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Action Item'),
        content: Text('Approve: "${item['summary']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('action_items').update({
        'status': 'approved',
        'approved_by': _supabase.auth.currentUser!.id,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Action approved!'),
            backgroundColor: Colors.green,
          )
        );
      }
    }
  }

  Future<void> _instructAction(Map<String, dynamic> item) async {
    final voiceNote = await _supabase
      .from('voice_notes')
      .select()
      .eq('id', item['voice_note_id'])
      .single();
    
    _handleReply(voiceNote);
  }

  Future<void> _forwardAction(Map<String, dynamic> item) async {
    final users = await _supabase
      .from('users')
      .select()
      .eq('account_id', widget.accountId ?? '')
      .neq('id', _supabase.auth.currentUser!.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forward to...'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user['email'][0].toUpperCase()),
                ),
                title: Text(user['email']),
                subtitle: Text(user['role'] ?? 'worker'),
                onTap: () {
                  Navigator.pop(context);
                  _forwardToUser(item, user);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _forwardToUser(Map<String, dynamic> item, Map<String, dynamic> toUser) async {
    final voiceNote = await _supabase
      .from('voice_notes')
      .select()
      .eq('id', item['voice_note_id'])
      .single();
    
    setState(() {
      _replyToId = voiceNote['id'];
      _isReplying = true;
    });
    
    await _recorderService.startRecording();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Recording Instruction...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Forwarding to: ${toUser['email']}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop & Send'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final bytes = await _recorderService.stopRecording();
                if (bytes != null) {
                  final instructionUrl = await _recorderService.uploadAudio(
                    bytes: bytes,
                    projectId: voiceNote['project_id'],
                    userId: _supabase.auth.currentUser!.id,
                    accountId: widget.accountId!,
                    recipientId: toUser['id'],
                  );
                  
                  if (instructionUrl != null) {
                    await _supabase.from('voice_note_forwards').insert({
                      'original_note_id': voiceNote['id'],
                      'forwarded_from': _supabase.auth.currentUser!.id,
                      'forwarded_to': toUser['id'],
                    });
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Forwarded to ${toUser['email']}')),
                      );
                    }
                  }
                }
                setState(() {
                  _isReplying = false;
                  _replyToId = null;
                });
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('action_items')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId ?? '')
        .order('priority', ascending: false),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        if (snap.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No action items yet", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        // Group by category
        final updates = snap.data!.where((a) => a['category'] == 'update').toList();
        final approvals = snap.data!.where((a) => a['category'] == 'approval').toList();
        final actions = snap.data!.where((a) => a['category'] == 'action_required').toList();
        
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (actions.isNotEmpty) ...[
              _buildCategoryHeader('🔴 Action Required', Colors.red, actions.length),
              ...actions.map((item) => _buildActionCard(item, Colors.red)),
              const SizedBox(height: 16),
            ],
            if (approvals.isNotEmpty) ...[
              _buildCategoryHeader('🟡 Pending Approval', Colors.orange, approvals.length),
              ...approvals.map((item) => _buildActionCard(item, Colors.orange)),
              const SizedBox(height: 16),
            ],
            if (updates.isNotEmpty) ...[
              _buildCategoryHeader('🟢 Updates', Colors.green, updates.length),
              ...updates.map((item) => _buildActionCard(item, Colors.green)),
            ],
          ],
        );
      }
    );
  }

  Widget _buildCategoryHeader(String title, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> item, Color categoryColor) {
    String priorityText = item['priority']?.toString() ?? 'Med';
    String priorityEmoji = priorityText == 'High' ? '🔴' : (priorityText == 'Med' ? '🟡' : '🟢');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: categoryColor,
              child: Text(
                priorityEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            title: Text(
              item['summary'] ?? 'Action Item',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priority: $priorityText',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item['ai_analysis'] != null && item['ai_analysis'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item['ai_analysis'], 
                      style: const TextStyle(fontSize: 12)
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${item['status'] ?? 'pending'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: item['status'] == 'approved' ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (item['status'] == 'pending')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 400) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _approveAction(item),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.mic, size: 18),
                          label: const Text('Instruct'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _instructAction(item),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.forward, size: 18),
                          label: const Text('Forward'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _forwardAction(item),
                        ),
                      ],
                    );
                  }
                  
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _approveAction(item),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.mic, size: 18),
                          label: const Text('Instruct', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _instructAction(item),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.forward, size: 18),
                          label: const Text('Forward', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _forwardAction(item),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}