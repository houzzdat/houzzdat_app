import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Daily Tasks tab — shows tasks assigned to the worker.
/// Mark as Finished: strike-through title, reduce opacity, toggle to Reopen.
class DailyTasksTab extends StatefulWidget {
  final String accountId;

  const DailyTasksTab({super.key, required this.accountId});

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
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('action_items')
          .select('id, summary, status, category, assigned_to, created_at')
          .eq('account_id', widget.accountId)
          .order('created_at', ascending: false);

      if (mounted) {
        final tasks = (data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        // Pre-mark completed ones
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

  void _toggleFinished(String taskId) {
    setState(() {
      if (_finishedIds.contains(taskId)) {
        _finishedIds.remove(taskId);
      } else {
        _finishedIds.add(taskId);
      }
    });

    // Update status on backend
    final newStatus = _finishedIds.contains(taskId) ? 'completed' : 'pending';
    _supabase.from('action_items').update({
      'status': newStatus,
    }).eq('id', taskId).then((_) {}).catchError((e) {
      debugPrint('Error updating task: $e');
    });
  }

  IconData _getTaskTypeIcon(String? category) {
    switch (category) {
      case 'voice':
      case 'audio':
        return LucideIcons.mic;
      default:
        return LucideIcons.fileText;
    }
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
          final manager = task['assigned_to'] ?? '';
          final category = task['category']?.toString();

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
                          _getTaskTypeIcon(category),
                          size: 20,
                          color: isFinished
                              ? Colors.grey.shade400
                              : const Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Task title + manager
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
                            if (manager.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                manager,
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
