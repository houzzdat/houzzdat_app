import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/widgets/responsive_layout.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';
import 'package:houzzdat_app/features/owner/widgets/owner_approval_card.dart';
import 'package:houzzdat_app/features/finance/widgets/finance_charts.dart';
import 'package:houzzdat_app/features/documents/services/document_service.dart';
import 'package:houzzdat_app/features/documents/widgets/document_card.dart';
import 'package:houzzdat_app/features/documents/widgets/document_approval_dialog.dart';
import 'package:houzzdat_app/features/documents/screens/document_detail_screen.dart';
import 'package:houzzdat_app/models/models.dart';

class OwnerApprovalsTab extends StatefulWidget {
  final String ownerId;
  final String accountId;
  final VoidCallback? onApprovalChanged;

  const OwnerApprovalsTab({
    super.key,
    required this.ownerId,
    required this.accountId,
    this.onApprovalChanged,
  });

  @override
  State<OwnerApprovalsTab> createState() => _OwnerApprovalsTabState();
}

class _OwnerApprovalsTabState extends State<OwnerApprovalsTab>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin { // UX-audit #3: preserve tab state
  @override
  bool get wantKeepAlive => true; // UX-audit #3: preserve tab state

  late TabController _subTabController;
  final _supabase = Supabase.instance.client;
  final _docService = DocumentService();
  List<Map<String, dynamic>> _approvals = [];
  List<Document> _pendingDocs = [];
  bool _isLoading = true;
  bool _isLoadingDocs = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
    _subTabController.addListener(() {
      if (!_subTabController.indexIsChanging && _subTabController.index == 1) {
        _loadPendingDocs();
      }
    });
    _loadApprovals();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingDocs() async {
    setState(() => _isLoadingDocs = true);
    try {
      final docs = await _docService.getPendingApprovals(widget.accountId);
      if (mounted) setState(() { _pendingDocs = docs; _isLoadingDocs = false; });
    } catch (e) {
      debugPrint('Error loading pending docs: $e');
      if (mounted) setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);

    try {
      // UX-audit CI-05: single query with join instead of N+1 per-approval user lookups
      final result = await _supabase
          .from('owner_approvals')
          .select('*, projects(name), users!owner_approvals_requested_by_fkey(full_name, email)')
          .eq('owner_id', widget.ownerId)
          .order('created_at', ascending: false);

      final enriched = <Map<String, dynamic>>[];
      for (final approval in result) {
        final map = Map<String, dynamic>.from(approval);
        map['project_name'] = map['projects']?['name'] ?? '';
        // Extract requester name from joined users data
        final requester = map['users'];
        map['requested_by_name'] = requester?['full_name'] ?? requester?['email'] ?? 'Unknown';
        enriched.add(map);
      }

      if (mounted) {
        setState(() {
          _approvals = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading approvals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredApprovals {
    if (_filterStatus == 'all') return _approvals;
    return _approvals.where((a) => a['status'] == _filterStatus).toList();
  }

  // UX-audit #5: Optimistic UI — immediately update local state, rollback on error
  Future<void> _handleApprove(Map<String, dynamic> approval) async {
    HapticFeedback.mediumImpact(); // UX-audit #16: tactile feedback on approve
    final response = await _showResponseDialog('Approve this request?', 'Optional note for approval');
    if (response == null) return;

    // Optimistic update: immediately change status locally
    final oldStatus = approval['status'];
    final approvalIndex = _approvals.indexWhere((a) => a['id'] == approval['id']);
    if (approvalIndex >= 0) {
      setState(() {
        _approvals[approvalIndex] = {..._approvals[approvalIndex], 'status': 'approved'};
      });
    }

    try {
      await _supabase.from('owner_approvals').update({
        'status': 'approved',
        'owner_response': response.isNotEmpty ? response : null,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', approval['id']);

      if (approval['action_item_id'] != null) {
        await _recordActionItemInteraction(
          approval['action_item_id'],
          'owner_approved',
          'Owner approved: ${approval['title']}${response.isNotEmpty ? " - $response" : ""}',
        );
      }

      _loadApprovals(); // Refresh from server to ensure consistency
      widget.onApprovalChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      // Rollback optimistic update on error
      if (approvalIndex >= 0 && mounted) {
        setState(() {
          _approvals[approvalIndex] = {..._approvals[approvalIndex], 'status': oldStatus};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      debugPrint('Error approving: $e');
    }
  }

  // UX-audit #5: Optimistic UI for deny
  Future<void> _handleDeny(Map<String, dynamic> approval) async {
    HapticFeedback.mediumImpact(); // UX-audit #16: tactile feedback on deny
    final reason = await _showResponseDialog('Deny this request?', 'Reason for denial');
    if (reason == null) return;

    // Optimistic update
    final oldStatus = approval['status'];
    final approvalIndex = _approvals.indexWhere((a) => a['id'] == approval['id']);
    if (approvalIndex >= 0) {
      setState(() {
        _approvals[approvalIndex] = {..._approvals[approvalIndex], 'status': 'denied'};
      });
    }

    try {
      await _supabase.from('owner_approvals').update({
        'status': 'denied',
        'owner_response': reason.isNotEmpty ? reason : 'Denied by owner',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', approval['id']);

      if (approval['action_item_id'] != null) {
        await _recordActionItemInteraction(
          approval['action_item_id'],
          'owner_denied',
          'Owner denied: ${approval['title']}${reason.isNotEmpty ? " - $reason" : ""}',
        );
      }

      _loadApprovals();
      widget.onApprovalChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request denied'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      // Rollback optimistic update on error
      if (approvalIndex >= 0 && mounted) {
        setState(() {
          _approvals[approvalIndex] = {..._approvals[approvalIndex], 'status': oldStatus};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to deny. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      debugPrint('Error denying: $e');
    }
  }

  Future<void> _handleAddNote(Map<String, dynamic> approval) async {
    final note = await _showResponseDialog('Add a note', 'Your note');
    if (note == null || note.isEmpty) return;

    try {
      final existingResponse = approval['owner_response'] ?? '';
      final updatedResponse = existingResponse.isNotEmpty
          ? '$existingResponse\n---\n$note'
          : note;

      await _supabase.from('owner_approvals').update({
        'owner_response': updatedResponse,
      }).eq('id', approval['id']);

      _loadApprovals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note added'),
            backgroundColor: AppTheme.infoBlue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding note: $e');
    }
  }

  Future<void> _recordActionItemInteraction(
    String actionItemId,
    String action,
    String details,
  ) async {
    try {
      final result = await _supabase
          .from('action_items')
          .select('interaction_history')
          .eq('id', actionItemId)
          .maybeSingle();

      if (result == null) return;

      final history = List<Map<String, dynamic>>.from(
        (result['interaction_history'] as List?) ?? [],
      );

      history.add({
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': widget.ownerId,
        'action': action,
        'details': details,
      });

      await _supabase.from('action_items').update({
        'interaction_history': history,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', actionItemId);
    } catch (e) {
      debugPrint('Error recording interaction: $e');
    }
  }

  Future<String?> _showResponseDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // UX-audit #3: required by AutomaticKeepAliveClientMixin
    return Column(
      children: [
        // Sub-tabs: Spending | Documents
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _subTabController,
            labelColor: AppTheme.primaryIndigo,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryIndigo,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              const Tab(text: 'SPENDING'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('DOCUMENTS'),
                    if (_pendingDocs.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pendingDocs.length}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildSpendingTab(),
              _buildDocumentsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingTab() {
    if (_isLoading) {
      return const ShimmerLoadingList(itemCount: 4, itemHeight: 140); // UX-audit #4: shimmer instead of spinner
    }

    // PP-11: Shared filter chips row
    final filterChips = Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(label: 'All', value: 'all', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
            const SizedBox(width: AppTheme.spacingS),
            _FilterChip(label: 'Pending', value: 'pending', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
            const SizedBox(width: AppTheme.spacingS),
            _FilterChip(label: 'Approved', value: 'approved', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
            const SizedBox(width: AppTheme.spacingS),
            _FilterChip(label: 'Denied', value: 'denied', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
          ],
        ),
      ),
    );

    // PP-11: Shared approval list builder
    Widget buildApprovalList({bool includeChart = true}) {
      if (_filteredApprovals.isEmpty && _approvals.isEmpty) {
        return const EmptyStateWidget(
          icon: Icons.approval_outlined,
          title: 'No Pending Approvals',
          subtitle: 'You\'re all caught up. When your site manager needs your sign-off on spending, design, or schedule changes, they\'ll appear here.',
          // UX-audit #10: actionable empty state
          action: Text('Approvals will appear when your team submits requests', style: TextStyle(color: Color(0xFF616161), fontSize: 13)),
        );
      }

      final showChart = includeChart && _approvals.length > 1;
      return RefreshIndicator(
        onRefresh: _loadApprovals,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingXL),
          itemCount: _filteredApprovals.length + (showChart ? 1 : 0),
          itemBuilder: (context, index) {
            if (showChart && index == 0) {
              return ApprovalDistributionChart(approvals: _approvals);
            }
            final adjustedIndex = showChart ? index - 1 : index;
            if (adjustedIndex >= _filteredApprovals.length) {
              return const SizedBox.shrink();
            }
            final approval = _filteredApprovals[adjustedIndex];
            return OwnerApprovalCard(
              approval: approval,
              onApprove: () => _handleApprove(approval),
              onDeny: () => _handleDeny(approval),
              onAddNote: () => _handleAddNote(approval),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= Breakpoints.tablet;

        if (isTablet && _approvals.length > 1) {
          // PP-11: Tablet — chart on left, approval list on right
          return Column(
            children: [
              filterChips,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chart panel (left)
                    SizedBox(
                      width: constraints.maxWidth * 0.38,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: ApprovalDistributionChart(approvals: _approvals),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // List panel (right) — no embedded chart
                    Expanded(
                      child: buildApprovalList(includeChart: false),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Phone layout or few approvals
        return Column(
          children: [
            filterChips,
            Expanded(child: buildApprovalList()),
          ],
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    if (_isLoadingDocs) {
      return const ShimmerLoadingList(itemCount: 3, itemHeight: 100);
    }

    if (_pendingDocs.isEmpty) {
      return const EmptyStateWidget(
        icon: LucideIcons.folderCheck,
        title: 'No documents pending',
        subtitle: 'Documents awaiting your approval will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingDocs,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _pendingDocs.length,
        itemBuilder: (_, i) {
          final doc = _pendingDocs[i];
          return DocumentCard(
            document: doc,
            onTap: () async {
              final updated = await Navigator.push<bool>(
                context,
                FadeSlideRoute(
                  page: DocumentDetailScreen(document: doc, userRole: 'owner'),
                ),
              );
              if (updated == true) _loadPendingDocs();
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppTheme.primaryIndigo.withValues(alpha:0.2),
      checkmarkColor: AppTheme.primaryIndigo,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryIndigo : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
