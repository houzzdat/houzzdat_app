import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';

/// Classic list view of actions for Manager Dashboard
/// Implements the SiteVoice Manager Action Lifecycle with filters
class ActionsTab extends StatefulWidget {
  final String accountId;

  const ActionsTab({super.key, required this.accountId});

  @override
  State<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<ActionsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _actions = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadActions();
    _subscribeToChanges();
  }

  void _subscribeToChanges() {
    _supabase
        .channel('action_items_classic_changes')
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
        setState(() {
          _actions = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading actions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredActions {
    return _actions.where((action) {
      final statusMatch = _filterStatus == 'all' || 
          action['status'] == _filterStatus;
      final categoryMatch = _filterCategory == 'all' || 
          action['category'] == _filterCategory;
      return statusMatch && categoryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  'Status',
                  _filterStatus,
                  [
                    ('all', 'All'),
                    ('pending', 'Pending'),
                    ('in_progress', 'In Progress'),
                    ('verifying', 'Verifying'),
                    ('completed', 'Completed'),
                  ],
                  (value) => setState(() => _filterStatus = value),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildFilterChip(
                  'Category',
                  _filterCategory,
                  [
                    ('all', 'All'),
                    ('approval', 'Approval'),
                    ('action_required', 'Action Required'),
                    ('update', 'Update'),
                  ],
                  (value) => setState(() => _filterCategory = value),
                ),
              ),
            ],
          ),
        ),

        // Stats Bar
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          color: AppTheme.backgroundGrey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'PENDING',
                _actions.where((a) => a['status'] == 'pending').length,
                AppTheme.warningOrange,
              ),
              _buildStatCard(
                'IN PROGRESS',
                _actions.where((a) => a['status'] == 'in_progress').length,
                AppTheme.infoBlue,
              ),
              _buildStatCard(
                'VERIFYING',
                _actions.where((a) => a['status'] == 'verifying').length,
                AppTheme.warningOrange,
              ),
              _buildStatCard(
                'COMPLETED',
                _actions.where((a) => a['status'] == 'completed').length,
                AppTheme.successGreen,
              ),
            ],
          ),
        ),

        // Actions List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryIndigo,
                  ),
                )
              : _filteredActions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: AppTheme.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            'No actions found',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            'Try changing your filters',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadActions,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          top: AppTheme.spacingS,
                          bottom: AppTheme.spacingXL,
                        ),
                        itemCount: _filteredActions.length,
                        itemBuilder: (context, index) {
                          return ActionCardWidget(
                            item: _filteredActions[index],
                            onRefresh: _loadActions,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    String currentValue,
    List<(String, String)> options,
    Function(String) onChanged,
  ) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryIndigo),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label: ${options.firstWhere((o) => o.$1 == currentValue).$2}',
              style: const TextStyle(
                color: AppTheme.primaryIndigo,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppTheme.primaryIndigo,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem<String>(
              value: option.$1,
              child: Text(option.$2),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _supabase.removeChannel(_supabase.channel('action_items_classic_changes'));
    super.dispose();
  }
}