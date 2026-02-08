import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
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
      final insertData = <String, dynamic>{
        'name': result['name'],
        'location': result['location'],
        'account_id': widget.accountId,
      };

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

      final existingOwnerId = result['existingOwnerId'];
      final ownerEmail = result['ownerEmail'];
      final ownerPhone = result['ownerPhone'];

      if (existingOwnerId != null && existingOwnerId.isNotEmpty) {
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
            content: const Text('Could not create site. Please try again.'),
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

              // Two-column grid layout
              return GridView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppTheme.spacingM,
                  mainAxisSpacing: AppTheme.spacingM,
                  childAspectRatio: 1.0, // Square cards
                ),
                itemCount: snap.data!.length,
                itemBuilder: (context, i) {
                  final project = snap.data![i];
                  return _SiteGridCard(
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

/// Square site card with photo thumbnail for 2-column grid layout
class _SiteGridCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssignUsers;
  final VoidCallback onAssignOwner;

  const _SiteGridCard({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignUsers,
    required this.onAssignOwner,
  });

  @override
  State<_SiteGridCard> createState() => _SiteGridCardState();
}

class _SiteGridCardState extends State<_SiteGridCard> {
  int _userCount = 0;
  String? _sitePhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserCount();
    _fetchSitePhoto();
  }

  Future<void> _fetchUserCount() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('current_project_id', widget.project['id']);

      if (mounted) {
        setState(() => _userCount = response.length);
      }
    } catch (e) {
      debugPrint('Error fetching user count: $e');
    }
  }

  Future<void> _fetchSitePhoto() async {
    try {
      // Try to get the latest proof photo from action items for this project
      final response = await Supabase.instance.client
          .from('action_items')
          .select('proof_photo_url')
          .eq('project_id', widget.project['id'])
          .not('proof_photo_url', 'is', null)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted && response != null && response['proof_photo_url'] != null) {
        setState(() => _sitePhotoUrl = response['proof_photo_url']);
      }
    } catch (e) {
      debugPrint('Error fetching site photo: $e');
    }

    // Also check project's own photo_url field if available
    if (_sitePhotoUrl == null && widget.project['photo_url'] != null) {
      setState(() => _sitePhotoUrl = widget.project['photo_url']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo thumbnail area (top half)
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo or placeholder
                if (_sitePhotoUrl != null)
                  Image.network(
                    _sitePhotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
                  )
                else
                  _buildPhotoPlaceholder(),

                // Menu button overlay
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton(
                      iconSize: 20,
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'assign',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, size: 20),
                              SizedBox(width: AppTheme.spacingS),
                              Text("Assign Users"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'assign_owner',
                          child: Row(
                            children: [
                              Icon(Icons.supervisor_account, size: 20),
                              SizedBox(width: AppTheme.spacingS),
                              Text("Assign Owner"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: AppTheme.spacingS),
                              Text("Edit"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: AppTheme.errorRed, size: 20),
                              SizedBox(width: AppTheme.spacingS),
                              Text("Delete", style: TextStyle(color: AppTheme.errorRed)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'assign':
                            widget.onAssignUsers();
                            break;
                          case 'assign_owner':
                            widget.onAssignOwner();
                            break;
                          case 'edit':
                            widget.onEdit();
                            break;
                          case 'delete':
                            widget.onDelete();
                            break;
                        }
                      },
                    ),
                  ),
                ),

                // User count badge overlay
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_userCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Site info (bottom portion)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.project['name'] ?? 'Site',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.project['location'] != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.project['location'],
                            style: AppTheme.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: AppTheme.surfaceGrey,
      child: const Center(
        child: Icon(
          Icons.business_rounded,
          size: 40,
          color: AppTheme.primaryIndigo,
        ),
      ),
    );
  }
}
