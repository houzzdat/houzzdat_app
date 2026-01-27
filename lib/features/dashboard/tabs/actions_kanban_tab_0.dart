import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/dashboard/widgets/kanban_stage_toggle.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_kanban.dart';

enum KanbanStage { queue, active, logs }

class ActionsKanbanTab extends StatefulWidget {
  final String accountId;
  
  const ActionsKanbanTab({super.key, required this.accountId});

  @override
  State<ActionsKanbanTab> createState() => _ActionsKanbanTabState();
}

class _ActionsKanbanTabState extends State<ActionsKanbanTab> {
  final _supabase = Supabase.instance.client;
  KanbanStage _currentStage = KanbanStage.queue;

  Stream<List<Map<String, dynamic>>> _getActionsStream() {
    return _supabase
        .from('action_items')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId)
        .order('priority', ascending: false)
        .order('created_at', ascending: false);
  }

  List<Map<String, dynamic>> _filterByStage(List<Map<String, dynamic>> items) {
    switch (_currentStage) {
      case KanbanStage.queue:
        return items.where((item) {
          final status = item['status']?.toString() ?? 'pending';
          return status == 'pending' || status == 'validating';
        }).toList();
      
      case KanbanStage.active:
        return items.where((item) {
          final status = item['status']?.toString() ?? 'pending';
          return status == 'approved' || status == 'in_progress';
        }).toList();
      
      case KanbanStage.logs:
        return items.where((item) {
          final status = item['status']?.toString() ?? 'pending';
          return status == 'completed' || status == 'verified';
        }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Kanban Stage Toggle
        KanbanStageToggle(
          currentStage: _currentStage,
          onStageChanged: (stage) {
            setState(() => _currentStage = stage);
          },
        ),
        
        // Actions List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getActionsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingWidget(message: 'Loading actions...');
              }

              if (snapshot.hasError) {
                return ErrorStateWidget(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(() {}),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              // Filter by stage
              final filteredItems = _filterByStage(snapshot.data!);

              if (filteredItems.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  return ActionCardKanban(
                    item: filteredItems[index],
                    onApprove: () => _handleApprove(filteredItems[index]),
                    onViewDetails: () => _handleViewDetails(filteredItems[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String title;
    String subtitle;

    switch (_currentStage) {
      case KanbanStage.queue:
        icon = Icons.checklist_rounded;
        title = 'No items in queue';
        subtitle = 'New action items will appear here';
        break;
      case KanbanStage.active:
        icon = Icons.construction_rounded;
        title = 'No active items';
        subtitle = 'Approved items will appear here';
        break;
      case KanbanStage.logs:
        icon = Icons.check_circle_outline_rounded;
        title = 'No completed items';
        subtitle = 'Completed items will appear here';
        break;
    }

    return EmptyStateWidget(
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }

  Future<void> _handleApprove(Map<String, dynamic> item) async {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
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

  Future<void> _handleViewDetails(Map<String, dynamic> item) async {
    // Navigate to details view or expand card
    // Implementation depends on your routing strategy
  }
}