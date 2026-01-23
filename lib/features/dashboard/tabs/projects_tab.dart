import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/dashboard/widgets/project_card_widget.dart';
import 'package:houzzdat_app/features/dashboard/widgets/project_dialogs.dart';

class ProjectsTab extends StatefulWidget {
  final String? accountId;
  const ProjectsTab({super.key, required this.accountId});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> _getProjectsStream() {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return Stream.value([]);
    }

    return _supabase
        .from('projects')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId!)
        .order('name');
  }

  Future<void> _handleAddProject() async {
    final result = await ProjectDialogs.showAddProjectDialog(context);
    if (result != null) {
      await _supabase.from('projects').insert({
        'name': result['name'],
        'location': result['location'],
        'account_id': widget.accountId,
      });
    }
  }

  Future<void> _handleEditProject(Map<String, dynamic> project) async {
    final result = await ProjectDialogs.showEditProjectDialog(context, project);
    if (result != null) {
      await _supabase.from('projects').update({
        'name': result['name'],
        'location': result['location'],
      }).eq('id', project['id']);
    }
  }

  Future<void> _handleDeleteProject(Map<String, dynamic> project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Site?"),
        content: Text("Are you sure you want to delete '${project['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('projects').delete().eq('id', project['id']);
    }
  }

  Future<void> _handleAssignUsers(Map<String, dynamic> project) async {
    await ProjectDialogs.showAssignUserDialog(
      context,
      project,
      widget.accountId ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return Column(
      children: [
        SectionHeader(
          title: "Site Management",
          trailing: ActionButton(
            label: "New Site",
            icon: Icons.add,
            onPressed: _handleAddProject,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getProjectsStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingWidget(message: 'Loading sites...');
              }

              if (snap.hasError) {
                return ErrorStateWidget(
                  message: snap.error.toString(),
                  onRetry: () => setState(() {}),
                );
              }

              if (!snap.hasData || snap.data!.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.business,
                  title: "No sites yet",
                  subtitle: "Create your first construction site to get started",
                  action: ActionButton(
                    label: "Create First Site",
                    icon: Icons.add,
                    onPressed: _handleAddProject,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                itemCount: snap.data!.length,
                itemBuilder: (context, i) {
                  final project = snap.data![i];
                  return ProjectCardWidget(
                    project: project,
                    onEdit: () => _handleEditProject(project),
                    onDelete: () => _handleDeleteProject(project),
                    onAssignUsers: () => _handleAssignUsers(project),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}