import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/dashboard/widgets/project_dialogs.dart';

class SitesManagementTab extends StatefulWidget {
  final String accountId;
  
  const SitesManagementTab({super.key, required this.accountId});

  @override
  State<SitesManagementTab> createState() => _SitesManagementTabState();
}

class _SitesManagementTabState extends State<SitesManagementTab> {
  final _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> _getProjectsStream() {
    return _supabase
        .from('projects')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId)
        .order('name');
  }

  Future<void> _handleAddSite() async {
    final result = await ProjectDialogs.showAddProjectDialog(context);
    if (result != null) {
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

      await _supabase.from('projects').insert(insertData);
    }
  }

  Future<void> _handleDeleteSite(Map<String, dynamic> project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Site?'),
        content: Text(
          'Are you sure you want to delete "${project['name']}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('projects').delete().eq('id', project['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Site deleted'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROJECT SITES',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryIndigo,
                ),
              ),
              FloatingActionButton.small(
                onPressed: _handleAddSite,
                backgroundColor: AppTheme.primaryIndigo,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        
        // Sites List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getProjectsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingWidget(message: 'Loading sites...');
              }

              if (snapshot.hasError) {
                return ErrorStateWidget(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(() {}),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.business_rounded,
                  title: 'No sites yet',
                  subtitle: 'Create your first construction site',
                  action: ActionButton(
                    label: 'Create Site',
                    icon: Icons.add,
                    onPressed: _handleAddSite,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return _SiteCard(
                    project: snapshot.data![index],
                    onDelete: () => _handleDeleteSite(snapshot.data![index]),
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

class _SiteCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final VoidCallback onDelete;

  const _SiteCard({
    required this.project,
    required this.onDelete,
  });

  @override
  State<_SiteCard> createState() => _SiteCardState();
}

class _SiteCardState extends State<_SiteCard> {
  int _userCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserCount();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: Colors.black.withValues(alpha:0.05),
        ),
      ),
      child: Row(
        children: [
          // Map Pin Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppTheme.primaryIndigo,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingM),
          
          // Site Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.project['name'] ?? 'Site',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.project['location'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.project['location'],
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // User Count
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_rounded,
                  size: 16,
                  color: AppTheme.primaryIndigo,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_userCount',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryIndigo,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingM),
          
          // Delete Button
          IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.errorRed,
            ),
          ),
        ],
      ),
    );
  }
}