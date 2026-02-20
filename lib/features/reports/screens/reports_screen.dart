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

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  RealtimeChannel? _reportsChannel;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReports();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Saved Reports'),
            Tab(text: 'Daily Reports'),
          ],
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Saved Reports Tab
          Column(
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
          // Daily Reports Tab
          _DailyReportsTab(accountId: widget.accountId),
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

// ══════════════════════════════════════════════════════════════
// Daily Reports Tab
// ══════════════════════════════════════════════════════════════

class _DailyReportsTab extends StatefulWidget {
  final String accountId;

  const _DailyReportsTab({required this.accountId});

  @override
  State<_DailyReportsTab> createState() => _DailyReportsTabState();
}

class _DailyReportsTabState extends State<_DailyReportsTab> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _dailyReports = [];
  Map<String, String> _userNames = {};
  Map<String, String> _projectNames = {};
  bool _isLoading = true;
  String? _selectedProjectId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadProjects(),
      _loadDailyReports(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _supabase
          .from('projects')
          .select('id, name')
          .eq('account_id', widget.accountId);

      if (mounted) {
        setState(() {
          _projectNames = {
            for (var p in projects)
              p['id'].toString(): p['name']?.toString() ?? 'Site'
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  Future<void> _loadDailyReports() async {
    try {
      final dayStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final dayEnd = DateTime(_endDate.year, _endDate.month, _endDate.day)
          .add(const Duration(days: 1));

      // Query attendance records
      var query = _supabase
          .from('attendance')
          .select('report_voice_note_id, user_id, check_in_at, check_out_at, project_id, voice_notes!report_voice_note_id(*)')
          .eq('account_id', widget.accountId)
          .gte('check_out_at', dayStart.toIso8601String())
          .lt('check_out_at', dayEnd.toIso8601String())
          .not('report_voice_note_id', 'is', null);

      if (_selectedProjectId != null) {
        query = query.eq('project_id', _selectedProjectId!);
      }

      final data = await query.order('check_out_at', ascending: false);

      final reports = (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Get unique user IDs
      final userIds = reports
          .map((r) => r['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      // Fetch user names
      final newNames = Map<String, String>.from(_userNames);
      for (final uid in userIds) {
        if (uid != null && !newNames.containsKey(uid)) {
          try {
            final user = await _supabase
                .from('users')
                .select('full_name, email')
                .eq('id', uid)
                .maybeSingle();
            if (user != null) {
              newNames[uid] =
                  user['full_name']?.toString() ?? user['email']?.toString() ?? 'User';
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _dailyReports = reports;
          _userNames = newNames;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily reports: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project filter
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Filter by Project',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Projects')),
                  ..._projectNames.entries.map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value))),
                ],
                onChanged: (value) {
                  setState(() => _selectedProjectId = value);
                  _loadDailyReports();
                },
              ),
              const SizedBox(height: 12),
              // Date range
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                          _loadDailyReports();
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_formatDate(_startDate)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to'),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _endDate = picked);
                          _loadDailyReports();
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_formatDate(_endDate)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Reports list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _dailyReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No daily reports',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No reports found for the selected filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      itemCount: _dailyReports.length,
                      itemBuilder: (context, i) {
                        final report = _dailyReports[i];
                        final voiceNote = report['voice_notes'];
                        final userName = _userNames[report['user_id']?.toString()] ?? 'Unknown';
                        final projectName = _projectNames[report['project_id']?.toString()] ?? 'Unknown Site';
                        final checkOut = DateTime.parse(report['check_out_at']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8EAF6),
                              child: Icon(Icons.description, color: Color(0xFF1A237E)),
                            ),
                            title: Text(
                              userName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(projectName),
                                Text(
                                  _formatDate(checkOut),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                if (voiceNote != null && voiceNote['transcript_final'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    voiceNote['transcript_final'].toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // Navigate to report detail or show dialog
                              _showReportDetail(report);
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showReportDetail(Map<String, dynamic> report) {
    final voiceNote = report['voice_notes'];
    final userName = _userNames[report['user_id']?.toString()] ?? 'Unknown';
    final projectName = _projectNames[report['project_id']?.toString()] ?? 'Unknown Site';
    final checkOut = DateTime.parse(report['check_out_at']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Daily Report - $userName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Project: $projectName', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Date: ${_formatDate(checkOut)}'),
              const SizedBox(height: 16),
              if (voiceNote != null) ...[
                if (voiceNote['transcript_final'] != null || voiceNote['transcription'] != null)
                  Text(
                    voiceNote['transcript_final']?.toString() ??
                        voiceNote['transcription']?.toString() ??
                        'No transcript available',
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
