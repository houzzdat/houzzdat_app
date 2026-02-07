import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';

/// Kanban board with tabbed stages (Queue/Active/Logs)
/// Matches the design with swipeable tabs at the top
class ActionsKanbanTab extends StatefulWidget {
  final String accountId;

  const ActionsKanbanTab({super.key, required this.accountId});

  @override
  State<ActionsKanbanTab> createState() => _ActionsKanbanTabState();
}

class _ActionsKanbanTabState extends State<ActionsKanbanTab>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _queueActions = [];
  List<Map<String, dynamic>> _activeActions = [];
  List<Map<String, dynamic>> _logsActions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadActions();
    _subscribeToChanges();
  }

  void _subscribeToChanges() {
    _supabase
        .channel('action_items_kanban_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'action_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: widget.accountId,
          ),
          callback: (payload) => _loadActions(),
        )
        .subscribe();
  }

  Future<void> _loadActions() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await _supabase
          .from('action_items')
          .select('*')
          .eq('account_id', widget.accountId)
          .order('created_at', ascending: false);

      if (mounted) {
        final allActions = (data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          // QUEUE: pending items (new items awaiting action)
          _queueActions = allActions
              .where((item) => item['status'] == 'pending')
              .toList();
          
          // ACTIVE: in_progress and verifying (actively being worked on)
          _activeActions = allActions
              .where((item) => 
                  item['status'] == 'in_progress' || 
                  item['status'] == 'verifying')
              .toList();
          
          // LOGS: completed items (archived)
          _logsActions = allActions
              .where((item) => item['status'] == 'completed')
              .toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading actions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Tab Bar matching the design
        Container(
          color: AppTheme.primaryIndigo,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha:0.6),
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule, size: 20),
                    const SizedBox(width: 8),
                    const Text('QUEUE'),
                    const SizedBox(width: 8),
                    if (_queueActions.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_queueActions.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.build, size: 20),
                    const SizedBox(width: 8),
                    const Text('ACTIVE'),
                    const SizedBox(width: 8),
                    if (_activeActions.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_activeActions.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 20),
                    const SizedBox(width: 8),
                    const Text('LOGS'),
                    const SizedBox(width: 8),
                    if (_logsActions.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_logsActions.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryIndigo,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStageView(
                      _queueActions,
                      'QUEUE',
                      'New items awaiting manager action',
                      Icons.inbox_outlined,
                      AppTheme.warningOrange,
                    ),
                    _buildStageView(
                      _activeActions,
                      'ACTIVE',
                      'Currently being worked on',
                      Icons.trending_up,
                      AppTheme.infoBlue,
                    ),
                    _buildStageView(
                      _logsActions,
                      'LOGS',
                      'Completed and archived',
                      Icons.history,
                      AppTheme.successGreen,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStageView(
    List<Map<String, dynamic>> items,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: color.withValues(alpha:0.3),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No items in $title',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary.withValues(alpha:0.5),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha:0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingM,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
            ),
            child: ActionCardWidget(
              item: items[index],
              onRefresh: _loadActions,
              stageColor: color,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _supabase.removeChannel(_supabase.channel('action_items_kanban_changes'));
    super.dispose();
  }
}