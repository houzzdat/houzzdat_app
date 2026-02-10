import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/finance/widgets/finance_summary_bar.dart';
import 'package:houzzdat_app/features/finance/widgets/invoice_card.dart';
import 'package:houzzdat_app/features/finance/widgets/payment_card.dart';
import 'package:houzzdat_app/features/finance/widgets/add_invoice_sheet.dart';
import 'package:houzzdat_app/features/finance/widgets/add_payment_sheet.dart';

/// Site Finances sub-tab.
/// Shows invoices and payments for the account with filtering, search, and
/// summary metrics. Supports create/approve/reject/pay workflows.
class SiteFinancesSubtab extends StatefulWidget {
  final String accountId;
  const SiteFinancesSubtab({super.key, required this.accountId});

  @override
  State<SiteFinancesSubtab> createState() => _SiteFinancesSubtabState();
}

class _SiteFinancesSubtabState extends State<SiteFinancesSubtab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  // Filters
  String _filterStatus = 'all';
  String? _filterProjectId;
  String? _expandedInvoiceId;

  // View mode: 'invoices' or 'payments'
  String _viewMode = 'invoices';

  RealtimeChannel? _invoiceChannel;
  RealtimeChannel? _paymentChannel;

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
    _invoiceChannel?.unsubscribe();
    _paymentChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _invoiceChannel = _supabase
        .channel('invoices_changes_${widget.accountId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invoices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: widget.accountId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();

    _paymentChannel = _supabase
        .channel('payments_changes_${widget.accountId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
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
            .from('invoices')
            .select('*, projects(name), users!invoices_submitted_by_fkey(full_name)')
            .eq('account_id', widget.accountId)
            .order('created_at', ascending: false),
        _supabase
            .from('payments')
            .select('*, projects(name)')
            .eq('account_id', widget.accountId)
            .order('payment_date', ascending: false),
        _supabase
            .from('projects')
            .select('id, name')
            .eq('account_id', widget.accountId),
      ]);

      if (mounted) {
        setState(() {
          _invoices = List<Map<String, dynamic>>.from(results[0]);
          _payments = List<Map<String, dynamic>>.from(results[1]);
          _projects = List<Map<String, dynamic>>.from(results[2]);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading site finances: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Computed metrics ──

  double get _totalInvoiced => _invoices.fold<double>(
        0,
        (sum, inv) => sum + ((inv['amount'] as num?)?.toDouble() ?? 0),
      );

  double get _totalPaid {
    // Sum payments linked to invoices + standalone payments
    return _payments.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  double get _totalPending {
    return _invoices
        .where((inv) =>
            inv['status'] == 'submitted' ||
            inv['status'] == 'approved' ||
            inv['status'] == 'draft')
        .fold<double>(0, (sum, inv) => sum + ((inv['amount'] as num?)?.toDouble() ?? 0));
  }

  double get _totalOverdue {
    final now = DateTime.now();
    return _invoices.where((inv) {
      if (inv['status'] == 'paid') return false;
      final dueDateStr = inv['due_date']?.toString();
      if (dueDateStr == null || dueDateStr.isEmpty) return false;
      try {
        return DateTime.parse(dueDateStr).isBefore(now);
      } catch (_) {
        return false;
      }
    }).fold<double>(0, (sum, inv) => sum + ((inv['amount'] as num?)?.toDouble() ?? 0));
  }

  // ── Filtered list ──

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((inv) {
      if (_filterStatus != 'all' && inv['status'] != _filterStatus) return false;
      if (_filterProjectId != null && inv['project_id'] != _filterProjectId) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((p) {
      if (_filterProjectId != null && p['project_id'] != _filterProjectId) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _paymentsForInvoice(String invoiceId) {
    return _payments.where((p) => p['invoice_id'] == invoiceId).toList();
  }

  // ── Actions ──

  Future<void> _handleCreateInvoice() async {
    final data = await AddInvoiceSheet.show(context, projects: _projects);
    if (data == null) return;

    try {
      await _supabase.from('invoices').insert({
        ...data,
        'account_id': widget.accountId,
        'submitted_by': _supabase.auth.currentUser?.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create invoice. Please check your connection and try again.'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Future<void> _handleAddPayment({String? invoiceId, String? projectId}) async {
    final data = await AddPaymentSheet.show(
      context,
      projects: _projects,
      invoices: _invoices.where((inv) => inv['status'] == 'approved').toList(),
      preselectedInvoiceId: invoiceId,
      preselectedProjectId: projectId,
    );
    if (data == null) return;

    try {
      await _supabase.from('payments').insert({
        ...data,
        'account_id': widget.accountId,
        'paid_by': _supabase.auth.currentUser?.id,
      });

      // If linked to an invoice, check if fully paid
      if (data['invoice_id'] != null) {
        await _checkAndUpdateInvoicePaidStatus(data['invoice_id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding payment: $e');
    }
  }

  Future<void> _checkAndUpdateInvoicePaidStatus(String invoiceId) async {
    try {
      final invoice =
          await _supabase.from('invoices').select('amount').eq('id', invoiceId).single();
      final payments = await _supabase
          .from('payments')
          .select('amount')
          .eq('invoice_id', invoiceId);

      final invoiceAmount = (invoice['amount'] as num?)?.toDouble() ?? 0;
      final totalPaid = payments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );

      if (totalPaid >= invoiceAmount) {
        await _supabase.from('invoices').update({
          'status': 'paid',
          'paid_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', invoiceId);
      }
    } catch (e) {
      debugPrint('Error checking paid status: $e');
    }
  }

  Future<void> _handleApproveInvoice(Map<String, dynamic> invoice) async {
    try {
      await _supabase.from('invoices').update({
        'status': 'approved',
        'approved_by': _supabase.auth.currentUser?.id,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', invoice['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice approved'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving invoice: $e');
    }
  }

  Future<void> _handleRejectInvoice(Map<String, dynamic> invoice) async {
    final reason = await _showReasonDialog('Reject Invoice', 'Reason for rejection');
    if (reason == null) return;

    try {
      await _supabase.from('invoices').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', invoice['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice rejected'),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting invoice: $e');
    }
  }

  Future<void> _handleSubmitInvoice(Map<String, dynamic> invoice) async {
    try {
      await _supabase.from('invoices').update({
        'status': 'submitted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', invoice['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice submitted for approval'),
            backgroundColor: AppTheme.infoBlue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting invoice: $e');
    }
  }

  Future<String?> _showReasonDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const LoadingWidget(message: 'Loading finances...');
    }

    return Stack(
      children: [
        Column(
          children: [
            // Summary bar
            FinanceSummaryBar(
              totalInvoiced: _totalInvoiced,
              totalPaid: _totalPaid,
              totalPending: _totalPending,
              totalOverdue: _totalOverdue,
            ),

            // View mode toggle + filter bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              color: Colors.white,
              child: Column(
                children: [
                  // View toggle
                  Row(
                    children: [
                      _ViewToggleChip(
                        label: 'Invoices',
                        isActive: _viewMode == 'invoices',
                        count: _filteredInvoices.length,
                        onTap: () => setState(() => _viewMode = 'invoices'),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      _ViewToggleChip(
                        label: 'Payments',
                        isActive: _viewMode == 'payments',
                        count: _filteredPayments.length,
                        onTap: () => setState(() => _viewMode = 'payments'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // Filters
                  Row(
                    children: [
                      // Site filter
                      Expanded(
                        child: _buildDropdownFilter(
                          label: 'Site',
                          value: _filterProjectId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Sites')),
                            ..._projects.map((p) => DropdownMenuItem(
                                  value: p['id']?.toString(),
                                  child: Text(
                                    p['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() => _filterProjectId = v),
                        ),
                      ),
                      if (_viewMode == 'invoices') ...[
                        const SizedBox(width: AppTheme.spacingS),
                        // Status filter
                        Expanded(
                          child: _buildDropdownFilter(
                            label: 'Status',
                            value: _filterStatus == 'all' ? null : _filterStatus,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All')),
                              DropdownMenuItem(value: 'draft', child: Text('Draft')),
                              DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                              DropdownMenuItem(value: 'approved', child: Text('Approved')),
                              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                              DropdownMenuItem(value: 'paid', child: Text('Paid')),
                              DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                            ],
                            onChanged: (v) =>
                                setState(() => _filterStatus = v ?? 'all'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: _viewMode == 'invoices' ? _buildInvoiceList() : _buildPaymentList(),
              ),
            ),
          ],
        ),

        // FAB
        Positioned(
          right: AppTheme.spacingM,
          bottom: AppTheme.spacingM,
          child: FloatingActionButton(
            backgroundColor: AppTheme.primaryIndigo,
            onPressed: _showAddOptions,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long, color: AppTheme.primaryIndigo),
              title: const Text('New Invoice'),
              subtitle: const Text('Create a new invoice'),
              onTap: () {
                Navigator.pop(ctx);
                _handleCreateInvoice();
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment, color: AppTheme.successGreen),
              title: const Text('Add Payment'),
              subtitle: const Text('Record a payment'),
              onTap: () {
                Navigator.pop(ctx);
                _handleAddPayment();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList() {
    final invoices = _filteredInvoices;
    if (invoices.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long_outlined,
        title: 'No invoices yet',
        subtitle: 'Tap + to create your first invoice',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppTheme.spacingS,
        bottom: 80, // Space for FAB
      ),
      itemCount: invoices.length,
      itemBuilder: (context, i) {
        final invoice = invoices[i];
        final invoiceId = invoice['id']?.toString() ?? '';
        final status = invoice['status']?.toString() ?? 'draft';

        return InvoiceCard(
          invoice: invoice,
          linkedPayments: _paymentsForInvoice(invoiceId),
          isExpanded: _expandedInvoiceId == invoiceId,
          onTap: () {
            setState(() {
              _expandedInvoiceId = _expandedInvoiceId == invoiceId ? null : invoiceId;
            });
          },
          onApprove: status == 'submitted' ? () => _handleApproveInvoice(invoice) : null,
          onReject: status == 'submitted' ? () => _handleRejectInvoice(invoice) : null,
          onAddPayment: (status == 'approved' || status == 'paid')
              ? () => _handleAddPayment(
                    invoiceId: invoiceId,
                    projectId: invoice['project_id']?.toString(),
                  )
              : null,
          onSubmit: status == 'draft' ? () => _handleSubmitInvoice(invoice) : null,
        );
      },
    );
  }

  Widget _buildPaymentList() {
    final payments = _filteredPayments;
    if (payments.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.payment_outlined,
        title: 'No payments yet',
        subtitle: 'Tap + to record a payment',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppTheme.spacingS,
        bottom: 80,
      ),
      itemCount: payments.length,
      itemBuilder: (context, i) => PaymentCard(payment: payments[i]),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryIndigo, size: 20),
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ViewToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final int count;
  final VoidCallback onTap;

  const _ViewToggleChip({
    required this.label,
    required this.isActive,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isActive ? AppTheme.primaryIndigo : AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
