import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/services/finance_export_service.dart';
import 'package:houzzdat_app/features/finance/widgets/owner_payment_card.dart';
import 'package:houzzdat_app/features/finance/widgets/fund_request_card.dart';
import 'package:houzzdat_app/features/finance/widgets/add_owner_payment_sheet.dart';
import 'package:houzzdat_app/features/finance/widgets/add_fund_request_sheet.dart';
import 'package:houzzdat_app/features/finance/widgets/finance_charts.dart';
import 'package:intl/intl.dart';

/// Owner Finances sub-tab.
/// Two sections: Payments Received (from owner) and Fund Requests (to owner).
class OwnerFinancesSubtab extends StatefulWidget {
  final String accountId;
  const OwnerFinancesSubtab({super.key, required this.accountId});

  @override
  State<OwnerFinancesSubtab> createState() => _OwnerFinancesSubtabState();
}

class _OwnerFinancesSubtabState extends State<OwnerFinancesSubtab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _ownerPayments = [];
  List<Map<String, dynamic>> _fundRequests = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _owners = [];
  bool _isLoading = true;

  String? _expandedRequestId;

  // Section collapse state
  bool _paymentsExpanded = true;
  bool _requestsExpanded = true;
  bool _chartsExpanded = true; // UX-audit PP-03: chart section visibility

  RealtimeChannel? _ownerPaymentChannel;
  RealtimeChannel? _fundRequestChannel;

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ownerPaymentChannel?.unsubscribe();
    _fundRequestChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _ownerPaymentChannel = _supabase
        .channel('owner_payments_changes_${widget.accountId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'owner_payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: widget.accountId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();

    _fundRequestChannel = _supabase
        .channel('fund_requests_changes_${widget.accountId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fund_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: widget.accountId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _supabase
            .from('owner_payments')
            .select('*, users!owner_payments_owner_id_fkey(full_name), projects(name)')
            .eq('account_id', widget.accountId)
            .order('received_date', ascending: false),
        _supabase
            .from('fund_requests')
            .select('*, users!fund_requests_owner_id_fkey(full_name), projects(name)')
            .eq('account_id', widget.accountId)
            .order('created_at', ascending: false),
        _supabase
            .from('projects')
            .select('id, name')
            .eq('account_id', widget.accountId),
        // Get owners from project_owners with user details
        _supabase.rpc('get_account_owners', params: {'p_account_id': widget.accountId}).onError(
          // Fallback: query project_owners directly if RPC doesn't exist
          (error, stackTrace) async {
            try {
              final projectOwners = await _supabase
                  .from('project_owners')
                  .select('owner_id, users!project_owners_owner_id_fkey(full_name, email)')
                  .inFilter(
                    'project_id',
                    (await _supabase
                            .from('projects')
                            .select('id')
                            .eq('account_id', widget.accountId))
                        .map((p) => p['id'])
                        .toList(),
                  );
              // Deduplicate by owner_id
              final seen = <String>{};
              final unique = <Map<String, dynamic>>[];
              for (final po in projectOwners) {
                final ownerId = po['owner_id']?.toString() ?? '';
                if (seen.add(ownerId)) {
                  unique.add({
                    'owner_id': ownerId,
                    'full_name': po['users']?['full_name']?.toString() ?? '',
                    'email': po['users']?['email']?.toString() ?? '',
                  });
                }
              }
              return unique;
            } catch (e) {
              debugPrint('Error loading account owners: $e');
              return <Map<String, dynamic>>[];
            }
          },
        ),
      ]);

      if (mounted) {
        setState(() {
          _ownerPayments = List<Map<String, dynamic>>.from(results[0]);
          _fundRequests = List<Map<String, dynamic>>.from(results[1]);
          _projects = List<Map<String, dynamic>>.from(results[2]);
          _owners = List<Map<String, dynamic>>.from(results[3]);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading owner finances: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Computed metrics ──

  double get _totalReceived => _ownerPayments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );

  double get _totalRequested => _fundRequests.fold<double>(
        0,
        (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
      );

  int get _pendingCount =>
      _fundRequests.where((r) => r['status'] == 'pending').length;

  // ── Actions ──

  Future<void> _handleRecordOwnerPayment() async {
    final data = await AddOwnerPaymentSheet.show(
      context,
      projects: _projects,
      owners: _owners,
    );
    if (data == null) return;

    try {
      await _supabase.from('owner_payments').insert({
        ...data,
        'account_id': widget.accountId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner payment recorded'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording owner payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record payment. Please check your connection and try again.'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Future<void> _handleCreateFundRequest() async {
    final data = await AddFundRequestSheet.show(
      context,
      projects: _projects,
      owners: _owners,
    );
    if (data == null) return;

    try {
      await _supabase.from('fund_requests').insert({
        ...data,
        'account_id': widget.accountId,
        'requested_by': _supabase.auth.currentUser?.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fund request submitted'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating fund request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit fund request. Please try again.'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Future<void> _handleConfirmPayment(Map<String, dynamic> payment) async {
    try {
      await _supabase.from('owner_payments').update({
        'confirmed_by': _supabase.auth.currentUser?.id,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', payment['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error confirming payment: $e');
    }
  }

  /// UX-audit PP-02: Generate and share financial report PDF
  void _handleExportPdf() {
    FinanceExportService.generateAndShare(
      context: context,
      payments: _ownerPayments,
      fundRequests: _fundRequests,
      accountName: 'Financial Report',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const ShimmerLoadingList(itemCount: 4, itemHeight: 120); // UX-audit #4: shimmer instead of spinner
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppTheme.spacingXL),
        child: Column(
          children: [
            // ── Summary row ──
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  _SummaryMetric(
                    label: 'Total Received',
                    value: _currencyFormat.format(_totalReceived),
                    color: AppTheme.successGreen,
                    icon: Icons.arrow_downward_rounded,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  _SummaryMetric(
                    label: 'Total Requested',
                    value: _currencyFormat.format(_totalRequested),
                    color: AppTheme.infoBlue,
                    icon: Icons.arrow_upward_rounded,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  _SummaryMetric(
                    label: 'Pending',
                    value: '$_pendingCount',
                    color: AppTheme.warningOrange,
                    icon: Icons.hourglass_top_rounded,
                  ),
                ],
              ),
            ),
            // UX-audit PP-02: Export button row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _handleExportPdf,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Export PDF'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryIndigo,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),

            // UX-audit PP-03: Financial analytics charts
            _CollapsibleSection(
              title: 'Analytics',
              count: 0,
              isExpanded: _chartsExpanded,
              onToggle: () => setState(() => _chartsExpanded = !_chartsExpanded),
            ),
            if (_chartsExpanded) ...[
              MonthlyCashFlowChart(
                payments: _ownerPayments,
                fundRequests: _fundRequests,
              ),
              // UX-audit PP-07: Project expenditure breakdown with month-over-month delta
              ProjectExpenditureChart(
                fundRequests: _fundRequests,
                projects: _projects,
              ),
              FundRequestStatusChart(fundRequests: _fundRequests),
              const SizedBox(height: AppTheme.spacingS),
            ],
            const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),

            // ── Payments Received section ──
            _CollapsibleSection(
              title: 'Payments Received',
              count: _ownerPayments.length,
              isExpanded: _paymentsExpanded,
              onToggle: () => setState(() => _paymentsExpanded = !_paymentsExpanded),
              trailing: TextButton.icon(
                onPressed: _handleRecordOwnerPayment,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Record'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.successGreen),
              ),
            ),
            if (_paymentsExpanded) ...[
              if (_ownerPayments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: EmptyStateWidget( // UX-audit #10: actionable empty state
                    icon: Icons.account_balance_outlined,
                    title: 'No payments received',
                    subtitle: 'Record payments from owners here',
                    action: ActionButton(
                      label: 'Record Payment',
                      icon: Icons.add,
                      onPressed: _handleRecordOwnerPayment,
                    ),
                  ),
                )
              else
                ..._ownerPayments.map((p) => OwnerPaymentCard(
                      payment: p,
                      onConfirm: p['confirmed_by'] == null
                          ? () => _handleConfirmPayment(p)
                          : null,
                    )),
              const SizedBox(height: AppTheme.spacingM),
            ],

            // ── Fund Requests section ──
            _CollapsibleSection(
              title: 'Fund Requests',
              count: _fundRequests.length,
              isExpanded: _requestsExpanded,
              onToggle: () => setState(() => _requestsExpanded = !_requestsExpanded),
              trailing: TextButton.icon(
                onPressed: _handleCreateFundRequest,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Request'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryIndigo),
              ),
            ),
            if (_requestsExpanded) ...[
              if (_fundRequests.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: EmptyStateWidget( // UX-audit #10: actionable empty state
                    icon: Icons.request_quote_outlined,
                    title: 'No fund requests',
                    subtitle: 'Create a request for funds from the owner',
                    action: ActionButton(
                      label: 'New Fund Request',
                      icon: Icons.add,
                      onPressed: _handleCreateFundRequest,
                    ),
                  ),
                )
              else
                ..._fundRequests.map((r) {
                  final requestId = r['id']?.toString() ?? '';
                  return FundRequestCard(
                    request: r,
                    isExpanded: _expandedRequestId == requestId,
                    onTap: () {
                      setState(() {
                        _expandedRequestId =
                            _expandedRequestId == requestId ? null : requestId;
                      });
                    },
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: AppTheme.caption.copyWith(color: color, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget? trailing;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryIndigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
