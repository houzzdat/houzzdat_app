import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/dashboard/widgets/team_card_widget.dart';
import 'package:houzzdat_app/features/dashboard/widgets/team_dialogs.dart';
import 'package:houzzdat_app/features/dashboard/widgets/role_management_dialog.dart';
import 'package:houzzdat_app/features/dashboard/widgets/user_action_dialogs.dart';

class TeamTab extends StatefulWidget {
  final String? accountId;
  const TeamTab({super.key, required this.accountId});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();

  late TabController _tabController;
  String? _recordingForUserId;

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

  /// Get team members stream filtered by status.
  /// Queries user_company_associations joined with user data.
  Stream<List<Map<String, dynamic>>> _getTeamStream(String statusFilter) {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return Stream.value([]);
    }

    // Use the associations table for status-aware queries
    return _supabase
        .from('user_company_associations')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId!)
        .order('role');
  }

  /// Load user details (email, etc.) for a list of associations.
  /// This is needed because Supabase streams don't support joins.
  Future<List<Map<String, dynamic>>> _enrichAssociations(
      List<Map<String, dynamic>> associations, String statusFilter) async {
    // Filter by status client-side (stream doesn't support multi-eq)
    final filtered =
        associations.where((a) => a['status'] == statusFilter).toList();

    if (filtered.isEmpty) return [];

    // Get user IDs
    final userIds = filtered.map((a) => a['user_id'] as String).toList();

    // Fetch user details
    try {
      final users = await _supabase
          .from('users')
          .select('id, email, full_name, phone_number, current_project_id, geofence_exempt')
          .inFilter('id', userIds);

      // Create a map for quick lookup
      final userMap = <String, Map<String, dynamic>>{};
      for (final u in users) {
        userMap[u['id']] = u;
      }

      // Merge association data with user data
      return filtered.map((assoc) {
        final userData = userMap[assoc['user_id']] ?? {};
        return {
          ...userData,
          'id': assoc['user_id'],
          'role': assoc['role'],
          'status': assoc['status'],
          'association_id': assoc['id'],
          'deactivated_at': assoc['deactivated_at'],
          'is_primary': assoc['is_primary'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error enriching associations: $e');
      return filtered;
    }
  }

  Future<void> _handleInviteStaff() async {
    final result = await TeamDialogs.showInviteStaffDialog(
      context,
      widget.accountId ?? '',
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User invited successfully!')),
      );
    }
  }

  Future<void> _handleEditUser(Map<String, dynamic> user) async {
    await TeamDialogs.showEditUserDialog(
      context,
      user,
      widget.accountId ?? '',
    );
  }

  Future<void> _handleManageRoles() async {
    await showDialog(
      context: context,
      builder: (context) => RoleManagementDialog(
        accountId: widget.accountId ?? '',
      ),
    );
  }

  Future<void> _handleSendVoiceNote(Map<String, dynamic> user) async {
    final userId = user['id'];
    final projectId = user['current_project_id'];

    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['email']} is not assigned to a project'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    // Start recording
    if (_recordingForUserId == null) {
      await _recorderService.startRecording();
      setState(() => _recordingForUserId = userId);
    } else if (_recordingForUserId == userId) {
      // Stop recording for this user
      setState(() => _recordingForUserId = null);

      final bytes = await _recorderService.stopRecording();

      if (bytes != null) {
        await _recorderService.uploadAudio(
          bytes: bytes,
          projectId: projectId,
          userId: _supabase.auth.currentUser!.id,
          accountId: widget.accountId!,
          recipientId: userId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice note sent to ${user['email']}'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDeactivateUser(Map<String, dynamic> user) async {
    final userName = user['email'] ?? 'User';
    final confirmed =
        await UserActionDialogs.showDeactivateDialog(context, userName);

    if (confirmed == true) {
      try {
        final response = await _supabase.functions.invoke(
          'manage-user-status',
          body: {
            'action': 'deactivate',
            'target_user_id': user['id'],
            'account_id': widget.accountId,
            'actor_id': _supabase.auth.currentUser!.id,
          },
        );

        if (response.status == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName has been deactivated'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        } else if (mounted) {
          final error = response.data?['error'] ?? 'Failed to deactivate user';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleActivateUser(Map<String, dynamic> user) async {
    final userName = user['email'] ?? 'User';
    final confirmed =
        await UserActionDialogs.showActivateDialog(context, userName);

    if (confirmed == true) {
      try {
        final response = await _supabase.functions.invoke(
          'manage-user-status',
          body: {
            'action': 'activate',
            'target_user_id': user['id'],
            'account_id': widget.accountId,
            'actor_id': _supabase.auth.currentUser!.id,
          },
        );

        if (response.status == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName has been reactivated'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else if (mounted) {
          final error = response.data?['error'] ?? 'Failed to activate user';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRemoveUser(Map<String, dynamic> user) async {
    final userName = user['email'] ?? 'User';
    final confirmed =
        await UserActionDialogs.showRemoveDialog(context, userName);

    if (confirmed == true) {
      try {
        final response = await _supabase.functions.invoke(
          'manage-user-status',
          body: {
            'action': 'remove',
            'target_user_id': user['id'],
            'account_id': widget.accountId,
            'actor_id': _supabase.auth.currentUser!.id,
          },
        );

        if (response.status == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName has been removed from the company'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else if (mounted) {
          final error = response.data?['error'] ?? 'Failed to remove user';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return Column(
      children: [
        SectionHeader(
          title: "Team Management",
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.badge, size: 18),
                label: const Text("Manage Roles"),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryIndigo,
                ),
                onPressed: _handleManageRoles,
              ),
              const SizedBox(width: AppTheme.spacingS),
              ActionButton(
                label: "Invite User",
                icon: Icons.person_add,
                onPressed: _handleInviteStaff,
                isCompact: true,
              ),
            ],
          ),
        ),
        // Active / Inactive tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryIndigo,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryIndigo,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 18),
                    SizedBox(width: 6),
                    Text('Active'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 18),
                    SizedBox(width: 6),
                    Text('Inactive'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserList('active'),
              _buildUserList('inactive'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(String statusFilter) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getTeamStream(statusFilter),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading team members...');
        }

        if (snap.hasError) {
          return ErrorStateWidget(
            message: snap.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        if (!snap.hasData || snap.data!.isEmpty) {
          return EmptyStateWidget(
            icon: statusFilter == 'active' ? Icons.people : Icons.person_off,
            title: statusFilter == 'active'
                ? "No active team members"
                : "No inactive members",
            subtitle: statusFilter == 'active'
                ? "Invite your first team member to get started"
                : "Deactivated members will appear here",
            action: statusFilter == 'active'
                ? ActionButton(
                    label: "Invite First Member",
                    icon: Icons.person_add,
                    onPressed: _handleInviteStaff,
                  )
                : null,
          );
        }

        // Enrich association data with user details
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _enrichAssociations(snap.data!, statusFilter),
          builder: (context, enrichedSnap) {
            if (enrichedSnap.connectionState == ConnectionState.waiting) {
              return const LoadingWidget(message: 'Loading team details...');
            }

            final users = enrichedSnap.data ?? [];
            if (users.isEmpty) {
              return EmptyStateWidget(
                icon: statusFilter == 'active'
                    ? Icons.people
                    : Icons.person_off,
                title: statusFilter == 'active'
                    ? "No active team members"
                    : "No inactive members",
                subtitle: statusFilter == 'active'
                    ? "Invite your first team member to get started"
                    : "Deactivated members will appear here",
              );
            }

            // Group by role
            final grouped = _groupByRole(users);

            return ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: grouped.length,
              itemBuilder: (context, i) {
                final item = grouped[i];

                // Role header
                if (item['_isHeader'] == true) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      top: AppTheme.spacingM,
                      bottom: AppTheme.spacingS,
                    ),
                    child: Text(
                      (item['_role'] as String).toUpperCase(),
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  );
                }

                // User card
                final user = item;
                final isRecording = _recordingForUserId == user['id'];
                final userRole =
                    (user['role'] ?? 'worker').toString().toLowerCase();
                final isAdmin = userRole == 'admin';

                return TeamCardWidget(
                  user: user,
                  onEdit: () => _handleEditUser(user),
                  isRecording: isRecording,
                  onSendVoiceNote: statusFilter == 'active'
                      ? () => _handleSendVoiceNote(user)
                      : null,
                  status: statusFilter,
                  isAdminUser: isAdmin,
                  onDeactivate: () => _handleDeactivateUser(user),
                  onActivate: () => _handleActivateUser(user),
                  onRemove: () => _handleRemoveUser(user),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Groups users by role and inserts header items.
  List<Map<String, dynamic>> _groupByRole(List<Map<String, dynamic>> users) {
    // Sort by role
    users.sort((a, b) {
      final roleA = (a['role'] ?? 'worker').toString().toLowerCase();
      final roleB = (b['role'] ?? 'worker').toString().toLowerCase();
      // Priority order: admin > manager > owner > worker > others
      const roleOrder = {'admin': 0, 'manager': 1, 'owner': 2, 'worker': 3};
      final orderA = roleOrder[roleA] ?? 4;
      final orderB = roleOrder[roleB] ?? 4;
      return orderA.compareTo(orderB);
    });

    final result = <Map<String, dynamic>>[];
    String? currentRole;

    for (final user in users) {
      final role = (user['role'] ?? 'worker').toString();
      if (role != currentRole) {
        currentRole = role;
        result.add({
          '_isHeader': true,
          '_role': role,
        });
      }
      result.add(user);
    }

    return result;
  }
}
