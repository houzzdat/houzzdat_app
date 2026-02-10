import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/reports/screens/generate_report_screen.dart';
import 'package:houzzdat_app/features/reports/screens/report_detail_screen.dart';
import 'package:houzzdat_app/features/reports/screens/prompts_management_screen.dart';
import 'package:houzzdat_app/features/reports/widgets/report_card.dart';

/// Main Reports screen showing saved reports list and access to generate new ones.
class ReportsScreen extends StatefulWidget {
  final String accountId;
  const ReportsScreen({super.key, required this.accountId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  RealtimeChannel? _reportsChannel;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _reportsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _reportsChannel = _supabase
        .channel('reports_changes_${widget.accountId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reports',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: widget.accountId,
          ),
          callback: (_) => _loadReports(),
        )
        .subscribe();
  }

  Future<void> _loadReports() async {
    try {
      final data = await _supabase
          .from('reports')
          .select('*, users!reports_created_by_fkey(full_name)')
          .eq('account_id', widget.accountId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_filterStatus == 'all') return _reports;

    return _reports.where((r) {
      final mgrStatus = r['manager_report_status']?.toString() ?? 'draft';
      final ownerStatus = r['owner_report_status']?.toString() ?? 'draft';

      switch (_filterStatus) {
        case 'draft':
          return mgrStatus == 'draft' && ownerStatus == 'draft';
        case 'final':
          return mgrStatus == 'final' || ownerStatus == 'final';
        case 'sent':
          return ownerStatus == 'sent';
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _handleDeleteReport(Map<String, dynamic> report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('This draft report will be permanently deleted. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('reports').delete().eq('id', report['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error deleting report: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete report. Please try again.'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      PromptsManagementScreen(accountId: widget.accountId),
                ),
              );
            },
            tooltip: 'Manage AI Prompts',
          ),
        ],
      ),
      body: Column(
        children: [
          // Generate new report button
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          GenerateReportScreen(accountId: widget.accountId),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text(
                  'Generate New Report',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentAmber,
                  foregroundColor: AppTheme.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                  elevation: 1,
                ),
              ),
            ),
          ),

          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  '${_filteredReports.length} report${_filteredReports.length == 1 ? '' : 's'}',
                  style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('Draft', 'draft'),
                const SizedBox(width: 6),
                _buildFilterChip('Final', 'final'),
                const SizedBox(width: 6),
                _buildFilterChip('Sent', 'sent'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          // Reports list
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Loading reports...')
                : _filteredReports.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.assessment_outlined,
                        title: 'No reports yet',
                        subtitle: 'Tap "Generate New Report" to create your first AI-powered report',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                            top: AppTheme.spacingS,
                            bottom: AppTheme.spacingXL,
                          ),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, i) {
                            final report = _filteredReports[i];
                            return ReportCard(
                              report: report,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ReportDetailScreen(
                                      reportId: report['id']?.toString() ?? '',
                                      accountId: widget.accountId,
                                    ),
                                  ),
                                );
                              },
                              onDelete: () => _handleDeleteReport(report),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isActive
                ? AppTheme.primaryIndigo
                : AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
