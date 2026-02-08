import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/dashboard/widgets/team_card_widget.dart';
import 'package:houzzdat_app/features/dashboard/widgets/team_dialogs.dart';
import 'package:houzzdat_app/features/dashboard/widgets/role_management_dialog.dart';

class TeamTab extends StatefulWidget {
  final String? accountId;
  const TeamTab({super.key, required this.accountId});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();

  String? _recordingForUserId;

  Stream<List<Map<String, dynamic>>> _getTeamStream() {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return Stream.value([]);
    }

    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId!)
        .order('role');
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
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getTeamStream(),
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
                  icon: Icons.people,
                  title: "No team members yet",
                  subtitle: "Invite your first team member to get started",
                  action: ActionButton(
                    label: "Invite First Member",
                    icon: Icons.person_add,
                    onPressed: _handleInviteStaff,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: snap.data!.length,
                itemBuilder: (context, i) {
                  final user = snap.data![i];
                  final isRecording = _recordingForUserId == user['id'];
                  return TeamCardWidget(
                    user: user,
                    onEdit: () => _handleEditUser(user),
                    isRecording: isRecording,
                    onSendVoiceNote: () => _handleSendVoiceNote(user),
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
