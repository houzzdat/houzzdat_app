import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';
import 'package:houzzdat_app/features/dashboard/tabs/feed_tab.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/services/error_logging_service.dart';

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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin { // UX-audit TL-06: preserve tab state
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;
  RealtimeChannel? _channel; // UX-audit CI-12: store channel reference for proper cleanup

  @override
  bool get wantKeepAlive => true; // UX-audit TL-06

  static const _pageSize = 30;

  List<Map<String, dynamic>> _actions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _filterCategory = 'all';
  String _sortBy = 'newest';
  String _searchQuery = '';
  String? _expandedCardId;

  // UX-audit TL-14: Advanced filters
  String? _filterProjectId;      // null = all projects
  DateTimeRange? _filterDateRange;
  double _filterMinConfidence = 0.0; // 0.0 = no filter
  List<Map<String, dynamic>> _projects = []; // cached project list for filter dropdown

  // Bulk selection (#38)
  bool _isSelectMode = false;
  final Set<String> _selectedActionIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadActions();
    _loadProjects(); // UX-audit TL-14: load project list for filter dropdown
    _subscribeToChanges();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreActions();
    }
  }

  void _subscribeToChanges() {
    _channel = _supabase
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
          callback: (payload) => _handleRealtimeDelta(payload),
        );
    _channel!.subscribe(); // UX-audit CI-12: store reference, subscribe separately
  }

  /// UX-audit TL-05: Delta sync — apply insert/update/delete patches in-place
  /// instead of full list reload. Preserves scroll position and avoids UI flicker.
  void _handleRealtimeDelta(PostgresChangePayload payload) {
    if (!mounted) return;

    final eventType = payload.eventType;
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    setState(() {
      switch (eventType) {
        case PostgresChangeEvent.insert:
          if (newRecord.isNotEmpty) {
            final item = Map<String, dynamic>.from(newRecord);
            // Insert at the top (most recent)
            _actions.insert(0, item);
          }
          break;

        case PostgresChangeEvent.update:
          if (newRecord.isNotEmpty) {
            final updatedId = newRecord['id']?.toString();
            if (updatedId != null) {
              final index = _actions.indexWhere(
                (a) => a['id']?.toString() == updatedId,
              );
              if (index >= 0) {
                // Patch in-place — preserves list position
                _actions[index] = Map<String, dynamic>.from(newRecord);
              } else {
                // Item not in current page — could be from pagination.
                // Only add if it matches our account_id filter.
                final itemAccountId = newRecord['account_id']?.toString();
                if (itemAccountId == widget.accountId) {
                  _actions.insert(0, Map<String, dynamic>.from(newRecord));
                }
              }
            }
          }
          break;

        case PostgresChangeEvent.delete:
          final deletedId = oldRecord['id']?.toString();
          if (deletedId != null) {
            _actions.removeWhere((a) => a['id']?.toString() == deletedId);
          }
          break;

        default:
          // Fallback for unknown event types — do a full reload
          _loadActions();
          return;
      }
    });
  }

  Future<void> _loadActions() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
    });

    try {
      final data = await _supabase
          .from('action_items')
          .select('*')
          .eq('account_id', widget.accountId)
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _actions = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _hasMore = _actions.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ActionsTabState._loadActions');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreActions() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final offset = _actions.length;
      final data = await _supabase
          .from('action_items')
          .select('*')
          .eq('account_id', widget.accountId)
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final newItems = (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (mounted) {
        setState(() {
          _actions.addAll(newItems);
          _hasMore = newItems.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ActionsTabState._loadMoreActions');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// UX-audit TL-14: Load projects for the filter dropdown
  Future<void> _loadProjects() async {
    try {
      final data = await _supabase
          .from('projects')
          .select('id, name')
          .eq('account_id', widget.accountId)
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _projects = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ActionsTabState._loadProjects');
    }
  }

  // ─── Filtering & Sorting ────────────────────────────────────────

  /// Apply category filter, search, advanced filters, and sort to a list of actions.
  List<Map<String, dynamic>> _applyFiltersAndSort(List<Map<String, dynamic>> items) {
    var result = items.where((action) {
      // Category filter
      final bool categoryMatch;
      if (_filterCategory == 'needs_review') {
        // Derive from review_status alone — needs_review boolean is redundant
        final rs = action['review_status'] as String?;
        categoryMatch = rs == 'pending_review' || rs == 'flagged';
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

      // UX-audit TL-14: Project filter
      bool projectMatch = true;
      if (_filterProjectId != null) {
        projectMatch = action['project_id']?.toString() == _filterProjectId;
      }

      // UX-audit TL-14: Date range filter (on created_at)
      bool dateMatch = true;
      if (_filterDateRange != null) {
        final createdAt = action['created_at']?.toString();
        if (createdAt != null) {
          try {
            final dt = DateTime.parse(createdAt);
            dateMatch = !dt.isBefore(_filterDateRange!.start) &&
                !dt.isAfter(_filterDateRange!.end.add(const Duration(days: 1)));
          } catch (e) {
            dateMatch = true; // include if date is unparseable
          }
        }
      }

      // UX-audit TL-14: Confidence threshold filter
      bool confidenceMatch = true;
      if (_filterMinConfidence > 0.0) {
        final score = action['confidence_score'];
        final aiAnalysis = action['ai_analysis'];
        double? confidence;
        if (score != null) {
          confidence = double.tryParse(score.toString());
        } else if (aiAnalysis is Map && aiAnalysis['confidence_score'] != null) {
          confidence = double.tryParse(aiAnalysis['confidence_score'].toString());
        }
        // If no confidence data, include only when threshold is at minimum
        confidenceMatch = confidence != null
            ? confidence >= _filterMinConfidence
            : false;
      }

      return categoryMatch && searchMatch && projectMatch && dateMatch && confidenceMatch;
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
      _filterCategory != 'all' ||
      _sortBy != 'newest' ||
      _filterProjectId != null ||
      _filterDateRange != null ||
      _filterMinConfidence > 0.0;

  // ─── Bulk Actions (#38) ───────────────────────────────────────

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) _selectedActionIds.clear();
    });
  }

  void _toggleActionSelection(String id) {
    setState(() {
      if (_selectedActionIds.contains(id)) {
        _selectedActionIds.remove(id);
      } else {
        _selectedActionIds.add(id);
      }
    });
  }

  // UX-audit TL-02: Confirmation dialog for bulk operations
  // UX-audit TL-16: Undo support with 5-second cache of previous statuses
  Future<void> _bulkResolve() async {
    HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
    if (_selectedActionIds.isEmpty) return;

    final count = _selectedActionIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Resolve'),
        content: Text(
          'Resolve $count selected action${count == 1 ? '' : 's'} as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('Resolve $count'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Cache previous statuses for undo — UX-audit TL-16
    final previousStatuses = <String, String>{};
    for (final id in _selectedActionIds) {
      final item = _actions.firstWhere(
        (a) => a['id']?.toString() == id,
        orElse: () => <String, dynamic>{},
      );
      previousStatuses[id] = item['status']?.toString() ?? 'pending';
    }
    final affectedIds = Set<String>.from(_selectedActionIds);

    try {
      for (final id in affectedIds) {
        await _supabase.from('action_items').update({
          'status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      }
      setState(() {
        _selectedActionIds.clear();
        _isSelectMode = false;
      });
      _loadActions();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count actions resolved'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _undoBulkOperation(previousStatuses),
            ),
          ),
        );
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ActionsTabState._bulkResolve');
    }
  }

  // UX-audit TL-02: Confirmation dialog for bulk status update
  // UX-audit TL-16: Undo support
  Future<void> _bulkUpdateStatus(String status) async {
    HapticFeedback.mediumImpact(); // UX-audit #16: haptic feedback
    if (_selectedActionIds.isEmpty) return;

    final count = _selectedActionIds.length;
    final statusLabel = status.replaceAll('_', ' ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Update'),
        content: Text(
          'Update $count selected action${count == 1 ? '' : 's'} to "$statusLabel"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Update $count'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Cache previous statuses for undo — UX-audit TL-16
    final previousStatuses = <String, String>{};
    for (final id in _selectedActionIds) {
      final item = _actions.firstWhere(
        (a) => a['id']?.toString() == id,
        orElse: () => <String, dynamic>{},
      );
      previousStatuses[id] = item['status']?.toString() ?? 'pending';
    }
    final affectedIds = Set<String>.from(_selectedActionIds);

    try {
      for (final id in affectedIds) {
        await _supabase.from('action_items').update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      }
      setState(() {
        _selectedActionIds.clear();
        _isSelectMode = false;
      });
      _loadActions();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count actions updated to $statusLabel'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _undoBulkOperation(previousStatuses),
            ),
          ),
        );
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ActionsTabState._bulkUpdateStatus');
    }
  }

  /// UX-audit TL-16: Undo bulk operation by restoring previous statuses
  Future<void> _undoBulkOperation(Map<String, String> previousStatuses) async {
    try {
      for (final entry in previousStatuses.entries) {
        await _supabase.from('action_items').update({
          'status': entry.value,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', entry.key);
      }
      _loadActions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${previousStatuses.length} actions restored'),
            backgroundColor: AppTheme.infoBlue,
          ),
        );
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ActionsTabState._undoBulkOperation');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to undo. Please restore manually.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // UX-audit TL-14: allow taller sheet for advanced filters
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterBottomSheet(
        filterCategory: _filterCategory,
        sortBy: _sortBy,
        projects: _projects,
        filterProjectId: _filterProjectId,
        filterDateRange: _filterDateRange,
        filterMinConfidence: _filterMinConfidence,
        onApply: ({
          required String category,
          required String sort,
          String? projectId,
          DateTimeRange? dateRange,
          required double minConfidence,
        }) {
          setState(() {
            _filterCategory = category;
            _sortBy = sort;
            _filterProjectId = projectId;
            _filterDateRange = dateRange;
            _filterMinConfidence = minConfidence;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  /// Wrap a card widget with a checkbox when in select mode.
  Widget _wrapWithSelectMode(Map<String, dynamic> item, Widget cardWidget) {
    if (!_isSelectMode) return cardWidget;

    final id = item['id']?.toString() ?? '';
    final isSelected = _selectedActionIds.contains(id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 16),
          child: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleActionSelection(id),
            activeColor: AppTheme.primaryIndigo,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        Expanded(child: cardWidget),
      ],
    );
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // UX-audit TL-06: required for AutomaticKeepAliveClientMixin
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
          color: Theme.of(context).cardColor,
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
                          tooltip: 'Clear search', // UX-audit #21
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
              // Bulk select toggle (#38)
              IconButton(
                icon: Icon(
                  _isSelectMode ? Icons.close : Icons.checklist_rounded,
                  color: _isSelectMode ? AppTheme.errorRed : AppTheme.primaryIndigo,
                ),
                tooltip: _isSelectMode ? 'Cancel Selection' : 'Select Multiple',
                onPressed: _toggleSelectMode,
              ),
              // Feed shortcut icon
              IconButton(
                icon: const Icon(Icons.feed_rounded, color: AppTheme.primaryIndigo),
                tooltip: 'Voice Notes Feed',
                onPressed: () {
                  Navigator.of(context).push(
                    FadeSlideRoute(
                      page: Scaffold(
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

        // Bulk action bar (#38)
        if (_isSelectMode && _selectedActionIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
            child: Row(
              children: [
                Text(
                  '${_selectedActionIds.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryIndigo,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _bulkUpdateStatus('in_progress'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.infoBlue,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _bulkResolve,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Resolve'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.successGreen,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

        // Tab Bar: OPEN / IN-PROGRESS / COMPLETED
        Container(
          color: Theme.of(context).cardColor,
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
                fontSize: 12, // UX-audit TL-15: 11 → 12 for readability on high counts
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

    final mainItems = items
        .where((item) => !naIds.contains(item['id']))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadActions,
      child: ListView.builder(
        controller: _scrollController,
        cacheExtent: 500, // UX-audit #6: improved scroll perf
        padding: const EdgeInsets.only(
          top: AppTheme.spacingS,
          bottom: AppTheme.spacingXL,
        ),
        itemCount: tabNeedsAttention.length +
            (tabNeedsAttention.isNotEmpty ? 2 : 0) + // header + divider
            mainItems.length +
            (_isLoadingMore && _hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // "Needs Attention" header
          if (tabNeedsAttention.isNotEmpty) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 18, color: AppTheme.errorRed),
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
              );
            }
            // Needs-attention items
            if (index <= tabNeedsAttention.length) {
              final item = tabNeedsAttention[index - 1];
              return StaggeredListItem(
                index: index - 1,
                child: _wrapWithSelectMode(
                  item,
                  ActionCardWidget(
                    item: item,
                    onRefresh: _loadActions,
                    expandedCardId: _expandedCardId,
                    onExpandChanged: (id) =>
                        setState(() => _expandedCardId = id),
                  ),
                ),
              );
            }
            // Divider after needs-attention section
            if (index == tabNeedsAttention.length + 1) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Divider(),
              );
            }
          }

          // Main items offset
          final mainIndex = tabNeedsAttention.isNotEmpty
              ? index - tabNeedsAttention.length - 2
              : index;

          // Loading more indicator at the end
          if (mainIndex >= mainItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryIndigo,
                  ),
                ),
              ),
            );
          }

          // UX-audit #24: Staggered slide-in animation for main action list items.
          return StaggeredListItem(
            index: mainIndex,
            child: _wrapWithSelectMode(
              mainItems[mainIndex],
              ActionCardWidget(
                item: mainItems[mainIndex],
                onRefresh: _loadActions,
                expandedCardId: _expandedCardId,
                onExpandChanged: (id) =>
                    setState(() => _expandedCardId = id),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe(); // UX-audit CI-12: proper cleanup via stored reference
    super.dispose();
  }
}

// ─── Filter Bottom Sheet (Category + Sort + Advanced Filters) ─────────
// UX-audit TL-14: Extended with project dropdown, date range picker, confidence slider

class _FilterBottomSheet extends StatefulWidget {
  final String filterCategory;
  final String sortBy;
  final List<Map<String, dynamic>> projects;
  final String? filterProjectId;
  final DateTimeRange? filterDateRange;
  final double filterMinConfidence;
  final void Function({
    required String category,
    required String sort,
    String? projectId,
    DateTimeRange? dateRange,
    required double minConfidence,
  }) onApply;

  const _FilterBottomSheet({
    required this.filterCategory,
    required this.sortBy,
    required this.projects,
    this.filterProjectId,
    this.filterDateRange,
    required this.filterMinConfidence,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _category;
  late String _sort;
  String? _projectId;
  DateTimeRange? _dateRange;
  late double _minConfidence;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _category = widget.filterCategory;
    _sort = widget.sortBy;
    _projectId = widget.filterProjectId;
    _dateRange = widget.filterDateRange;
    _minConfidence = widget.filterMinConfidence;
    // Auto-expand if any advanced filter is active
    _showAdvanced = _projectId != null || _dateRange != null || _minConfidence > 0.0;
  }

  bool get _hasAdvancedFilters =>
      _projectId != null || _dateRange != null || _minConfidence > 0.0;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryIndigo,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPadding),
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

          const SizedBox(height: 16),

          // Advanced Filters toggle
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showAdvanced ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppTheme.primaryIndigo,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _hasAdvancedFilters ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                    ),
                  ),
                  if (_hasAdvancedFilters) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Advanced filter fields (collapsible)
          if (_showAdvanced) ...[
            const SizedBox(height: 12),

            // Project dropdown
            const Text('Project / Site', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _projectId,
                  isExpanded: true,
                  hint: const Text('All Projects', style: TextStyle(fontSize: 13)),
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Projects'),
                    ),
                    ...widget.projects.map((p) => DropdownMenuItem<String?>(
                      value: p['id']?.toString(),
                      child: Text(
                        p['name']?.toString() ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                  onChanged: (value) => setState(() => _projectId = value),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Date range picker
            const Text('Date Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 18, color: _dateRange != null ? AppTheme.primaryIndigo : AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _dateRange != null
                          ? '${DateFormat('d MMM yyyy').format(_dateRange!.start)} — ${DateFormat('d MMM yyyy').format(_dateRange!.end)}'
                          : 'All time',
                      style: TextStyle(
                        fontSize: 13,
                        color: _dateRange != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (_dateRange != null)
                      GestureDetector(
                        onTap: () => setState(() => _dateRange = null),
                        child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Confidence slider
            Row(
              children: [
                const Text('Min Confidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const Spacer(),
                Text(
                  _minConfidence > 0
                      ? '${(_minConfidence * 100).toInt()}%'
                      : 'Off',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _minConfidence > 0 ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryIndigo,
                inactiveTrackColor: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                thumbColor: AppTheme.primaryIndigo,
                overlayColor: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                trackHeight: 4,
              ),
              child: Slider(
                value: _minConfidence,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: _minConfidence > 0
                    ? '${(_minConfidence * 100).toInt()}%'
                    : 'Off',
                onChanged: (value) => setState(() => _minConfidence = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Off', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
                  Text('50%', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
                  Text('100%', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _category = 'all';
                    _sort = 'newest';
                    _projectId = null;
                    _dateRange = null;
                    _minConfidence = 0.0;
                  });
                },
                child: const Text('Reset All'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => widget.onApply(
                  category: _category,
                  sort: _sort,
                  projectId: _projectId,
                  dateRange: _dateRange,
                  minConfidence: _minConfidence,
                ),
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
