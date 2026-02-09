import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';

/// Daily Tasks tab — two-tier expandable action cards for worker tasks.
///
/// Shows action items assigned to the current worker with:
/// - Collapsed view: priority border, category badge, summary, sender, time, actions
/// - Expanded view: audio player, transcript, AI analysis
/// - Worker actions: ADD INFO (voice/text), COMPLETE / REOPEN
/// - Accordion behavior (max 1 expanded card at a time)
/// - Real-time Supabase subscription for live updates
class DailyTasksTab extends StatefulWidget {
  final String accountId;
  final String userId;

  const DailyTasksTab({super.key, required this.accountId, required this.userId});

  @override
  State<DailyTasksTab> createState() => _DailyTasksTabState();
}

class _DailyTasksTabState extends State<DailyTasksTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _expandedCardId;
  RealtimeChannel? _channel;

  // Cache voice note data loaded on expand
  final Map<String, Map<String, dynamic>> _voiceNoteCache = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ─── Realtime ────────────────────────────────────────────────

  void _subscribeToRealtime() {
    _channel = _supabase
        .channel('worker-tasks-${widget.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'action_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_to',
            value: widget.userId,
          ),
          callback: (payload) {
            if (mounted) _loadTasks();
          },
        )
        .subscribe();
  }

  // ─── Data Loading ────────────────────────────────────────────

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('action_items')
          .select('''
            id, summary, details, status, category, priority, user_id,
            voice_note_id, created_at, updated_at, confidence_score,
            ai_analysis, interaction_history, assigned_to,
            users!action_items_user_id_fkey(full_name, email)
          ''')
          .eq('account_id', widget.accountId)
          .eq('assigned_to', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _tasks = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Lazily load voice note data when a card is expanded.
  Future<void> _loadVoiceNote(String voiceNoteId) async {
    if (_voiceNoteCache.containsKey(voiceNoteId)) return;
    try {
      final note = await _supabase
          .from('voice_notes')
          .select('audio_url, transcript_final, transcription, transcript_en_current, transcript_raw_current, transcript_raw, detected_language_code, status')
          .eq('id', voiceNoteId)
          .maybeSingle();

      if (note != null && mounted) {
        setState(() => _voiceNoteCache[voiceNoteId] = note);
      }
    } catch (e) {
      debugPrint('Error loading voice note: $e');
    }
  }

  // ─── Actions ─────────────────────────────────────────────────

  Future<void> _handleComplete(Map<String, dynamic> task) async {
    final taskId = task['id'].toString();
    final currentStatus = task['status']?.toString() ?? 'pending';
    final isCompleted = currentStatus == 'completed';

    final newStatus = isCompleted ? 'in_progress' : 'completed';

    // Optimistic update
    setState(() {
      final idx = _tasks.indexWhere((t) => t['id'].toString() == taskId);
      if (idx != -1) _tasks[idx]['status'] = newStatus;
    });

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newStatus == 'completed') {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('action_items').update(updateData).eq('id', taskId);

      // Record interaction
      await _recordInteraction(task, isCompleted ? 'reopened' : 'completed',
          isCompleted ? 'Worker reopened the task' : 'Worker marked task as completed');
    } catch (e) {
      debugPrint('Error updating task: $e');
      // Revert on failure
      if (mounted) {
        setState(() {
          final idx = _tasks.indexWhere((t) => t['id'].toString() == taskId);
          if (idx != -1) _tasks[idx]['status'] = currentStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update task')),
        );
      }
    }
  }

  Future<void> _handleAddInfo(Map<String, dynamic> task) async {
    final result = await showModalBottomSheet<_AddInfoResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddInfoSheet(task: task, accountId: widget.accountId),
    );

    if (result == null) return;

    if (result.type == 'text' && result.text != null) {
      await _recordInteraction(task, 'info_added', result.text!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Information added'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } else if (result.type == 'voice' && result.success) {
      await _recordInteraction(task, 'voice_reply', 'Worker added voice information');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice note sent'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _recordInteraction(
      Map<String, dynamic> task, String action, String details) async {
    final taskId = task['id'].toString();
    final existing = task['interaction_history'];
    final history = existing is List
        ? List<Map<String, dynamic>>.from(existing)
        : <Map<String, dynamic>>[];

    history.add({
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': widget.userId,
      'action': action,
      'details': details,
    });

    try {
      await _supabase.from('action_items').update({
        'interaction_history': history,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);

      // Update local state
      if (mounted) {
        setState(() {
          final idx = _tasks.indexWhere((t) => t['id'].toString() == taskId);
          if (idx != -1) _tasks[idx]['interaction_history'] = history;
        });
      }
    } catch (e) {
      debugPrint('Error recording interaction: $e');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────

  String _getManagerName(Map<String, dynamic> task) {
    final userMap = task['users'];
    if (userMap is Map) {
      return userMap['full_name']?.toString() ?? userMap['email']?.toString() ?? '';
    }
    return '';
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'action_required': return AppTheme.errorRed;
      case 'approval': return AppTheme.warningOrange;
      case 'update': return AppTheme.successGreen;
      default: return AppTheme.infoBlue;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'Critical': return AppTheme.errorRed;
      case 'High': return AppTheme.warningOrange;
      case 'Med': return AppTheme.infoBlue;
      case 'Low': return AppTheme.textSecondary;
      default: return AppTheme.textSecondary;
    }
  }

  String _getCategoryLabel(String? category) {
    switch (category) {
      case 'action_required': return 'ACTION';
      case 'approval': return 'APPROVAL';
      case 'update': return 'UPDATE';
      default: return 'TASK';
    }
  }

  // ─── Card Builders ───────────────────────────────────────────

  Widget _buildActionBtn(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(Map<String, dynamic> task) {
    final isCompleted = task['status'] == 'completed';
    final category = task['category']?.toString();
    final priority = task['priority']?.toString();
    final hasVoiceNote = task['voice_note_id'] != null;
    final managerName = _getManagerName(task);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: Priority + Category + Voice icon + Time
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.textSecondary : _getPriorityColor(priority),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              if (priority != null && !isCompleted)
                Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getPriorityColor(priority),
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                _getCategoryLabel(category),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? AppTheme.textSecondary : _getCategoryColor(category),
                ),
              ),
              if (hasVoiceNote) ...[
                const SizedBox(width: 8),
                Icon(LucideIcons.mic, size: 14,
                    color: isCompleted ? AppTheme.textSecondary : AppTheme.primaryIndigo),
              ],
              const Spacer(),
              Text(_timeAgo(task['created_at']?.toString()),
                  style: AppTheme.caption),
            ],
          ),
          const SizedBox(height: 6),
          // Line 2: Summary
          Text(
            task['summary'] ?? 'Task',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
              decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          // Line 3: Manager + Status badge
          Row(
            children: [
              if (managerName.isNotEmpty) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryIndigo,
                  child: Text(
                    managerName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'From $managerName',
                    style: AppTheme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Expanded(child: SizedBox()),
              if (task['status'] != 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (task['status'] == 'completed'
                            ? AppTheme.successGreen
                            : AppTheme.infoBlue)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (task['status'] ?? '').toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: task['status'] == 'completed'
                          ? AppTheme.successGreen
                          : AppTheme.infoBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildActionRow(Map<String, dynamic> task) {
    final isCompleted = task['status'] == 'completed';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _buildActionBtn(
            'ADD INFO',
            AppTheme.infoBlue,
            () => _handleAddInfo(task),
          ),
          const SizedBox(width: 8),
          _buildActionBtn(
            isCompleted ? 'REOPEN' : 'COMPLETE',
            isCompleted ? AppTheme.warningOrange : AppTheme.successGreen,
            () => _handleComplete(task),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> task) {
    final voiceNoteId = task['voice_note_id']?.toString();
    final voiceNote = voiceNoteId != null ? _voiceNoteCache[voiceNoteId] : null;
    final aiAnalysis = task['ai_analysis'];
    final details = task['details']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),

        // Voice note audio + transcript
        if (voiceNoteId != null && voiceNote == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (voiceNote != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (voiceNote['audio_url'] != null)
                  VoiceNoteAudioPlayer(audioUrl: voiceNote['audio_url']),
                if (_getTranscript(voiceNote) != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGrey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRANSCRIPT',
                          style: AppTheme.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTranscript(voiceNote)!,
                          style: AppTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Details section
        if (details != null && details.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DETAILS',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(details, style: AppTheme.bodyMedium),
              ],
            ),
          ),
        ],

        // AI Analysis
        if (aiAnalysis != null && aiAnalysis.toString().isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppTheme.infoBlue),
                      const SizedBox(width: 6),
                      Text(
                        'AI Analysis',
                        style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.infoBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aiAnalysis.toString(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.infoBlue,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Interaction history (last 3)
        if (_hasInteractions(task)) _buildInteractionTrail(task),
      ],
    );
  }

  String? _getTranscript(Map<String, dynamic> voiceNote) {
    return voiceNote['transcript_final']?.toString() ??
        voiceNote['transcription']?.toString() ??
        voiceNote['transcript_en_current']?.toString() ??
        voiceNote['transcript_raw_current']?.toString() ??
        voiceNote['transcript_raw']?.toString();
  }

  bool _hasInteractions(Map<String, dynamic> task) {
    final history = task['interaction_history'];
    return history is List && history.isNotEmpty;
  }

  Widget _buildInteractionTrail(Map<String, dynamic> task) {
    final history = List<Map<String, dynamic>>.from(task['interaction_history'] as List);
    final recent = history.length > 3 ? history.sublist(history.length - 3) : history;

    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECENT ACTIVITY',
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ...recent.map((interaction) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        _getInteractionIcon(interaction['action']?.toString()),
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${(interaction['action'] ?? '').toString().toUpperCase()} \u2014 ${interaction['details'] ?? ''}',
                          style: AppTheme.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getInteractionIcon(String? action) {
    switch (action) {
      case 'completed': return Icons.check_circle;
      case 'reopened': return Icons.replay;
      case 'info_added': return Icons.note_add;
      case 'voice_reply': return Icons.mic;
      case 'created': return Icons.add_circle;
      case 'approved': return Icons.check;
      case 'instructed': return Icons.record_voice_over;
      default: return Icons.history;
    }
  }

  // ─── Main Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
      );
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.clipboardList, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No tasks assigned',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Tasks from your manager will appear here',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final taskId = task['id'].toString();
          final isExpanded = _expandedCardId == taskId;
          final isCompleted = task['status'] == 'completed';
          final catColor = _getCategoryColor(task['category']?.toString());

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: isExpanded ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.hardEdge,
            child: Opacity(
              opacity: isCompleted ? 0.7 : 1.0,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left priority/category border bar
                    Container(
                      width: 4,
                      color: isCompleted ? AppTheme.textSecondary : catColor,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Only the collapsed content is tappable for expand/collapse
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedCardId = null;
                                } else {
                                  _expandedCardId = taskId;
                                  // Lazy load voice note
                                  if (task['voice_note_id'] != null) {
                                    _loadVoiceNote(task['voice_note_id'].toString());
                                  }
                                }
                              });
                            },
                            child: _buildCollapsedContent(task),
                          ),
                          // Action buttons outside InkWell so taps aren't intercepted
                          _buildActionRow(task),
                          if (isExpanded) _buildExpandedContent(task),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Add Info Bottom Sheet ─────────────────────────────────────

class _AddInfoResult {
  final String type; // 'text' or 'voice'
  final String? text;
  final bool success;

  _AddInfoResult({required this.type, this.text, this.success = false});
}

class _AddInfoSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final String accountId;

  const _AddInfoSheet({required this.task, required this.accountId});

  @override
  State<_AddInfoSheet> createState() => _AddInfoSheetState();
}

class _AddInfoSheetState extends State<_AddInfoSheet> {
  final _textController = TextEditingController();
  final _recorder = AudioRecorderService();
  final _supabase = Supabase.instance.client;

  bool _isRecording = false;
  bool _isUploading = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
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
      _recordingDuration = Duration.zero;
      _error = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordingDuration = Duration(seconds: timer.tick));
      }
    });
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    final bytes = await _recorder.stopRecording();
    if (bytes == null) {
      if (mounted) setState(() => _isRecording = false);
      return;
    }

    setState(() {
      _isRecording = false;
      _isUploading = true;
    });

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final projectId = widget.task['project_id']?.toString();

      // Upload voice note as a reply linked to the original voice note
      final url = await _recorder.uploadAudio(
        bytes: bytes,
        projectId: projectId ?? '',
        userId: currentUser.id,
        accountId: widget.accountId,
        parentId: widget.task['voice_note_id']?.toString(),
        recipientId: widget.task['user_id']?.toString(),
      );

      if (url == null) throw Exception('Upload failed');

      if (mounted) {
        Navigator.pop(context, _AddInfoResult(type: 'voice', success: true));
      }
    } catch (e) {
      debugPrint('Error uploading voice info: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = 'Failed to send voice note';
        });
      }
    }
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, _AddInfoResult(type: 'text', text: text));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'ADD INFORMATION',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.task['summary'] ?? 'Task',
            style: AppTheme.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.errorRed),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryIndigo),
                    SizedBox(height: 12),
                    Text('Sending...', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else if (_isRecording)
            // Recording UI
            Column(
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.mic, size: 48, color: AppTheme.errorRed),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 8),
                const Text('Recording...', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _stopAndSend,
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text('Stop & Send', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            )
          else ...[
            // Text input
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your update or additional information...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                // Voice record button
                OutlinedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic, size: 18),
                  label: const Text('Record Voice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryIndigo,
                    side: const BorderSide(color: AppTheme.primaryIndigo),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                const Spacer(),
                // Send text button
                ElevatedButton(
                  onPressed: _submitText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: const Text('Send', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
