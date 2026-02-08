import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/dashboard/widgets/project_dialogs.dart';
import 'package:intl/intl.dart';

/// Projects/Sites tab with two sub-tabs:
/// 1. Sites — grid of site cards (original ProjectsTab)
/// 2. Attendance — per-site attendance log for all workers
class ProjectsTab extends StatefulWidget {
  final String? accountId;
  const ProjectsTab({super.key, required this.accountId});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab>
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
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return Column(
      children: [
        // Sub-tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryIndigo,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryIndigo,
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
              Tab(text: 'SITES'),
              Tab(text: 'ATTENDANCE'),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SitesSubTab(accountId: widget.accountId!),
              _AttendanceSubTab(accountId: widget.accountId!),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SITES SUB-TAB (original ProjectsTab content)
// ══════════════════════════════════════════════════════════════

class _SitesSubTab extends StatefulWidget {
  final String accountId;
  const _SitesSubTab({required this.accountId});

  @override
  State<_SitesSubTab> createState() => _SitesSubTabState();
}

class _SitesSubTabState extends State<_SitesSubTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;

  @override
  bool get wantKeepAlive => true;

  Stream<List<Map<String, dynamic>>> _getProjectsStream() {
    return _supabase
        .from('projects')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId)
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
        insertData['geofence_radius_m'] =
            int.parse(result['geofenceRadius'] ?? '200');
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
                content: Text(
                    'Project created, but owner needs a password. Skipped owner creation.'),
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
          final errorMsg =
              response.data?['error'] ?? 'Failed to create owner';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Project created, but owner creation failed: $errorMsg'),
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
          const SnackBar(
            content: Text('Could not create site. Please try again.'),
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
      widget.accountId,
    );
  }

  Future<void> _handleEditProject(Map<String, dynamic> project) async {
    final result =
        await ProjectDialogs.showEditProjectDialog(context, project);
    if (result != null) {
      final updateData = <String, dynamic>{
        'name': result['name'],
        'location': result['location'],
      };

      if (result['siteLat'] != null && result['siteLng'] != null) {
        updateData['site_latitude'] = double.parse(result['siteLat']!);
        updateData['site_longitude'] = double.parse(result['siteLng']!);
        updateData['geofence_radius_m'] =
            int.parse(result['geofenceRadius'] ?? '200');
      } else if (result['clearGeofence'] == 'true') {
        updateData['site_latitude'] = null;
        updateData['site_longitude'] = null;
        updateData['geofence_radius_m'] = 200;
      }

      await _supabase
          .from('projects')
          .update(updateData)
          .eq('id', project['id']);
    }
  }

  Future<void> _handleDeleteProject(Map<String, dynamic> project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Site?"),
        content:
            Text("Are you sure you want to delete '${project['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed),
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
      widget.accountId,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
                  subtitle:
                      "Create your first construction site to get started",
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white, size: 18),
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
                              Icon(Icons.delete,
                                  color: AppTheme.errorRed, size: 20),
                              SizedBox(width: AppTheme.spacingS),
                              Text("Delete",
                                  style:
                                      TextStyle(color: AppTheme.errorRed)),
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
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusS),
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

// ══════════════════════════════════════════════════════════════
// ATTENDANCE SUB-TAB (Manager view of worker attendance)
// ══════════════════════════════════════════════════════════════

class _AttendanceSubTab extends StatefulWidget {
  final String accountId;
  const _AttendanceSubTab({required this.accountId});

  @override
  State<_AttendanceSubTab> createState() => _AttendanceSubTabState();
}

class _AttendanceSubTabState extends State<_AttendanceSubTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  // Filter state
  String? _selectedProjectId;
  List<Map<String, dynamic>> _projects = [];
  DateTime _selectedDate = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final data = await _supabase
          .from('projects')
          .select('id, name')
          .eq('account_id', widget.accountId)
          .order('name');

      if (mounted) {
        setState(() {
          _projects = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
        _loadAttendance();
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      // Build date range for selected day
      final dayStart = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      var query = _supabase
          .from('attendance')
          .select(
              'id, user_id, project_id, check_in_at, check_out_at, report_type, report_text, check_in_distance_m, geofence_overridden, users!attendance_user_id_fkey(full_name, email), projects!attendance_project_id_fkey(name)')
          .eq('account_id', widget.accountId)
          .gte('check_in_at', dayStart.toIso8601String())
          .lt('check_in_at', dayEnd.toIso8601String());

      if (_selectedProjectId != null) {
        query = query.eq('project_id', _selectedProjectId!);
      }

      final data = await query.order('check_in_at', ascending: false);

      if (mounted) {
        setState(() {
          _records = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? isoStr) {
    if (isoStr == null) return '--';
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '--';
    return DateFormat('h:mm a').format(dt.toLocal());
  }

  String _calcDuration(String? checkIn, String? checkOut) {
    if (checkIn == null) return '--';
    final start = DateTime.tryParse(checkIn);
    if (start == null) return '--';
    final end = checkOut != null
        ? DateTime.tryParse(checkOut) ?? DateTime.now()
        : DateTime.now();
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  String _getWorkerName(Map<String, dynamic> record) {
    final user = record['users'];
    if (user is Map) {
      return user['full_name']?.toString() ??
          user['email']?.toString() ??
          'Unknown';
    }
    return 'Unknown';
  }

  String _getProjectName(Map<String, dynamic> record) {
    final project = record['projects'];
    if (project is Map) {
      return project['name']?.toString() ?? 'Unknown Site';
    }
    return 'Unknown Site';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Filters row
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
          color: Colors.white,
          child: Row(
            children: [
              // Date picker chip
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
                        _isToday(_selectedDate)
                            ? 'Today'
                            : DateFormat('MMM d').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Site filter dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedProjectId,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('All Sites',
                          style: TextStyle(fontSize: 13)),
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Sites'),
                        ),
                        ..._projects.map((p) => DropdownMenuItem<String?>(
                              value: p['id']?.toString(),
                              child: Text(
                                p['name']?.toString() ?? 'Site',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedProjectId = val);
                        _loadAttendance();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Summary bar
        if (!_isLoading && _records.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM, vertical: 10),
            color: AppTheme.primaryIndigo.withValues(alpha: 0.04),
            child: Row(
              children: [
                _summaryChip(
                  Icons.people,
                  '${_uniqueWorkerCount()} workers',
                  AppTheme.primaryIndigo,
                ),
                const SizedBox(width: 12),
                _summaryChip(
                  Icons.login,
                  '${_records.length} check-ins',
                  AppTheme.successGreen,
                ),
                const SizedBox(width: 12),
                _summaryChip(
                  Icons.schedule,
                  '${_stillOnSiteCount()} on site',
                  AppTheme.warningOrange,
                ),
              ],
            ),
          ),

        // Records list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryIndigo))
              : _records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy,
                              size: 48,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No attendance records',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isToday(_selectedDate)
                                ? 'No workers have checked in today'
                                : 'No records for ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAttendance,
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.all(AppTheme.spacingM),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _buildAttendanceCard(_records[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  int _uniqueWorkerCount() {
    return _records.map((r) => r['user_id']).toSet().length;
  }

  int _stillOnSiteCount() {
    return _records.where((r) => r['check_out_at'] == null).length;
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final workerName = _getWorkerName(record);
    final projectName = _getProjectName(record);
    final checkIn = record['check_in_at']?.toString();
    final checkOut = record['check_out_at']?.toString();
    final isOnSite = checkOut == null;
    final reportType = record['report_type']?.toString();
    final distance = record['check_in_distance_m'];
    final overridden = record['geofence_overridden'] == true;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Status color bar
            Container(
              width: 4,
              color: isOnSite ? AppTheme.successGreen : Colors.grey.shade300,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Worker name + status badge
                    Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryIndigo
                              .withValues(alpha: 0.1),
                          child: Text(
                            workerName.isNotEmpty
                                ? workerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppTheme.primaryIndigo,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workerName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                projectName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOnSite
                                ? AppTheme.successGreen
                                    .withValues(alpha: 0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOnSite ? 'ON SITE' : 'CHECKED OUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isOnSite
                                  ? AppTheme.successGreen
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Time details row
                    Row(
                      children: [
                        // Check-in time
                        _timeDetail(
                            Icons.login, 'In', _formatTime(checkIn),
                            AppTheme.successGreen),
                        const SizedBox(width: 16),
                        // Check-out time
                        _timeDetail(
                            Icons.logout,
                            'Out',
                            isOnSite ? '--' : _formatTime(checkOut),
                            isOnSite
                                ? Colors.grey.shade400
                                : AppTheme.errorRed),
                        const SizedBox(width: 16),
                        // Duration
                        _timeDetail(Icons.schedule, 'Duration',
                            _calcDuration(checkIn, checkOut),
                            AppTheme.primaryIndigo),
                        const Spacer(),
                        // Badges
                        if (overridden)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'EXEMPT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        if (reportType != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: reportType == 'voice'
                                  ? AppTheme.primaryIndigo
                                      .withValues(alpha: 0.1)
                                  : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  reportType == 'voice'
                                      ? Icons.mic
                                      : Icons.edit_note,
                                  size: 10,
                                  color: reportType == 'voice'
                                      ? AppTheme.primaryIndigo
                                      : Colors.amber.shade800,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  reportType == 'voice'
                                      ? 'Voice'
                                      : 'Text',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: reportType == 'voice'
                                        ? AppTheme.primaryIndigo
                                        : Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Distance info
                    if (distance != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Check-in distance: ${(distance as num).round()}m from site centre',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeDetail(
      IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
