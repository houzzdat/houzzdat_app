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
    if (result == null) return;

    try {
      // 1. Insert the project
      final insertData = <String, dynamic>{
        'name': result['name'],
        'location': result['location'],
        'account_id': widget.accountId,
      };

      // Geofence coordinates
      if (result['siteLat'] != null && result['siteLng'] != null) {
        insertData['site_latitude'] = double.parse(result['siteLat']!);
        insertData['site_longitude'] = double.parse(result['siteLng']!);
        insertData['geofence_radius_m'] = int.parse(result['geofenceRadius'] ?? '200');
      }

      final projectResponse = await _supabase
          .from('projects')
          .insert(insertData)
          .select('id')
          .single();

      final projectId = projectResponse['id'] as String;

      // 2. Handle owner linking if owner info was provided
      final existingOwnerId = result['existingOwnerId'];
      final ownerEmail = result['ownerEmail'];
      final ownerPhone = result['ownerPhone'];

      if (existingOwnerId != null && existingOwnerId.isNotEmpty) {
        // Link existing owner to project
        await _supabase.from('project_owners').insert({
          'project_id': projectId,
          'owner_id': existingOwnerId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project created and linked to existing owner'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else if (ownerEmail != null && ownerEmail.isNotEmpty) {
        // Create new owner via invite-user edge function
        final ownerName = result['ownerName'] ?? '';
        final ownerPassword = result['ownerPassword'] ?? '';

        if (ownerPassword.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project created, but owner needs a password. Skipped owner creation.'),
                backgroundColor: AppTheme.warningOrange,
              ),
            );
          }
          return;
        }

        final response = await _supabase.functions.invoke(
          'invite-user',
          body: {
            'email': ownerEmail,
            'password': ownerPassword,
            'role': 'owner',
            'account_id': widget.accountId,
            'full_name': ownerName,
            if (ownerPhone != null && ownerPhone.isNotEmpty)
              'phone_number': ownerPhone,
          },
        );

        if (response.status == 200) {
          final newUserId = response.data?['user_id'];
          if (newUserId != null) {
            await _supabase.from('project_owners').insert({
              'project_id': projectId,
              'owner_id': newUserId,
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project created with new owner account'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } else {
          final errorMsg = response.data?['error'] ?? 'Failed to create owner';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Project created, but owner creation failed: $errorMsg'),
                backgroundColor: AppTheme.warningOrange,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error creating project: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not delete site. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleAssignOwner(Map<String, dynamic> project) async {
    await ProjectDialogs.showAssignOwnerDialog(
      context,
      project,
      widget.accountId ?? '',
    );
  }

  Future<void> _handleEditProject(Map<String, dynamic> project) async {
    final result = await ProjectDialogs.showEditProjectDialog(context, project);
    if (result != null) {
      final updateData = <String, dynamic>{
        'name': result['name'],
        'location': result['location'],
      };

      // Geofence coordinates
      if (result['siteLat'] != null && result['siteLng'] != null) {
        updateData['site_latitude'] = double.parse(result['siteLat']!);
        updateData['site_longitude'] = double.parse(result['siteLng']!);
        updateData['geofence_radius_m'] = int.parse(result['geofenceRadius'] ?? '200');
      } else if (result['clearGeofence'] == 'true') {
        updateData['site_latitude'] = null;
        updateData['site_longitude'] = null;
        updateData['geofence_radius_m'] = 200;
      }

      await _supabase.from('projects').update(updateData).eq('id', project['id']);
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
                    onAssignOwner: () => _handleAssignOwner(project),
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