import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// User card matching the kanban view _UserCard design and functionality exactly.
/// Includes: avatar, email, role/project badges, and "SEND VOICE NOTE" action bar.
/// Optionally supports an onEdit callback (accessible via long-press on the card).
class TeamCardWidget extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final bool isRecording;
  final VoidCallback? onSendVoiceNote;

  const TeamCardWidget({
    super.key,
    required this.user,
    required this.onEdit,
    this.isRecording = false,
    this.onSendVoiceNote,
  });

  @override
  State<TeamCardWidget> createState() => _TeamCardWidgetState();
}

class _TeamCardWidgetState extends State<TeamCardWidget> {
  String? _projectName;

  @override
  void initState() {
    super.initState();
    if (widget.user['current_project_id'] != null) {
      _fetchProjectName();
    }
  }

  Future<void> _fetchProjectName() async {
    try {
      final project = await Supabase.instance.client
          .from('projects')
          .select('name')
          .eq('id', widget.user['current_project_id'])
          .single();

      if (mounted) {
        setState(() => _projectName = project['name']);
      }
    } catch (e) {
      debugPrint('Error fetching project: $e');
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'manager':
      case 'admin':
        return AppTheme.infoBlue;
      case 'worker':
        return AppTheme.primaryIndigo;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'] ?? 'worker';
    final email = widget.user['email'] ?? 'User';
    final roleColor = _getRoleColor(role);

    return GestureDetector(
      onLongPress: widget.onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            // User Info
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: roleColor,
                    child: Text(
                      email[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppTheme.spacingM),

                  // User Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CategoryBadge(
                              text: role.toUpperCase(),
                              color: roleColor,
                            ),
                            if (_projectName != null) ...[
                              const SizedBox(width: AppTheme.spacingS),
                              CategoryBadge(
                                text: _projectName!,
                                color: AppTheme.successGreen,
                                icon: Icons.location_on_rounded,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Send Voice Note Button
            if (widget.onSendVoiceNote != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onSendVoiceNote,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.radiusXL),
                      bottomRight: Radius.circular(AppTheme.radiusXL),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: widget.isRecording
                                ? AppTheme.errorRed
                                : AppTheme.primaryIndigo,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            widget.isRecording
                                ? 'STOP & SEND'
                                : 'SEND VOICE NOTE',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.isRecording
                                  ? AppTheme.errorRed
                                  : AppTheme.primaryIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
