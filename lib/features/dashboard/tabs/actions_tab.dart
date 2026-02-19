import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';
import 'package:houzzdat_app/features/dashboard/tabs/feed_tab.dart';

/// Classic list view of actions for Manager Dashboard with 3 sub-tabs:
/// OPEN (pending), IN-PROGRESS (in_progress + verifying), COMPLETED.
/// Includes search, category/sort filters, and "Needs Attention" section in Open tab.
class ActionsTab extends StatefulWidget {
  final String accountId;

  const ActionsTab({super.key, required this.accountId});

  @override
  State<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<ActionsTab>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _actions = [];
  bool _isLoading = true;
  String _filterCategory = 'all';
  String _sortBy = 'newest';
  String _searchQuery = '';
  String? _expandedCardId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  // ─── Filtering & Sorting ────────────────────────────────────────

  /// Apply category filter, search, and sort to a list of actions.
  List<Map<String, dynamic>> _applyFiltersAndSort(List<Map<String, dynamic>> items) {
    var result = items.where((action) {
      // Category filter
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

      return categoryMatch && searchMatch;
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

  /// All non-update actions (base set for tab splitting).
  List<Map<String, dynamic>> get _actionableItems =>
      _actions.where((a) => a['category'] != 'update').toList();

  /// OPEN tab: pending items (no manager action taken yet).
  List<Map<String, dynamic>> get _openActions =>
      _applyFiltersAndSort(
        _actionableItems.where((a) => a['status'] == 'pending').toList(),
      );

  /// IN-PROGRESS tab: items being worked on (in_progress + verifying).
  List<Map<String, dynamic>> get _inProgressActions =>
      _applyFiltersAndSort(
        _actionableItems.where((a) =>
            a['status'] == 'in_progress' || a['status'] == 'verifying').toList(),
      );

  /// COMPLETED tab: finished items.
  List<Map<String, dynamic>> get _completedActions =>
      _applyFiltersAndSort(
        _actionableItems.where((a) => a['status'] == 'completed').toList(),
      );

  /// Raw counts (before filters/search) for tab badges.
  int get _openCount =>
      _actionableItems.where((a) => a['status'] == 'pending').length;
  int get _inProgressCount =>
      _actionableItems.where((a) =>
          a['status'] == 'in_progress' || a['status'] == 'verifying').length;
  int get _completedCount =>
      _actionableItems.where((a) => a['status'] == 'completed').length;

  /// "Needs Attention" items: high/critical priority + pending, excluding updates.
  List<Map<String, dynamic>> get _needsAttentionItems {
    return _actionableItems.where((a) {
      final priority = a['priority']?.toString();
      final status = a['status']?.toString();
      return (priority == 'High' || priority == 'Critical') &&
          status == 'pending';
    }).toList()
      ..sort((a, b) => _comparePriority(a, b));
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

  bool get _hasActiveFilters =>
      _filterCategory != 'all' || _sortBy != 'newest';

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterBottomSheet(
        filterCategory: _filterCategory,
        sortBy: _sortBy,
        onApply: (category, sort) {
          setState(() {
            _filterCategory = category;
            _sortBy = sort;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final openActions = _openActions;
    final inProgressActions = _inProgressActions;
    final completedActions = _completedActions;
    final needsAttention = _needsAttentionItems;

    return Column(
      children: [
        // Search Bar + Filter chip + Feed shortcut
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingS,
          ),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(child: TextField(
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
              )),
              const SizedBox(width: AppTheme.spacingS),
              // Filter button with active indicator
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune, color: AppTheme.primaryIndigo),
                    tooltip: 'Filters & Sort',
                    onPressed: _showFilterBottomSheet,
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ),
                ],
              ),
              // Feed shortcut icon
              IconButton(
                icon: const Icon(Icons.feed_rounded, color: AppTheme.primaryIndigo),
                tooltip: 'Voice Notes Feed',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('VOICE NOTES FEED',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          backgroundColor: AppTheme.primaryIndigo,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        body: FeedTab(accountId: widget.accountId),
                      ),
                    ),
                  );
                },
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
                  '${openActions.length + inProgressActions.length + completedActions.length} result${(openActions.length + inProgressActions.length + completedActions.length) == 1 ? '' : 's'} for "$_searchQuery"',
                  style: const TextStyle(
                    color: AppTheme.infoBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Tab Bar: OPEN / IN-PROGRESS / COMPLETED
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryIndigo,
            indicatorWeight: 3,
            labelColor: AppTheme.primaryIndigo,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(child: _buildTabHeader('OPEN', _openCount, AppTheme.warningOrange)),
              Tab(child: _buildTabHeader('IN-PROGRESS', _inProgressCount, AppTheme.infoBlue)),
              Tab(child: _buildTabHeader('COMPLETED', _completedCount, AppTheme.successGreen)),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // Tab Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabContent(
                      items: openActions,
                      emptyTitle: 'No open actions',
                      emptySubtitle: 'New items will appear here',
                      emptyIcon: Icons.inbox_outlined,
                      emptyColor: AppTheme.warningOrange,
                      needsAttention: needsAttention,
                    ),
                    _buildTabContent(
                      items: inProgressActions,
                      emptyTitle: 'No items in progress',
                      emptySubtitle: 'Actions being worked on will appear here',
                      emptyIcon: Icons.trending_up,
                      emptyColor: AppTheme.infoBlue,
                    ),
                    _buildTabContent(
                      items: completedActions,
                      emptyTitle: 'No completed actions',
                      emptySubtitle: 'Finished items will appear here',
                      emptyIcon: Icons.check_circle_outline,
                      emptyColor: AppTheme.successGreen,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTabHeader(String label, int count, Color badgeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabContent({
    required List<Map<String, dynamic>> items,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required Color emptyColor,
    List<Map<String, dynamic>>? needsAttention,
  }) {
    if (items.isEmpty && (needsAttention == null || needsAttention.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : emptyIcon,
              size: 64,
              color: (_searchQuery.isNotEmpty ? AppTheme.textSecondary : emptyColor)
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              _searchQuery.isNotEmpty ? 'No matching actions' : emptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty ? 'Try a different search term' : emptySubtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Determine which needs-attention items are also in this tab's list
    final tabNeedsAttention = needsAttention != null && _searchQuery.isEmpty
        ? needsAttention.where((na) =>
            items.any((item) => item['id'] == na['id'])).toList()
        : <Map<String, dynamic>>[];
    // IDs of needs-attention items to avoid duplicates in main list
    final naIds = tabNeedsAttention.map((na) => na['id']).toSet();

    return RefreshIndicator(
      onRefresh: _loadActions,
      child: ListView(
        padding: const EdgeInsets.only(
          top: AppTheme.spacingS,
          bottom: AppTheme.spacingXL,
        ),
        children: [
          // "Needs Attention" section (only in Open tab)
          if (tabNeedsAttention.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 18, color: AppTheme.errorRed),
                  const SizedBox(width: 6),
                  Text(
                    'NEEDS ATTENTION (${tabNeedsAttention.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorRed,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            ...tabNeedsAttention.map((item) => ActionCardWidget(
              item: item,
              onRefresh: _loadActions,
              expandedCardId: _expandedCardId,
              onExpandChanged: (id) =>
                  setState(() => _expandedCardId = id),
            )),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
          ],
          // Remaining items (excluding needs-attention dupes)
          ...items
              .where((item) => !naIds.contains(item['id']))
              .map((item) => ActionCardWidget(
                item: item,
                onRefresh: _loadActions,
                expandedCardId: _expandedCardId,
                onExpandChanged: (id) =>
                    setState(() => _expandedCardId = id),
              )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _supabase.removeChannel(_supabase.channel('action_items_classic_changes'));
    super.dispose();
  }
}

// ─── Filter Bottom Sheet (Category + Sort only) ─────────────────────

class _FilterBottomSheet extends StatefulWidget {
  final String filterCategory;
  final String sortBy;
  final void Function(String category, String sort) onApply;

  const _FilterBottomSheet({
    required this.filterCategory,
    required this.sortBy,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _category;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _category = widget.filterCategory;
    _sort = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
          const Text('FILTERS & SORT',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Category filter
          const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _categoryChip('all', 'All'),
              _categoryChip('approval', 'Approval'),
              _categoryChip('action_required', 'Action Required'),
              _categoryChip('needs_review', 'Needs Review'),
            ],
          ),

          const SizedBox(height: 16),

          // Sort
          const Text('Sort By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _sortChip('newest', 'Newest'),
              _sortChip('oldest', 'Oldest'),
              _sortChip('priority_high', 'Priority: High-Low'),
              _sortChip('recently_updated', 'Recently Updated'),
            ],
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _category = 'all';
                    _sort = 'newest';
                  });
                },
                child: const Text('Reset All'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => widget.onApply(_category, _sort),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String value, String label) {
    final isSelected = _category == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      )),
      selected: isSelected,
      selectedColor: AppTheme.primaryIndigo,
      onSelected: (_) => setState(() => _category = value),
    );
  }

  Widget _sortChip(String value, String label) {
    final isSelected = _sort == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      )),
      selected: isSelected,
      selectedColor: AppTheme.primaryIndigo,
      onSelected: (_) => setState(() => _sort = value),
    );
  }
}
