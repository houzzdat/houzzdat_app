import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// User card matching the kanban view _UserCard design and functionality.
/// Includes: avatar with status dot, email, role/project badges, action menu,
/// and "SEND VOICE NOTE" action bar.
/// Supports active/inactive user states with appropriate visual feedback.
class TeamCardWidget extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final bool isRecording;
  final VoidCallback? onSendVoiceNote;

  /// User status: 'active' or 'inactive'
  final String status;

  /// Callbacks for user management actions
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;
  final VoidCallback? onRemove;

  /// Whether this user's role is 'admin' (prevents deactivate/remove)
  final bool isAdminUser;

  /// Whether this user is currently on site (has an open attendance session today)
  final bool isOnSite;

  const TeamCardWidget({
    super.key,
    required this.user,
    required this.onEdit,
    this.isRecording = false,
    this.onSendVoiceNote,
    this.status = 'active',
    this.onDeactivate,
    this.onActivate,
    this.onRemove,
    this.isAdminUser = false,
    this.isOnSite = false,
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

  bool get _isActive => widget.status == 'active';

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'] ?? 'worker';
    final email = widget.user['email'] ?? 'User';
    final fullName = widget.user['full_name']?.toString();
    final displayName = fullName ?? email;
    final roleColor = _getRoleColor(role);

    return GestureDetector(
      onLongPress: widget.onEdit,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isActive ? 1.0 : 0.7,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(
              color: _isActive
                  ? Colors.black.withValues(alpha: 0.05)
                  : AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // User Info
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Row(
                  children: [
                    // Avatar with status dot
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              _isActive ? roleColor : AppTheme.textSecondary,
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Status dot
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _isActive
                                  ? AppTheme.successGreen
                                  : AppTheme.textSecondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: AppTheme.spacingM),

                    // User Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (fullName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: AppTheme.spacingS,
                            runSpacing: 4,
                            children: [
                              CategoryBadge(
                                text: role.toUpperCase(),
                                color: roleColor,
                              ),
                              if (_projectName != null && _isActive)
                                CategoryBadge(
                                  text: _projectName!,
                                  color: AppTheme.successGreen,
                                  icon: Icons.location_on_rounded,
                                ),
                              if (widget.isOnSite && _isActive)
                                const CategoryBadge(
                                  text: 'ON SITE',
                                  color: AppTheme.successGreen,
                                  icon: Icons.check_circle,
                                ),
                              if (!_isActive)
                                const CategoryBadge(
                                  text: 'INACTIVE',
                                  color: AppTheme.textSecondary,
                                  icon: Icons.pause_circle,
                                ),
                            ],
                          ),
                          // Deactivated date
                          if (!_isActive &&
                              widget.user['deactivated_at'] != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AppTheme.spacingXS),
                              child: Text(
                                'Deactivated ${_formatDate(widget.user['deactivated_at'])}',
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Action menu
                    _buildActionMenu(),
                  ],
                ),
              ),

              // Send Voice Note Button (only for active users)
              if (widget.onSendVoiceNote != null && _isActive)
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
                              widget.isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
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
      ),
    );
  }

  Widget _buildActionMenu() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            widget.onEdit();
            break;
          case 'deactivate':
            widget.onDeactivate?.call();
            break;
          case 'activate':
            widget.onActivate?.call();
            break;
          case 'remove':
            widget.onRemove?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit, size: 20),
            title: Text('Edit'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (_isActive && widget.onDeactivate != null && !widget.isAdminUser)
          PopupMenuItem(
            value: 'deactivate',
            child: ListTile(
              leading: Icon(Icons.pause_circle, size: 20,
                  color: AppTheme.warningOrange),
              title: Text('Deactivate',
                  style: TextStyle(color: AppTheme.warningOrange)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (!_isActive && widget.onActivate != null)
          PopupMenuItem(
            value: 'activate',
            child: ListTile(
              leading: Icon(Icons.play_circle, size: 20,
                  color: AppTheme.successGreen),
              title: Text('Activate',
                  style: TextStyle(color: AppTheme.successGreen)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (widget.onRemove != null && !widget.isAdminUser)
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.person_remove, size: 20,
                  color: AppTheme.errorRed),
              title: Text('Remove from Company',
                  style: TextStyle(color: AppTheme.errorRed)),
              subtitle: Text('Permanent action',
                  style: AppTheme.caption.copyWith(color: AppTheme.errorRed)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final date = DateTime.parse(dateValue.toString());
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return '';
    }
  }
}
