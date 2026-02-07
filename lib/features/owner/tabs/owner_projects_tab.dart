import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/owner/widgets/owner_project_card.dart';
import 'package:houzzdat_app/features/owner/screens/owner_project_detail.dart';

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

class _OwnerProjectsTabState extends State<OwnerProjectsTab> {
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
      for (final row in result) {
        if (row['projects'] != null) {
          projects.add(row['projects'] as Map<String, dynamic>);
        }
      }

      // Load action item stats for each project
      final stats = <String, Map<String, int>>{};
      for (final project in projects) {
        final projectId = project['id'];
        final actionItems = await _supabase
            .from('action_items')
            .select('status')
            .eq('project_id', projectId);

        int pending = 0, inProgress = 0, completed = 0;
        for (final item in actionItems) {
          switch (item['status']) {
            case 'pending':
            case 'approved':
              pending++;
              break;
            case 'in_progress':
            case 'verifying':
              inProgress++;
              break;
            case 'completed':
              completed++;
              break;
          }
        }
        stats[projectId] = {
          'pending': pending,
          'inProgress': inProgress,
          'completed': completed,
        };
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
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading projects...');
    }

    if (_error != null) {
      return ErrorStateWidget(
        message: _error!,
        onRetry: _loadProjects,
      );
    }

    if (_projects.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.business_outlined,
        title: 'No Projects',
        subtitle: 'You have no projects linked to your account yet. Ask your manager to add you.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: AppTheme.spacingM, bottom: AppTheme.spacingXL),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
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
                MaterialPageRoute(
                  builder: (context) => OwnerProjectDetail(
                    project: project,
                    ownerId: widget.ownerId,
                    accountId: widget.accountId,
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
