import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/dashboard/widgets/team_card_widget.dart';
import 'package:houzzdat_app/features/dashboard/widgets/team_dialogs.dart';

class TeamTab extends StatefulWidget {
  final String? accountId;
  const TeamTab({super.key, required this.accountId});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  final _supabase = Supabase.instance.client;

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
        const SnackBar(content: Text('✅ User invited successfully!')),
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

  @override
  Widget build(BuildContext context) {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return Column(
      children: [
        SectionHeader(
          title: "Team Management",
          trailing: ActionButton(
            label: "Invite User",
            icon: Icons.person_add,
            onPressed: _handleInviteStaff,
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
                padding: const EdgeInsets.all(AppTheme.spacingS),
                itemCount: snap.data!.length,
                itemBuilder: (context, i) {
                  final user = snap.data![i];
                  return TeamCardWidget(
                    user: user,
                    onEdit: () => _handleEditUser(user),
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