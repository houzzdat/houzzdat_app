import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';

/// Classic list view of actions for Manager Dashboard
/// Implements the SiteVoice Manager Action Lifecycle with filters, search, and sort
class ActionsTab extends StatefulWidget {
  final String accountId;

  const ActionsTab({super.key, required this.accountId});

  @override
  State<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<ActionsTab> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _actions = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _filterCategory = 'all';
  String _sortBy = 'newest';
  String _searchQuery = '';
  String? _expandedCardId;
  String? _selectedStatStatus; // For stats card click-to-filter

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

  List<Map<String, dynamic>> get _filteredAndSortedActions {
    var result = _actions.where((action) {
      // Updates are now ambient-only (Feed tab) — exclude from Actions
      if (action['category'] == 'update') return false;

      // Stats card filter takes priority when active
      final bool statusMatch;
      if (_selectedStatStatus != null) {
        statusMatch = action['status'] == _selectedStatStatus;
      } else {
        statusMatch = _filterStatus == 'all' ||
            action['status'] == _filterStatus;
      }

      // Support 'needs_review' as a virtual category filter
      final bool categoryMatch;
      if (_filterCategory == 'needs_review') {
        categoryMatch = action['needs_review'] == true &&
            action['review_status'] != 'confirmed';
      } else {
        categoryMatch = _filterCategory == 'all' ||
            action['category'] == _filterCategory;
      }

      // Search filter
      bool searchMatch = true;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final summary = (action['summary'] ?? '').toString().toLowerCase();
        final details = (action['details'] ?? '').toString().toLowerCase();
        final analysis = (action['ai_analysis'] ?? '').toString().toLowerCase();
        searchMatch = summary.contains(query) ||
            details.contains(query) ||
            analysis.contains(query);
      }

      return statusMatch && categoryMatch && searchMatch;
    }).toList();

    // Apply sorting
    switch (_sortBy) {
      case 'newest':
        result.sort((a, b) => _compareTimestamps(b, a, 'created_at'));
        break;
      case 'oldest':
        result.sort((a, b) => _compareTimestamps(a, b, 'created_at'));
        break;
      case 'priority_high':
        result.sort((a, b) => _comparePriority(a, b));
        break;
      case 'priority_low':
        result.sort((a, b) => _comparePriority(b, a));
        break;
      case 'recently_updated':
        result.sort((a, b) => _compareTimestamps(b, a, 'updated_at'));
        break;
    }

    return result;
  }

  int _compareTimestamps(
      Map<String, dynamic> a, Map<String, dynamic> b, String field) {
    final aTime = a[field]?.toString() ?? '';
    final bTime = b[field]?.toString() ?? '';
    return aTime.compareTo(bTime);
  }

  int _comparePriority(Map<String, dynamic> a, Map<String, dynamic> b) {
    const priorityOrder = {'High': 0, 'Med': 1, 'Low': 2};
    final aPriority = priorityOrder[a['priority']?.toString()] ?? 1;
    final bPriority = priorityOrder[b['priority']?.toString()] ?? 1;
    return aPriority.compareTo(bPriority);
  }

  @override
  Widget build(BuildContext context) {
    final filteredActions = _filteredAndSortedActions;

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingM, 0,
          ),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search actions...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.backgroundGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
            ),
          ),
        ),

        // Filter & Sort Bar
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
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: _buildFilterChip(
                  'Category',
                  _filterCategory,
                  [
                    ('all', 'All'),
                    ('approval', 'Approval'),
                    ('action_required', 'Action Required'),
                    ('needs_review', 'Needs Review'),
                  ],
                  (value) => setState(() => _filterCategory = value),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              // Sort button
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => _sortBy = value),
                tooltip: 'Sort',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryIndigo),
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                  child: const Icon(
                    Icons.sort,
                    color: AppTheme.primaryIndigo,
                    size: 20,
                  ),
                ),
                itemBuilder: (context) => [
                  _buildSortItem('newest', 'Newest First', Icons.arrow_downward),
                  _buildSortItem('oldest', 'Oldest First', Icons.arrow_upward),
                  _buildSortItem('priority_high', 'Priority: High → Low', Icons.priority_high),
                  _buildSortItem('priority_low', 'Priority: Low → High', Icons.low_priority),
                  _buildSortItem('recently_updated', 'Recently Updated', Icons.update),
                ],
              ),
            ],
          ),
        ),

        // Stats Bar — tappable cards with highlight effect
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          color: AppTheme.backgroundGrey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'PENDING',
                'pending',
                _actions.where((a) => a['status'] == 'pending').length,
                AppTheme.warningOrange,
              ),
              _buildStatCard(
                'IN PROGRESS',
                'in_progress',
                _actions.where((a) => a['status'] == 'in_progress').length,
                AppTheme.infoBlue,
              ),
              _buildStatCard(
                'VERIFYING',
                'verifying',
                _actions.where((a) => a['status'] == 'verifying').length,
                AppTheme.warningOrange,
              ),
              _buildStatCard(
                'COMPLETED',
                'completed',
                _actions.where((a) => a['status'] == 'completed').length,
                AppTheme.successGreen,
              ),
            ],
          ),
        ),

        // Results count when searching
        if (_searchQuery.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            color: AppTheme.infoBlue.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: AppTheme.infoBlue),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  '${filteredActions.length} result${filteredActions.length == 1 ? '' : 's'} for "$_searchQuery"',
                  style: const TextStyle(
                    color: AppTheme.infoBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
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
              : filteredActions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.inbox_outlined,
                            size: 64,
                            color: AppTheme.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching actions'
                                : 'No actions found',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try a different search term'
                                : 'Try changing your filters',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
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
                        itemCount: filteredActions.length,
                        itemBuilder: (context, index) {
                          return ActionCardWidget(
                            item: filteredActions[index],
                            onRefresh: _loadActions,
                            expandedCardId: _expandedCardId,
                            onExpandChanged: (id) =>
                                setState(() => _expandedCardId = id),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortItem(
      String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: _sortBy == value
                ? AppTheme.primaryIndigo
                : AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  _sortBy == value ? FontWeight.bold : FontWeight.normal,
              color: _sortBy == value
                  ? AppTheme.primaryIndigo
                  : AppTheme.textPrimary,
            ),
          ),
          if (_sortBy == value) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18, color: AppTheme.primaryIndigo),
          ],
        ],
      ),
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
            Expanded(
              child: Text(
                '$label: ${options.firstWhere((o) => o.$1 == currentValue).$2}',
                style: const TextStyle(
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppTheme.primaryIndigo,
              size: 18,
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

  Widget _buildStatCard(String label, String statusKey, int count, Color color) {
    final isSelected = _selectedStatStatus == statusKey;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedStatStatus == statusKey) {
            // Toggle off — remove filter
            _selectedStatStatus = null;
          } else {
            // Toggle on — filter by this status
            _selectedStatStatus = statusKey;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        transform: isSelected
            ? Matrix4.translationValues(0.0, -4.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _supabase.removeChannel(_supabase.channel('action_items_classic_changes'));
    super.dispose();
  }
}
