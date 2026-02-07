import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

class OwnerProjectDetail extends StatefulWidget {
  final Map<String, dynamic> project;
  final String ownerId;
  final String accountId;

  const OwnerProjectDetail({
    super.key,
    required this.project,
    required this.ownerId,
    required this.accountId,
  });

  @override
  State<OwnerProjectDetail> createState() => _OwnerProjectDetailState();
}

class _OwnerProjectDetailState extends State<OwnerProjectDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectName = widget.project['name'] ?? 'Project';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(projectName),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Summary'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Materials'),
            Tab(icon: Icon(Icons.design_services), text: 'Design Log'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Finance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(
            projectId: widget.project['id'],
            accountId: widget.accountId,
          ),
          _MaterialsTab(
            projectId: widget.project['id'],
          ),
          _DesignLogTab(
            projectId: widget.project['id'],
          ),
          _FinanceTab(
            projectId: widget.project['id'],
            ownerId: widget.ownerId,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SUMMARY TAB
// ============================================================
class _SummaryTab extends StatefulWidget {
  final String projectId;
  final String accountId;

  const _SummaryTab({required this.projectId, required this.accountId});

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  final _supabase = Supabase.instance.client;
  Map<String, int> _statusCounts = {};
  List<Map<String, dynamic>> _blockers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);

    try {
      final actionItems = await _supabase
          .from('action_items')
          .select('status, priority, summary, category')
          .eq('project_id', widget.projectId);

      final counts = <String, int>{};
      final blockers = <Map<String, dynamic>>[];

      for (final item in actionItems) {
        final status = item['status'] ?? 'pending';
        counts[status] = (counts[status] ?? 0) + 1;

        // High priority pending/in_progress items are blockers
        if ((status == 'pending' || status == 'in_progress') &&
            item['priority'] == 'High') {
          blockers.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _statusCounts = counts;
          _blockers = blockers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading summary: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading summary...');
    }

    final total = _statusCounts.values.fold(0, (a, b) => a + b);
    final pending = _statusCounts['pending'] ?? 0;
    final inProgress = (_statusCounts['in_progress'] ?? 0) +
        (_statusCounts['verifying'] ?? 0);
    final completed = _statusCounts['completed'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status overview cards
            Row(
              children: [
                _StatCard(label: 'Total', count: total, color: AppTheme.primaryIndigo),
                _StatCard(label: 'Pending', count: pending, color: AppTheme.warningOrange),
                _StatCard(label: 'Active', count: inProgress, color: AppTheme.infoBlue),
                _StatCard(label: 'Done', count: completed, color: AppTheme.successGreen),
              ],
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Progress bar
            if (total > 0) ...[
              Text('Completion', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingS),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                child: LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  backgroundColor: AppTheme.backgroundGrey,
                  color: AppTheme.successGreen,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                '${total > 0 ? (completed / total * 100).toStringAsFixed(0) : 0}% complete',
                style: AppTheme.caption,
              ),
              const SizedBox(height: AppTheme.spacingL),
            ],

            // Blockers section
            Text('Blockers', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingS),
            if (_blockers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: AppTheme.successGreen.withValues(alpha:0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.successGreen),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'No blockers',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.successGreen),
                    ),
                  ],
                ),
              )
            else
              ...(_blockers.map((blocker) => Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                    child: ListTile(
                      leading: const PriorityIndicator(priority: 'High'),
                      title: Text(
                        blocker['summary'] ?? 'Action item',
                        style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: CategoryBadge(
                        text: (blocker['category'] ?? '').toString().toUpperCase(),
                        color: blocker['category'] == 'action_required'
                            ? AppTheme.errorRed
                            : AppTheme.warningOrange,
                      ),
                    ),
                  ))),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            children: [
              Text(
                '$count',
                style: AppTheme.headingLarge.copyWith(color: color),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(label, style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MATERIALS TAB
// ============================================================
class _MaterialsTab extends StatelessWidget {
  final String projectId;

  const _MaterialsTab({required this.projectId});

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ordered': return AppTheme.infoBlue;
      case 'delivered': return AppTheme.warningOrange;
      case 'installed': return AppTheme.successGreen;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder(
      stream: supabase
          .from('material_specs')
          .stream(primaryKey: ['id'])
          .eq('project_id', projectId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading materials...');
        }

        final materials = snapshot.data ?? [];

        if (materials.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'No Materials',
            subtitle: 'Material specifications will appear here as they are recorded on site.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final m = materials[index];
            final status = m['status'] ?? 'planned';

            return Card(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m['material_name'] ?? 'Material',
                            style: AppTheme.headingSmall,
                          ),
                        ),
                        CategoryBadge(
                          text: status.toUpperCase(),
                          color: _getStatusColor(status),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    if (m['brand'] != null)
                      _DetailRow(label: 'Brand', value: m['brand']),
                    if (m['specification'] != null)
                      _DetailRow(label: 'Spec', value: m['specification']),
                    if (m['quantity'] != null)
                      _DetailRow(
                        label: 'Quantity',
                        value: '${m['quantity']} ${m['unit'] ?? ''}',
                      ),
                    if (m['unit_price'] != null)
                      _DetailRow(
                        label: 'Unit Price',
                        value: 'INR ${m['unit_price']}',
                      ),
                    if (m['vendor'] != null)
                      _DetailRow(label: 'Vendor', value: m['vendor']),
                    if (m['category'] != null)
                      _DetailRow(label: 'Category', value: m['category']),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppTheme.caption.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value, style: AppTheme.bodySmall)),
        ],
      ),
    );
  }
}

// ============================================================
// DESIGN LOG TAB
// ============================================================
class _DesignLogTab extends StatelessWidget {
  final String projectId;

  const _DesignLogTab({required this.projectId});

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved': return AppTheme.successGreen;
      case 'rejected': return AppTheme.errorRed;
      case 'implemented': return AppTheme.infoBlue;
      default: return AppTheme.warningOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder(
      stream: supabase
          .from('design_change_logs')
          .stream(primaryKey: ['id'])
          .eq('project_id', projectId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading design log...');
        }

        final changes = snapshot.data ?? [];

        if (changes.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.design_services_outlined,
            title: 'No Design Changes',
            subtitle: 'Design change proposals and approvals will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          itemCount: changes.length,
          itemBuilder: (context, index) {
            final change = changes[index];
            final status = change['status'] ?? 'proposed';

            return Card(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            change['title'] ?? 'Design Change',
                            style: AppTheme.headingSmall,
                          ),
                        ),
                        CategoryBadge(
                          text: status.toUpperCase(),
                          color: _getStatusColor(status),
                        ),
                      ],
                    ),
                    if (change['description'] != null) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        change['description'],
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                    if (change['before_spec'] != null ||
                        change['after_spec'] != null) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      const Divider(height: 1),
                      const SizedBox(height: AppTheme.spacingS),
                      if (change['before_spec'] != null)
                        _SpecBox(
                          label: 'Before',
                          content: change['before_spec'],
                          color: AppTheme.errorRed,
                        ),
                      if (change['after_spec'] != null)
                        _SpecBox(
                          label: 'After',
                          content: change['after_spec'],
                          color: AppTheme.successGreen,
                        ),
                    ],
                    if (change['reason'] != null) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      _DetailRow(label: 'Reason', value: change['reason']),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SpecBox extends StatelessWidget {
  final String label;
  final String content;
  final Color color;

  const _SpecBox({
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(content, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}

// ============================================================
// FINANCE TAB
// ============================================================
class _FinanceTab extends StatefulWidget {
  final String projectId;
  final String ownerId;

  const _FinanceTab({required this.projectId, required this.ownerId});

  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  double _totalApproved = 0;
  double _totalPending = 0;
  double _totalTransactions = 0;
  int _pendingCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    try {
      // Load approval spending totals
      final approvals = await _supabase
          .from('owner_approvals')
          .select('amount, status, category')
          .eq('project_id', widget.projectId)
          .eq('category', 'spending');

      double approved = 0;
      double pending = 0;
      int pendingC = 0;

      for (final a in approvals) {
        final amount = (a['amount'] as num?)?.toDouble() ?? 0;
        if (a['status'] == 'approved') {
          approved += amount;
        } else if (a['status'] == 'pending') {
          pending += amount;
          pendingC++;
        }
      }

      // Load finance transactions
      final transactions = await _supabase
          .from('finance_transactions')
          .select()
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false);

      double txTotal = 0;
      for (final t in transactions) {
        txTotal += (t['amount'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _totalApproved = approved;
          _totalPending = pending;
          _pendingCount = pendingC;
          _transactions = List<Map<String, dynamic>>.from(transactions);
          _totalTransactions = txTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading finance data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'purchase': return AppTheme.infoBlue;
      case 'labour_payment': return AppTheme.warningOrange;
      case 'petty_cash': return AppTheme.primaryIndigo;
      default: return AppTheme.textSecondary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'purchase': return 'Purchase';
      case 'labour_payment': return 'Labour';
      case 'petty_cash': return 'Petty Cash';
      default: return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading financial overview...');
    }

    return RefreshIndicator(
      onRefresh: _loadFinanceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards row
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.successGreen),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            'INR ${_totalApproved.toStringAsFixed(0)}',
                            style: AppTheme.headingMedium.copyWith(color: AppTheme.successGreen),
                          ),
                          Text('Approved', style: AppTheme.caption),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        children: [
                          const Icon(Icons.pending, color: AppTheme.warningOrange),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            'INR ${_totalPending.toStringAsFixed(0)}',
                            style: AppTheme.headingMedium.copyWith(color: AppTheme.warningOrange),
                          ),
                          Text('$_pendingCount Pending', style: AppTheme.caption),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingS),

            // Total recorded spend card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppTheme.primaryIndigo),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Recorded Spend', style: AppTheme.caption),
                          Text(
                            'INR ${_totalTransactions.toStringAsFixed(0)}',
                            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryIndigo),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_transactions.length} entries',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Transaction list header
            Text(
              'TRANSACTIONS',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

            if (_transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppTheme.spacingL),
                child: Center(
                  child: Text(
                    'No transactions recorded yet',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              ..._transactions.map((t) {
                final type = t['type'] ?? 'other';
                final amount = (t['amount'] as num?)?.toDouble() ?? 0;
                final currency = t['currency'] ?? 'INR';
                final item = t['item'] ?? t['description'] ?? 'Transaction';
                final vendor = t['vendor'];
                final verified = t['verified_by'] != null;
                final createdAt = DateTime.tryParse(t['created_at'] ?? '');

                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(type),
                      child: Icon(
                        type == 'purchase'
                            ? Icons.shopping_cart
                            : type == 'labour_payment'
                                ? Icons.engineering
                                : Icons.money,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CategoryBadge(
                              text: _getTypeLabel(type),
                              color: _getTypeColor(type),
                            ),
                            if (verified) ...[
                              const SizedBox(width: AppTheme.spacingS),
                              const CategoryBadge(
                                text: 'Verified',
                                color: AppTheme.successGreen,
                                icon: Icons.verified,
                              ),
                            ],
                          ],
                        ),
                        if (vendor != null) ...[
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            'Vendor: $vendor',
                            style: AppTheme.caption,
                          ),
                        ],
                        if (createdAt != null)
                          Text(
                            '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                            style: AppTheme.caption,
                          ),
                      ],
                    ),
                    trailing: Text(
                      '$currency ${amount.toStringAsFixed(0)}',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryIndigo,
                      ),
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
