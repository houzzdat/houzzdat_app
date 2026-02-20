import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_card.dart';

/// Manager's site detail screen — opened when tapping a site card.
/// Contains tabs for Summary and Daily Reports (voice notes).
class ManagerSiteDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final String accountId;

  const ManagerSiteDetailScreen({
    super.key,
    required this.project,
    required this.accountId,
  });

  @override
  State<ManagerSiteDetailScreen> createState() =>
      _ManagerSiteDetailScreenState();
}

class _ManagerSiteDetailScreenState extends State<ManagerSiteDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectName = widget.project['name']?.toString() ?? 'Site';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(projectName),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Summary'),
            Tab(icon: Icon(Icons.mic_none, size: 20), text: 'Daily Reports'),
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
          _DailyReportsTab(
            projectId: widget.project['id'],
            accountId: widget.accountId,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SUMMARY TAB — project status overview
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
  List<Map<String, dynamic>> _recentActions = [];
  int _workerCount = 0;
  int _todayVoiceNotes = 0;
  bool _isLoading = true;

  // Trajectory data
  int _daysSinceLastActivity = 0;
  int _completedLastWeek = 0;
  int _completedThisWeek = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);

    try {
      // Action items
      final actionItems = await _supabase
          .from('action_items')
          .select('status, priority, summary, category, created_at')
          .eq('project_id', widget.projectId);

      final counts = <String, int>{};
      final blockers = <Map<String, dynamic>>[];
      final recentActions = <Map<String, dynamic>>[];

      for (final item in actionItems) {
        final status = item['status'] ?? 'pending';
        counts[status] = (counts[status] ?? 0) + 1;

        if ((status == 'pending' || status == 'in_progress') &&
            item['priority'] == 'High') {
          blockers.add(Map<String, dynamic>.from(item));
        }
      }

      // Sort by newest and take top 5
      final sorted = List<Map<String, dynamic>>.from(actionItems);
      sorted.sort((a, b) {
        final aDate = a['created_at']?.toString() ?? '';
        final bDate = b['created_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });
      recentActions.addAll(sorted.take(5));

      // Worker count for this project
      final workers = await _supabase
          .from('users')
          .select('id')
          .eq('current_project_id', widget.projectId);

      // Today's voice notes count
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final todayNotes = await _supabase
          .from('voice_notes')
          .select('id')
          .eq('project_id', widget.projectId)
          .gte('created_at', todayStart);

      // Trajectory: days since last activity
      int daysSinceActivity = 0;
      if (actionItems.isNotEmpty) {
        final dates = actionItems
            .map((a) => a['created_at']?.toString())
            .where((d) => d != null)
            .toList();
        if (dates.isNotEmpty) {
          dates.sort((a, b) => b!.compareTo(a!));
          final lastDate = DateTime.tryParse(dates.first!);
          if (lastDate != null) {
            daysSinceActivity = now.difference(lastDate).inDays;
          }
        }
      }

      // Trajectory: completed this week vs last week
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final lastWeekStart = weekStart.subtract(const Duration(days: 7));
      int completedThisWeek = 0;
      int completedLastWeek = 0;
      for (final item in actionItems) {
        if (item['status'] != 'completed') continue;
        final dateStr = item['created_at']?.toString();
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        if (date.isAfter(weekStart)) {
          completedThisWeek++;
        } else if (date.isAfter(lastWeekStart)) {
          completedLastWeek++;
        }
      }

      if (mounted) {
        setState(() {
          _statusCounts = counts;
          _blockers = blockers;
          _recentActions = recentActions;
          _workerCount = (workers as List).length;
          _todayVoiceNotes = (todayNotes as List).length;
          _daysSinceLastActivity = daysSinceActivity;
          _completedThisWeek = completedThisWeek;
          _completedLastWeek = completedLastWeek;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading site summary: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading site summary...');
    }

    final total = _statusCounts.values.fold(0, (a, b) => a + b);
    final pending = (_statusCounts['pending'] ?? 0) +
        (_statusCounts['approved'] ?? 0);
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

            const SizedBox(height: AppTheme.spacingM),

            // Quick stats row
            Row(
              children: [
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.people,
                    label: 'Workers',
                    value: '$_workerCount',
                    color: AppTheme.primaryIndigo,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.mic,
                    label: "Today's Reports",
                    value: '$_todayVoiceNotes',
                    color: AppTheme.infoBlue,
                  ),
                ),
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

            // Completion trajectory
            if (total > 0) ...[
              _buildTrajectoryCard(total, completed),
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
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                      color: AppTheme.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppTheme.successGreen),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'No blockers',
                      style: AppTheme.bodyMedium
                          .copyWith(color: AppTheme.successGreen),
                    ),
                  ],
                ),
              )
            else
              ...(_blockers.map((blocker) => Card(
                    margin:
                        const EdgeInsets.only(bottom: AppTheme.spacingS),
                    child: ListTile(
                      leading:
                          const PriorityIndicator(priority: 'High'),
                      title: Text(
                        blocker['summary'] ?? 'Action item',
                        style: AppTheme.bodyMedium
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: CategoryBadge(
                        text: (blocker['category'] ?? '')
                            .toString()
                            .toUpperCase(),
                        color: blocker['category'] == 'action_required'
                            ? AppTheme.errorRed
                            : AppTheme.warningOrange,
                      ),
                    ),
                  ))),

            const SizedBox(height: AppTheme.spacingL),

            // Recent action items
            if (_recentActions.isNotEmpty) ...[
              Text('Recent Actions', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingS),
              ..._recentActions.map((action) {
                final status = action['status'] ?? 'pending';
                final created = action['created_at']?.toString();
                String timeLabel = '';
                if (created != null) {
                  try {
                    final dt = DateTime.parse(created);
                    final diff = DateTime.now().difference(dt);
                    if (diff.inMinutes < 60) {
                      timeLabel = '${diff.inMinutes}m ago';
                    } else if (diff.inHours < 24) {
                      timeLabel = '${diff.inHours}h ago';
                    } else {
                      timeLabel =
                          DateFormat('d MMM').format(dt);
                    }
                  } catch (_) {}
                }

                return Card(
                  margin: const EdgeInsets.only(
                      bottom: AppTheme.spacingXS),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      _statusIcon(status),
                      color: _statusColor(status),
                      size: 20,
                    ),
                    title: Text(
                      action['summary'] ?? 'Action item',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        CategoryBadge(
                          text: status.toUpperCase(),
                          color: _statusColor(status),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: AppTheme.spacingS),
                          Text(timeLabel, style: AppTheme.caption),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrajectoryCard(int total, int completed) {
    // Determine trajectory: improving, stable, or declining
    final String trajectory;
    final IconData trajectoryIcon;
    final Color trajectoryColor;

    if (_completedThisWeek > _completedLastWeek) {
      trajectory = 'Improving';
      trajectoryIcon = Icons.trending_up;
      trajectoryColor = AppTheme.successGreen;
    } else if (_completedThisWeek == _completedLastWeek) {
      trajectory = 'Stable';
      trajectoryIcon = Icons.trending_flat;
      trajectoryColor = AppTheme.infoBlue;
    } else {
      trajectory = 'Slowing Down';
      trajectoryIcon = Icons.trending_down;
      trajectoryColor = AppTheme.warningOrange;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Completion Trajectory', style: AppTheme.headingSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trajectoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trajectoryIcon, size: 16, color: trajectoryColor),
                    const SizedBox(width: 4),
                    Text(trajectory, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: trajectoryColor,
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Completion rate comparison
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('$_completedThisWeek', style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: trajectoryColor,
                    )),
                    Text('Done This Week', style: AppTheme.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: trajectoryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(trajectoryIcon, size: 20, color: trajectoryColor),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('$_completedLastWeek', style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textSecondary,
                    )),
                    Text('Done Last Week', style: AppTheme.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Days since last activity
          Row(
            children: [
              Icon(
                _daysSinceLastActivity == 0 ? Icons.check_circle : Icons.access_time,
                size: 16,
                color: _daysSinceLastActivity > 2 ? AppTheme.warningOrange : AppTheme.successGreen,
              ),
              const SizedBox(width: 6),
              Text(
                _daysSinceLastActivity == 0
                    ? 'Active today'
                    : '$_daysSinceLastActivity day${_daysSinceLastActivity == 1 ? '' : 's'} since last activity',
                style: TextStyle(
                  fontSize: 12,
                  color: _daysSinceLastActivity > 2 ? AppTheme.warningOrange : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successGreen;
      case 'in_progress':
      case 'verifying':
        return AppTheme.infoBlue;
      case 'pending':
      case 'approved':
        return AppTheme.warningOrange;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.play_circle;
      case 'verifying':
        return Icons.pending;
      case 'pending':
        return Icons.radio_button_unchecked;
      default:
        return Icons.circle_outlined;
    }
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

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: AppTheme.headingMedium.copyWith(color: color)),
                  Text(label, style: AppTheme.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DAILY REPORTS TAB — voice notes for this project
// ============================================================
class _DailyReportsTab extends StatefulWidget {
  final String projectId;
  final String accountId;

  const _DailyReportsTab({
    required this.projectId,
    required this.accountId,
  });

  @override
  State<_DailyReportsTab> createState() => _DailyReportsTabState();
}

class _DailyReportsTabState extends State<_DailyReportsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _voiceNotes = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _channel;

  // Date filter state
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadVoiceNotes();
    _setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _channel = _supabase.channel('site-reports-${widget.projectId}');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'voice_notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: widget.projectId,
          ),
          callback: (payload) {
            _loadVoiceNotes();
          },
        )
        .subscribe();
  }

  Future<void> _loadVoiceNotes() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // Date range for query
      final dayStart = DateTime(
          _startDate.year, _startDate.month, _startDate.day);
      final dayEnd = DateTime(
              _endDate.year, _endDate.month, _endDate.day)
          .add(const Duration(days: 1));

      // Step 1: Query attendance records for this project within date range
      final attendanceRecords = await _supabase
          .from('attendance')
          .select('report_voice_note_id, user_id, check_in_at, check_out_at')
          .eq('project_id', widget.projectId)
          .gte('check_out_at', dayStart.toIso8601String())
          .lt('check_out_at', dayEnd.toIso8601String())
          .not('report_voice_note_id', 'is', null);

      // Step 2: Extract voice note IDs
      final reportVoiceNoteIds = attendanceRecords
          .map((a) => a['report_voice_note_id']?.toString())
          .where((id) => id != null)
          .toList();

      if (reportVoiceNoteIds.isEmpty) {
        if (mounted) {
          setState(() {
            _voiceNotes = [];
            _isLoading = false;
            _error = null;
          });
        }
        return;
      }

      // Step 3: Fetch voice notes for these IDs
      final data = await _supabase
          .from('voice_notes')
          .select()
          .inFilter('id', reportVoiceNoteIds)
          .order('created_at', ascending: false);

      final notes = (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Resolve user names
      final userIds = notes
          .map((n) => n['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

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
          _voiceNotes = notes;
          _userNames = newNames;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading voice notes: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load reports';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryIndigo,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If start is after end, adjust end
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      });
      _loadVoiceNotes();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryIndigo,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _loadVoiceNotes();
    }
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date filter bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          color: Colors.white,
          child: Row(
            children: [
              // From date
              _DateChip(
                label: _isToday(_startDate)
                    ? 'Today'
                    : DateFormat('d MMM').format(_startDate),
                onTap: _pickStartDate,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'to',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              // To date
              _DateChip(
                label: _isToday(_endDate)
                    ? 'Today'
                    : DateFormat('d MMM').format(_endDate),
                onTap: _pickEndDate,
              ),
              const Spacer(),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_voiceNotes.length} report${_voiceNotes.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryIndigo,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

        // Voice notes list
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading daily reports...');
    }

    if (_error != null) {
      return ErrorStateWidget(
        message: _error!,
        onRetry: _loadVoiceNotes,
      );
    }

    if (_voiceNotes.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.mic_off_outlined,
        title: 'No Reports',
        subtitle: _isToday(_startDate) && _isToday(_endDate)
            ? 'No voice reports have been submitted today for this site.'
            : 'No voice reports found for the selected date range.',
      );
    }

    // Group voice notes by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final note in _voiceNotes) {
      final createdAt = note['created_at']?.toString() ?? '';
      try {
        final dt = DateTime.parse(createdAt);
        final dateKey = DateFormat('yyyy-MM-dd').format(dt);
        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add(note);
      } catch (_) {
        grouped.putIfAbsent('unknown', () => []);
        grouped['unknown']!.add(note);
      }
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _loadVoiceNotes,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: AppTheme.spacingS,
          bottom: AppTheme.spacingXL,
        ),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          final notes = grouped[dateKey]!;

          // Format date header
          String dateHeader;
          try {
            final dt = DateTime.parse(dateKey);
            if (_isToday(dt)) {
              dateHeader = 'Today';
            } else if (_isToday(dt.add(const Duration(days: 1)))) {
              dateHeader = 'Yesterday';
            } else {
              dateHeader = DateFormat('EEEE, d MMM yyyy').format(dt);
            }
          } catch (_) {
            dateHeader = dateKey;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date section header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingM,
                  AppTheme.spacingM,
                  AppTheme.spacingM,
                  AppTheme.spacingXS,
                ),
                child: Row(
                  children: [
                    Text(
                      dateHeader,
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${notes.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Voice note cards for this date
              ...notes.map((note) {
                final userId = note['user_id']?.toString() ?? '';
                final senderName = _userNames[userId] ?? 'Worker';

                return VoiceNoteCard(
                  note: note,
                  isReplying: false,
                  onReply: () {
                    // Reply handled externally (not in this read-view)
                  },
                  senderName: senderName,
                  projectName: null, // We're already in the project context
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today,
                size: 14, color: AppTheme.primaryIndigo),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryIndigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
