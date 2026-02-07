import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Daily Tasks tab — shows tasks assigned to the current worker.
/// Fetches manager name via user_id join.
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
  final Set<String> _finishedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      // Fetch tasks assigned to this worker, with the creating user's name
      final data = await _supabase
          .from('action_items')
          .select('id, summary, status, category, user_id, voice_note_id, created_at, users!action_items_user_id_fkey(full_name, email)')
          .eq('account_id', widget.accountId)
          .eq('assigned_to', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        final tasks = (data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final completed = tasks
            .where((t) => t['status'] == 'completed')
            .map((t) => t['id'].toString())
            .toSet();

        setState(() {
          _tasks = tasks;
          _finishedIds.addAll(completed);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFinished(String taskId) async {
    final wasFinished = _finishedIds.contains(taskId);
    setState(() {
      if (wasFinished) {
        _finishedIds.remove(taskId);
      } else {
        _finishedIds.add(taskId);
      }
    });

    final newStatus = _finishedIds.contains(taskId) ? 'completed' : 'in_progress';
    try {
      final updateData = <String, dynamic>{'status': newStatus};
      if (newStatus == 'completed') {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('action_items').update(updateData).eq('id', taskId);
    } catch (e) {
      debugPrint('Error updating task: $e');
      // Revert on failure
      if (mounted) {
        setState(() {
          if (wasFinished) {
            _finishedIds.add(taskId);
          } else {
            _finishedIds.remove(taskId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update task')),
        );
      }
    }
  }

  IconData _getTaskTypeIcon(String? category, bool hasVoiceNote) {
    if (hasVoiceNote) return LucideIcons.mic;
    switch (category) {
      case 'action_required': return LucideIcons.alertTriangle;
      case 'approval': return LucideIcons.checkSquare;
      case 'update': return LucideIcons.info;
      default: return LucideIcons.fileText;
    }
  }

  String _getManagerName(Map<String, dynamic> task) {
    final userMap = task['users'];
    if (userMap is Map) {
      return userMap['full_name']?.toString() ?? userMap['email']?.toString() ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A237E)),
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
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final taskId = task['id'].toString();
          final isFinished = _finishedIds.contains(taskId);
          final title = task['summary'] ?? 'Untitled Task';
          final managerName = _getManagerName(task);
          final category = task['category']?.toString();
          final hasVoiceNote = task['voice_note_id'] != null;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Opacity(
              opacity: isFinished ? 0.6 : 1.0,
              child: Card(
                elevation: isFinished ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Task type icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isFinished
                              ? Colors.grey.shade200
                              : const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getTaskTypeIcon(category, hasVoiceNote),
                          size: 20,
                          color: isFinished
                              ? Colors.grey.shade400
                              : const Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Task title + manager name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isFinished
                                    ? Colors.grey.shade500
                                    : const Color(0xFF212121),
                                decoration: isFinished
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: Colors.grey.shade400,
                              ),
                            ),
                            if (managerName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                managerName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Mark as Finished / Reopen button
                      TextButton(
                        onPressed: () => _toggleFinished(taskId),
                        style: TextButton.styleFrom(
                          foregroundColor: isFinished
                              ? const Color(0xFFFFCA28)
                              : Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          isFinished ? 'Reopen' : 'Finished',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
