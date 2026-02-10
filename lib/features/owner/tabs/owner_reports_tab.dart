import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/owner/screens/owner_report_view_screen.dart';

/// Tab that lists all reports sent to the owner.
class OwnerReportsTab extends StatefulWidget {
  final String ownerId;
  final String accountId;

  const OwnerReportsTab({
    super.key,
    required this.ownerId,
    required this.accountId,
  });

  @override
  State<OwnerReportsTab> createState() => _OwnerReportsTabState();
}

class _OwnerReportsTabState extends State<OwnerReportsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  Set<String> _ownerProjectIds = {};
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _channel = _supabase.channel('owner-reports-${widget.ownerId}');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reports',
          callback: (payload) {
            // Reload when any report changes
            _loadReports();
          },
        )
        .subscribe();
  }

  Future<void> _loadReports() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Fetch owner's project IDs
      final projectOwners = await _supabase
          .from('project_owners')
          .select('project_id')
          .eq('owner_id', widget.ownerId);

      _ownerProjectIds = (projectOwners as List)
          .map((po) => po['project_id'].toString())
          .toSet();

      // 2. Fetch all sent reports for this account
      final reportsData = await _supabase
          .from('reports')
          .select('*, users!reports_created_by_fkey(full_name)')
          .eq('account_id', widget.accountId)
          .eq('owner_report_status', 'sent')
          .order('sent_at', ascending: false);

      // 3. Filter: keep reports where project_ids is empty (all projects)
      //    or any of project_ids overlaps with owner's project IDs
      final filtered = <Map<String, dynamic>>[];
      for (final report in reportsData) {
        final projectIds = (report['project_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        if (projectIds.isEmpty) {
          // All-projects report — visible to all owners
          filtered.add(Map<String, dynamic>.from(report));
        } else {
          // Check if any of the report's projects belong to this owner
          final hasOverlap =
              projectIds.any((pid) => _ownerProjectIds.contains(pid));
          if (hasOverlap) {
            filtered.add(Map<String, dynamic>.from(report));
          }
        }
      }

      // 4. Enrich with project names for display
      Map<String, String> projectNameCache = {};
      for (final report in filtered) {
        final projectIds = (report['project_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        if (projectIds.isEmpty) {
          report['_project_names'] = 'All Sites';
        } else {
          final names = <String>[];
          for (final pid in projectIds) {
            if (!projectNameCache.containsKey(pid)) {
              try {
                final p = await _supabase
                    .from('projects')
                    .select('name')
                    .eq('id', pid)
                    .maybeSingle();
                projectNameCache[pid] = p?['name']?.toString() ?? 'Site';
              } catch (_) {
                projectNameCache[pid] = 'Site';
              }
            }
            names.add(projectNameCache[pid]!);
          }
          report['_project_names'] = names.join(', ');
        }
      }

      if (mounted) {
        setState(() {
          _reports = filtered;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading owner reports: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load reports';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading reports...');
    }

    if (_error != null) {
      return ErrorStateWidget(
        message: _error!,
        onRetry: _loadReports,
      );
    }

    if (_reports.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.assessment_outlined,
        title: 'No Reports Yet',
        subtitle:
            'No reports have been shared with you yet. Reports from your manager will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: AppTheme.spacingM,
          bottom: AppTheme.spacingXL,
        ),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          return _OwnerReportCard(
            report: _reports[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OwnerReportViewScreen(
                    report: _reports[index],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// Owner Report Card — simplified version for the owner view
// ============================================================
class _OwnerReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _OwnerReportCard({
    required this.report,
    required this.onTap,
  });

  String get _dateLabel {
    final startDate = report['start_date']?.toString() ?? '';
    final endDate = report['end_date']?.toString() ?? '';
    final reportType = report['report_type']?.toString() ?? 'daily';

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final fmt = DateFormat('d MMM yyyy');

      if (reportType == 'daily' || startDate == endDate) {
        return 'Progress Report \u2014 ${fmt.format(start)}';
      } else {
        return 'Progress Report \u2014 ${fmt.format(start)} to ${fmt.format(end)}';
      }
    } catch (_) {
      return 'Progress Report';
    }
  }

  String get _sentLabel {
    final sentAt = report['sent_at']?.toString();
    if (sentAt == null) return '';
    try {
      final dt = DateTime.parse(sentAt);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 60) {
        return 'Received ${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return 'Received ${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return 'Received ${diff.inDays}d ago';
      } else {
        return 'Received ${DateFormat('d MMM').format(dt)}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdBy = report['users']?['full_name']?.toString() ?? 'Manager';
    final projectNames = report['_project_names']?.toString() ?? 'All Sites';
    final reportType = report['report_type']?.toString() ?? 'daily';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(
                    Icons.assessment_outlined,
                    color: AppTheme.primaryIndigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From $createdBy',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                CategoryBadge(
                  text: reportType == 'daily'
                      ? 'Daily'
                      : reportType == 'weekly'
                          ? 'Weekly'
                          : 'Custom',
                  color: AppTheme.infoBlue,
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingS),

            // Sites + sent time
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    projectNames,
                    style: AppTheme.caption.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  _sentLabel,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingXS),

            // Arrow
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
