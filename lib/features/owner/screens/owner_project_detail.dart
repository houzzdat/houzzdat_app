import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/widgets/responsive_layout.dart';

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
    final location = (widget.project['location'] ?? '') as String;

    return Scaffold(
      appBar: AppBar(
        // Issue #16 fix: title + subtitle gives context; location as subtitle
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projectName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (location.isNotEmpty)
              Text(
                location,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              )
            else
              const Text(
                'Site Overview',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        // Issue #1 & #2 fix: text-only tabs, styled with amber indicator + white labels
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'SUMMARY'),
            Tab(text: 'MATERIALS'),
            Tab(text: 'DESIGN LOG'),
            Tab(text: 'FINANCE'),
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
      // Fetch all fields needed for rich blocker cards
      final actionItems = await _supabase
          .from('action_items')
          .select(
            'status, priority, summary, category, due_date, '
            'is_critical_flag, assigned_to, created_at, updated_at',
          )
          .eq('project_id', widget.projectId);

      final counts = <String, int>{};
      final blockers = <Map<String, dynamic>>[];

      for (final item in actionItems) {
        final status = item['status'] ?? 'pending';
        counts[status] = (counts[status] ?? 0) + 1;

        if ((status == 'pending' || status == 'in_progress') &&
            item['priority'] == 'High') {
          blockers.add(item);
        }
      }

      // Sort: critical-flagged first, then by due_date ascending (earliest first)
      blockers.sort((a, b) {
        final aCrit = (a['is_critical_flag'] == true) ? 0 : 1;
        final bCrit = (b['is_critical_flag'] == true) ? 0 : 1;
        if (aCrit != bCrit) return aCrit.compareTo(bCrit);
        final aDate = DateTime.tryParse(a['due_date'] ?? '');
        final bDate = DateTime.tryParse(b['due_date'] ?? '');
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

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
    // Issue #3 fix: shimmer instead of spinner
    if (_isLoading) return const ShimmerLoadingList(itemCount: 4, itemHeight: 80);

    final total = _statusCounts.values.fold(0, (a, b) => a + b);
    final pending = _statusCounts['pending'] ?? 0;
    final inProgress = (_statusCounts['in_progress'] ?? 0) +
        (_statusCounts['verifying'] ?? 0);
    final completed = _statusCounts['completed'] ?? 0;
    final completionPct = total > 0 ? (completed / total) : 0.0;

    return ContentConstraint(
      maxContentWidth: 1000,
      child: RefreshIndicator(
        onRefresh: _loadSummary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Issue #7 & #17 fix: stat cards with visual hierarchy + proper padding
              Row(
                children: [
                  _StatCard(label: 'Total', count: total, color: AppTheme.primaryIndigo, isPrimary: true),
                  _StatCard(label: 'Pending', count: pending, color: AppTheme.warningOrange, isPrimary: false),
                  _StatCard(label: 'Active', count: inProgress, color: AppTheme.infoBlue, isPrimary: false),
                  _StatCard(label: 'Done', count: completed, color: AppTheme.successGreen, isPrimary: false),
                ],
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Completion progress
              if (total > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Completion', style: AppTheme.headingSmall),
                    Text(
                      '${(completionPct * 100).toStringAsFixed(0)}%',
                      style: AppTheme.headingSmall.copyWith(color: AppTheme.successGreen),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                // Issue #8 fix: use Theme.of(context) colour — works in dark mode
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  child: LinearProgressIndicator(
                    value: completionPct,
                    backgroundColor: Theme.of(context).dividerColor,
                    color: AppTheme.successGreen,
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],

              // Blockers section
              if (_blockers.isEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 18),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'No blockers — all clear',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.successGreen),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Blockers', style: AppTheme.headingSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_blockers.length}',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                ...(_blockers.map((b) => _BlockerCard(blocker: b))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isPrimary;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    // Issue #7 fix: "Total" card has slightly larger number to signal hierarchy
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingM,
            horizontal: AppTheme.spacingXS,
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: (isPrimary ? AppTheme.headingLarge : AppTheme.headingMedium)
                    .copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                label,
                style: AppTheme.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BLOCKER CARD
// ============================================================
class _BlockerCard extends StatelessWidget {
  final Map<String, dynamic> blocker;

  const _BlockerCard({required this.blocker});

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'action_required': return AppTheme.errorRed;
      case 'safety':          return AppTheme.errorRed;
      case 'quality':         return AppTheme.warningOrange;
      case 'delay':           return AppTheme.warningOrange;
      default:                return AppTheme.warningOrange;
    }
  }

  String _categoryLabel(String? cat) {
    if (cat == null || cat.isEmpty) return 'BLOCKER';
    return cat.replaceAll('_', ' ').toUpperCase();
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'in_progress': return 'In Progress';
      case 'verifying':   return 'Verifying';
      default:            return 'Pending';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'in_progress': return AppTheme.infoBlue;
      case 'verifying':   return AppTheme.primaryIndigo;
      default:            return AppTheme.warningOrange;
    }
  }

  /// Returns "X days overdue", "Due today", "Due in X days", or null.
  String? _dueDateLabel(String? rawDate) {
    if (rawDate == null) return null;
    final due = DateTime.tryParse(rawDate);
    if (due == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;
    if (diff < 0)  return '${diff.abs()} day${diff.abs() == 1 ? '' : 's'} overdue';
    if (diff == 0) return 'Due today';
    return 'Due in $diff day${diff == 1 ? '' : 's'}';
  }

  bool _isOverdue(String? rawDate) {
    if (rawDate == null) return false;
    final due = DateTime.tryParse(rawDate);
    if (due == null) return false;
    return DateTime(due.year, due.month, due.day)
        .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
  }

  /// How long ago the blocker was logged.
  String _openSince(String? rawDate) {
    if (rawDate == null) return '';
    final created = DateTime.tryParse(rawDate);
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inDays >= 1) return 'Open ${diff.inDays}d';
    if (diff.inHours >= 1) return 'Open ${diff.inHours}h';
    return 'Just logged';
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = blocker['is_critical_flag'] == true;
    final status     = blocker['status'] as String?;
    final category   = blocker['category'] as String?;
    final dueRaw     = blocker['due_date'] as String?;
    final createdRaw = blocker['created_at'] as String?;
    final summary    = (blocker['summary'] ?? 'Action item') as String;
    final assignedTo = blocker['assigned_to'] as String?;

    final accentColor = isCritical ? AppTheme.errorRed : _categoryColor(category);
    final dueLbl      = _dueDateLabel(dueRaw);
    final overdue     = _isOverdue(dueRaw);
    final openSince   = _openSince(createdRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: accentColor.withValues(alpha: isCritical ? 0.5 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(width: 4, color: accentColor),

              // Card body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row: critical badge + status pill + open-since ──
                      Row(
                        children: [
                          if (isCritical) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_rounded,
                                      color: Colors.white, size: 11),
                                  SizedBox(width: 3),
                                  Text(
                                    'CRITICAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                          ],
                          // Category pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _categoryLabel(category),
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Status pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ── Summary text ──
                      Text(
                        summary,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Bottom row: due date + open-since + assigned ──
                      Row(
                        children: [
                          // Due date chip
                          if (dueLbl != null) ...[
                            Icon(
                              overdue ? Icons.alarm : Icons.calendar_today_outlined,
                              size: 12,
                              color: overdue ? AppTheme.errorRed : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueLbl,
                              style: AppTheme.caption.copyWith(
                                color: overdue ? AppTheme.errorRed : AppTheme.textSecondary,
                                fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                          ],
                          // Open since
                          if (openSince.isNotEmpty) ...[
                            Icon(Icons.access_time_outlined,
                                size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(openSince, style: AppTheme.caption),
                          ],
                          const Spacer(),
                          // Assigned-to avatar/label
                          if (assignedTo != null && assignedTo.isNotEmpty) ...[
                            const Icon(Icons.person_outline,
                                size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              assignedTo,
                              style: AppTheme.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
class _MaterialsTab extends StatefulWidget {
  final String projectId;

  const _MaterialsTab({required this.projectId});

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ordered':   return AppTheme.infoBlue;
      case 'delivered': return AppTheme.warningOrange;
      case 'installed': return AppTheme.successGreen;
      default:          return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return StreamBuilder(
      stream: supabase
          .from('material_specs')
          .stream(primaryKey: ['id'])
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        // Issue #4 fix: shimmer while waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerLoadingList(itemCount: 5, itemHeight: 110);
        }

        final materials = snapshot.data ?? [];

        if (materials.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'No Materials',
            subtitle: 'Material specifications will appear here as they are recorded on site.',
          );
        }

        // Issue #13 fix: compute cost summary
        double totalCost = 0;
        final statusTotals = <String, int>{'ordered': 0, 'delivered': 0, 'installed': 0};
        for (final m in materials) {
          final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
          final unitPrice = (m['unit_price'] as num?)?.toDouble() ?? 0;
          totalCost += qty * unitPrice;
          final st = m['status']?.toString() ?? '';
          if (statusTotals.containsKey(st)) statusTotals[st] = statusTotals[st]! + 1;
        }

        // Issue #6 fix: RefreshIndicator wraps the scrollable content
        return RefreshIndicator(
          onRefresh: () async {
            // StreamBuilder auto-updates; trigger a UI rebuild hint
            if (mounted) setState(() {});
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Issue #13 fix: cost summary header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingM, AppTheme.spacingM,
                    AppTheme.spacingM, AppTheme.spacingS,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Material Cost', style: AppTheme.caption),
                              Text(
                                currencyFmt.format(totalCost),
                                style: AppTheme.headingMedium.copyWith(
                                  color: AppTheme.primaryIndigo,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              _StatusPill('Ordered', statusTotals['ordered']!, AppTheme.infoBlue),
                              const SizedBox(width: AppTheme.spacingS),
                              _StatusPill('Delivered', statusTotals['delivered']!, AppTheme.warningOrange),
                              const SizedBox(width: AppTheme.spacingS),
                              _StatusPill('Installed', statusTotals['installed']!, AppTheme.successGreen),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingM, 0,
                  AppTheme.spacingM, AppTheme.spacingM,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final m = materials[index];
                      final status = m['status'] ?? 'planned';
                      final qty = (m['quantity'] as num?)?.toDouble();
                      final unitPrice = (m['unit_price'] as num?)?.toDouble();

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
                              if (qty != null)
                                _DetailRow(
                                  label: 'Quantity',
                                  value: '$qty ${m['unit'] ?? ''}',
                                ),
                              if (unitPrice != null)
                                _DetailRow(
                                  label: 'Unit Price',
                                  value: currencyFmt.format(unitPrice),
                                ),
                              if (qty != null && unitPrice != null)
                                _DetailRow(
                                  label: 'Total',
                                  value: currencyFmt.format(qty * unitPrice),
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
                    childCount: materials.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Text(
        '$count $label',
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
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
            child: Text(
              label,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.bold),
            ),
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
class _DesignLogTab extends StatefulWidget {
  final String projectId;

  const _DesignLogTab({required this.projectId});

  @override
  State<_DesignLogTab> createState() => _DesignLogTabState();
}

class _DesignLogTabState extends State<_DesignLogTab> {
  // Issue #15 fix: 'proposed' is neutral, not a warning
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':    return AppTheme.successGreen;
      case 'rejected':    return AppTheme.errorRed;
      case 'implemented': return AppTheme.infoBlue;
      case 'proposed':    return AppTheme.textSecondary;
      default:            return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder(
      stream: supabase
          .from('design_change_logs')
          .stream(primaryKey: ['id'])
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        // Issue #5 fix: shimmer while waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerLoadingList(itemCount: 4, itemHeight: 140);
        }

        final changes = snapshot.data ?? [];

        if (changes.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.design_services_outlined,
            title: 'No Design Changes',
            subtitle: 'Design change proposals and approvals will appear here.',
          );
        }

        // Issue #6 fix: pull-to-refresh on Design Log
        return RefreshIndicator(
          onRefresh: () async {
            if (mounted) setState(() {});
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTheme.spacingM),
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final change = changes[index];
              final status = change['status'] ?? 'proposed';
              // Issue #14 fix: parse and show timestamp
              final createdAt = DateTime.tryParse(change['created_at'] ?? '');
              final dateStr = createdAt != null
                  ? DateFormat('dd MMM yyyy').format(createdAt.toLocal())
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  change['title'] ?? 'Design Change',
                                  style: AppTheme.headingSmall,
                                ),
                                // Issue #14 fix: timestamp below title
                                if (dateStr != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
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
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
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
          ),
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
        color: color.withValues(alpha: 0.05),
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

  // Issue #10 fix: Indian locale currency formatter
  final _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    try {
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
      case 'purchase':       return AppTheme.infoBlue;
      case 'labour_payment': return AppTheme.warningOrange;
      case 'petty_cash':     return AppTheme.primaryIndigo;
      default:               return AppTheme.textSecondary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'purchase':       return 'Purchase';
      case 'labour_payment': return 'Labour';
      case 'petty_cash':     return 'Petty Cash';
      default:               return 'Other';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'purchase':       return Icons.shopping_cart;
      case 'labour_payment': return Icons.engineering;
      case 'petty_cash':     return Icons.money;
      default:               return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Issue #4 fix: shimmer instead of spinner
    if (_isLoading) return const ShimmerLoadingList(itemCount: 5, itemHeight: 90);

    final hasApprovalData = _totalApproved > 0 || _totalPending > 0;

    return ContentConstraint(
      maxContentWidth: 1000,
      child: RefreshIndicator(
        onRefresh: _loadFinanceData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Issue #12 fix: only show approval cards when there's actual data
              if (hasApprovalData) ...[
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
                                // Issue #10 fix: formatted with locale
                                _currencyFmt.format(_totalApproved),
                                style: AppTheme.headingMedium.copyWith(
                                  color: AppTheme.successGreen,
                                ),
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
                                _currencyFmt.format(_totalPending),
                                style: AppTheme.headingMedium.copyWith(
                                  color: AppTheme.warningOrange,
                                ),
                              ),
                              Text(
                                '$_pendingCount Pending',
                                style: AppTheme.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
              ],

              // Total recorded spend card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: AppTheme.primaryIndigo,
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Recorded Spend', style: AppTheme.caption),
                            Text(
                              _currencyFmt.format(_totalTransactions),
                              style: AppTheme.headingMedium.copyWith(
                                color: AppTheme.primaryIndigo,
                              ),
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
                  final item = t['item'] ?? t['description'] ?? 'Transaction';
                  final vendor = t['vendor'] as String?;
                  final verified = t['verified_by'] != null;
                  // Issue #11 fix: proper zero-padded date with month name
                  final createdAt = DateTime.tryParse(t['created_at'] ?? '');
                  final dateStr = createdAt != null
                      ? DateFormat('dd MMM yyyy').format(createdAt.toLocal())
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getTypeColor(type),
                        child: Icon(
                          _getTypeIcon(type),
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
                      // Issue #18 fix: subtitle only has as many lines as needed
                      subtitle: Wrap(
                        spacing: AppTheme.spacingS,
                        runSpacing: 4,
                        children: [
                          CategoryBadge(
                            text: _getTypeLabel(type),
                            color: _getTypeColor(type),
                          ),
                          if (verified)
                            const CategoryBadge(
                              text: 'Verified',
                              color: AppTheme.successGreen,
                              icon: Icons.verified,
                            ),
                          if (vendor != null)
                            Text('Vendor: $vendor', style: AppTheme.caption),
                          if (dateStr != null)
                            Text(dateStr, style: AppTheme.caption),
                        ],
                      ),
                      trailing: Text(
                        // Issue #10 fix: locale-formatted amount
                        _currencyFmt.format(amount),
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryIndigo,
                        ),
                      ),
                      // Issue #18 fix: no isThreeLine — height adapts to content
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
