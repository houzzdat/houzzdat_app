import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';
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

  Stream<List<Map<String, dynamic>>> _getActionsStream() {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return Stream.value([]);
    }
    
    return _supabase
        .from('action_items')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId!)
        .order('priority', ascending: false);
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
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
            backgroundColor: AppTheme.successGreen,
          ),
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
            const SizedBox(height: AppTheme.spacingM),
            Text('Forwarding to: ${toUser['email']}'),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop & Send'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () async {
                final bytes = await _recorderService.stopRecording();
                if (bytes != null) {
                  await _recorderService.uploadAudio(
                    bytes: bytes,
                    projectId: voiceNote['project_id'],
                    userId: _supabase.auth.currentUser!.id,
                    accountId: widget.accountId!,
                    recipientId: toUser['id'],
                  );

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
      setState(() {
        _isReplying = true;
        _replyToId = note['id'];
      });
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
        setState(() {
          _replyToId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getActionsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading actions...');
        }

        if (snap.hasError) {
          return ErrorStateWidget(
            message: snap.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        if (!snap.hasData || snap.data!.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.check_circle_outline,
            title: "No action items yet",
            subtitle: "Action items will appear here when team members record tasks",
          );
        }

        // Group by category
        final actions = snap.data!.where((a) => a['category'] == 'action_required').toList();
        final approvals = snap.data!.where((a) => a['category'] == 'approval').toList();
        final updates = snap.data!.where((a) => a['category'] == 'update').toList();

        return ListView(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          children: [
            if (actions.isNotEmpty) ...[
              _buildCategoryHeader('🔴 Action Required', AppTheme.errorRed, actions.length),
              ...actions.map((item) => ActionCardWidget(
                item: item,
                onApprove: () => _approveAction(item),
                onInstruct: () => _instructAction(item),
                onForward: () => _forwardAction(item),
              )),
              const SizedBox(height: AppTheme.spacingM),
            ],
            if (approvals.isNotEmpty) ...[
              _buildCategoryHeader('🟡 Pending Approval', AppTheme.warningOrange, approvals.length),
              ...approvals.map((item) => ActionCardWidget(
                item: item,
                onApprove: () => _approveAction(item),
                onInstruct: () => _instructAction(item),
                onForward: () => _forwardAction(item),
              )),
              const SizedBox(height: AppTheme.spacingM),
            ],
            if (updates.isNotEmpty) ...[
              _buildCategoryHeader('🟢 Updates', AppTheme.successGreen, updates.length),
              ...updates.map((item) => ActionCardWidget(
                item: item,
                onApprove: () => _approveAction(item),
                onInstruct: () => _instructAction(item),
                onForward: () => _forwardAction(item),
              )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCategoryHeader(String title, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingM,
      ),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTheme.headingSmall.copyWith(color: color),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: Text(
              '$count',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}