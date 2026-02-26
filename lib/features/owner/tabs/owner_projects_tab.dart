import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/widgets/responsive_layout.dart';
import 'package:houzzdat_app/features/owner/widgets/owner_project_card.dart';
import 'package:houzzdat_app/features/owner/screens/owner_project_detail.dart';
import 'package:houzzdat_app/features/finance/widgets/finance_charts.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';

class OwnerProjectsTab extends StatefulWidget {
  final String ownerId;
  final String accountId;

  const OwnerProjectsTab({
    super.key,
    required this.ownerId,
    required this.accountId,
  });

  @override
  State<OwnerProjectsTab> createState() => _OwnerProjectsTabState();
}

class _OwnerProjectsTabState extends State<OwnerProjectsTab> with AutomaticKeepAliveClientMixin { // UX-audit #3: preserve tab state
  @override
  bool get wantKeepAlive => true; // UX-audit #3: preserve tab state

  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _projects = [];
  Map<String, Map<String, int>> _projectStats = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch projects linked to this owner
      final result = await _supabase
          .from('project_owners')
          .select('project_id, projects(id, name, location, created_at)')
          .eq('owner_id', widget.ownerId);

      final projects = <Map<String, dynamic>>[];
      final projectIds = <String>[];
      for (final row in result) {
        final proj = row['projects'];
        if (proj != null && proj is Map<String, dynamic>) { // UX-audit CI-04: safe cast
          projects.add(proj);
          projectIds.add(proj['id'].toString());
        }
      }

      // UX-audit CI-05: batch query instead of N+1 per-project action_items lookups
      final stats = <String, Map<String, int>>{};
      if (projectIds.isNotEmpty) {
        final actionItems = await _supabase
            .from('action_items')
            .select('project_id, status')
            .inFilter('project_id', projectIds);

        // Initialize all projects with zero counts
        for (final pid in projectIds) {
          stats[pid] = {'pending': 0, 'inProgress': 0, 'completed': 0};
        }

        // Aggregate in one pass
        for (final item in actionItems) {
          final pid = item['project_id']?.toString() ?? '';
          if (!stats.containsKey(pid)) continue;
          switch (item['status']) {
            case 'pending':
            case 'approved':
              stats[pid]!['pending'] = (stats[pid]!['pending'] ?? 0) + 1;
              break;
            case 'in_progress':
            case 'verifying':
              stats[pid]!['inProgress'] = (stats[pid]!['inProgress'] ?? 0) + 1;
              break;
            case 'completed':
              stats[pid]!['completed'] = (stats[pid]!['completed'] ?? 0) + 1;
              break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _projects = projects;
          _projectStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load projects';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // UX-audit #3: required by AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return const ShimmerLoadingList(itemCount: 4, itemHeight: 120); // UX-audit #4: shimmer instead of spinner
    }

    if (_error != null) {
      return ErrorStateWidget(
        message: _error!,
        onRetry: _loadProjects,
      );
    }

    if (_projects.isEmpty) {
      return EmptyStateWidget( // UX-audit PP-05: premium empty state
        icon: Icons.business_outlined,
        title: 'Your Portfolio Is Being Set Up',
        subtitle: 'Your construction sites will appear here once your manager links them to your account. You\'ll be notified when they\'re ready.',
        // UX-audit #10: actionable empty state
        action: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add First Project'),
        ),
      );
    }

    // UX-audit PP-03: Build project names map for chart
    final projectNames = <String, String>{};
    for (final p in _projects) {
      projectNames[p['id']?.toString() ?? ''] = p['name']?.toString() ?? 'Unknown';
    }

    // PP-11: Responsive layout — grid on tablet, list on phone
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= Breakpoints.tablet;
        final columns = responsiveColumnCount(constraints.maxWidth);

        Widget buildProjectCard(int idx) {
          final project = _projects[idx];
          final projectId = project['id'];
          final stats = _projectStats[projectId] ?? {'pending': 0, 'inProgress': 0, 'completed': 0};

          return OwnerProjectCard(
            project: project,
            pendingCount: stats['pending'] ?? 0,
            inProgressCount: stats['inProgress'] ?? 0,
            completedCount: stats['completed'] ?? 0,
            onTap: () {
              Navigator.push(
                context,
                FadeSlideRoute(
                  page: OwnerProjectDetail(
                    project: project,
                    ownerId: widget.ownerId,
                    accountId: widget.accountId,
                  ),
                ),
              );
            },
          );
        }

        if (isTablet && columns >= 2) {
          // Tablet: chart at top + grid of project cards
          return RefreshIndicator(
            onRefresh: _loadProjects,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: AppTheme.spacingS, bottom: AppTheme.spacingXL),
              child: Column(
                children: [
                  // Chart
                  if (_projectStats.isNotEmpty)
                    ProjectProgressChart(
                      projectStats: _projectStats,
                      projectNames: projectNames,
                    ),
                  // Grid of project cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                    child: AdaptiveGrid(
                      spacing: AppTheme.spacingS,
                      runSpacing: AppTheme.spacingS,
                      children: List.generate(
                        _projects.length,
                        (idx) => buildProjectCard(idx),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Phone: standard list
        return RefreshIndicator(
          onRefresh: _loadProjects,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: AppTheme.spacingS, bottom: AppTheme.spacingXL),
            // UX-audit PP-03: chart + project cards
            itemCount: _projects.length + (_projectStats.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              // UX-audit PP-03: project progress chart at top
              if (_projectStats.isNotEmpty && index == 0) {
                return ProjectProgressChart(
                  projectStats: _projectStats,
                  projectNames: projectNames,
                );
              }
              final adjustedIndex = _projectStats.isNotEmpty ? index - 1 : index;
              return buildProjectCard(adjustedIndex);
            },
          ),
        );
      },
    );
  }
}
