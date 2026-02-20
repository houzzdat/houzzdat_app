import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// Compact user card for the team tab.
/// Header: avatar + name/email + action icons (mic, chat, more).
/// Metadata: role badge, project badge, status pill.
class TeamCardWidget extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final bool isRecording;
  final VoidCallback? onSendVoiceNote;
  final VoidCallback? onSendTextMessage;

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

  /// Quick-tag toggle callback. If non-null, shows the toggle in the action menu.
  final void Function(bool enabled)? onQuickTagToggle;

  /// Current quick-tag enabled state for this user (null = account default).
  final bool? quickTagEnabled;

  const TeamCardWidget({
    super.key,
    required this.user,
    required this.onEdit,
    this.isRecording = false,
    this.onSendVoiceNote,
    this.onSendTextMessage,
    this.status = 'active',
    this.onDeactivate,
    this.onActivate,
    this.onRemove,
    this.isAdminUser = false,
    this.isOnSite = false,
    this.onQuickTagToggle,
    this.quickTagEnabled,
  });

  @override
  State<TeamCardWidget> createState() => _TeamCardWidgetState();
}

class _TeamCardWidgetState extends State<TeamCardWidget> {
  static const Color _avatarBg = Color(0xFFBBDEFB);
  static const Color _avatarFg = Color(0xFF1565C0);

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
      case 'owner':
        return AppTheme.warningOrange;
      case 'site_engineer':
      case 'supervisor':
      case 'worker':
        return AppTheme.primaryIndigo;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'owner':
        return 'Owner';
      case 'worker':
        return 'Worker';
      case 'site_engineer':
        return 'Engineer';
      case 'supervisor':
        return 'Supervisor';
      default:
        return role[0].toUpperCase() + role.substring(1);
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
          margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(
              color: _isActive
                  ? Colors.black.withValues(alpha: 0.05)
                  : AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──
              Row(
                children: [
                  // Avatar with status dot
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _isActive
                            ? _avatarBg
                            : AppTheme.textSecondary.withValues(alpha: 0.2),
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: TextStyle(
                            color: _isActive ? _avatarFg : AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _isActive
                                ? AppTheme.successGreen
                                : AppTheme.textSecondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: AppTheme.spacingM),

                  // Name + Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (fullName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action icons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onSendVoiceNote != null && _isActive)
                        _buildActionIcon(
                          icon: widget.isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          onTap: widget.onSendVoiceNote!,
                          isActive: widget.isRecording,
                          activeColor: AppTheme.errorRed,
                        ),
                      if (widget.onSendTextMessage != null && _isActive)
                        _buildActionIcon(
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: widget.onSendTextMessage!,
                        ),
                      _buildActionMenu(),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingS),

              // ── Metadata Row ──
              Row(
                children: [
                  CategoryBadge(
                    text: _getRoleDisplayName(role),
                    color: roleColor,
                  ),
                  if (_projectName != null && _isActive) ...[
                    const SizedBox(width: AppTheme.spacingS),
                    Flexible(
                      child: CategoryBadge(
                        text: _projectName!,
                        color: AppTheme.successGreen,
                        icon: Icons.location_on_rounded,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _buildStatusPill(),
                ],
              ),

              // Deactivated date
              if (!_isActive && widget.user['deactivated_at'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingXS),
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
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final color = isActive ? (activeColor ?? AppTheme.errorRed) : AppTheme.infoBlue;
    final bgColor = isActive
        ? color.withValues(alpha: 0.15)
        : AppTheme.infoBlue.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacingXS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    if (!_isActive) {
      return _statusPill(
        dotColor: AppTheme.textSecondary,
        text: 'Inactive',
      );
    }
    if (widget.isOnSite) {
      return _statusPill(
        dotColor: AppTheme.successGreen,
        text: 'On Site',
      );
    }
    return _statusPill(
      dotColor: AppTheme.textSecondary,
      text: 'Away',
    );
  }

  Widget _statusPill({required Color dotColor, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: dotColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.infoBlue.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: AppTheme.infoBlue, size: 18),
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            widget.onEdit();
            break;
          case 'toggle_quick_tag':
            widget.onQuickTagToggle?.call(!(widget.quickTagEnabled ?? true));
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
        if (_isActive && widget.onQuickTagToggle != null)
          PopupMenuItem(
            value: 'toggle_quick_tag',
            child: ListTile(
              leading: Icon(
                (widget.quickTagEnabled ?? true) ? Icons.label_off : Icons.label,
                size: 20,
                color: AppTheme.primaryIndigo,
              ),
              title: Text(
                (widget.quickTagEnabled ?? true)
                    ? 'Disable Quick-Tag'
                    : 'Enable Quick-Tag',
              ),
              subtitle: Text(
                'Message tagging after recording',
                style: AppTheme.caption,
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_isActive && widget.onDeactivate != null && !widget.isAdminUser)
          PopupMenuItem(
            value: 'deactivate',
            child: ListTile(
              leading: Icon(Icons.pause_circle,
                  size: 20, color: AppTheme.warningOrange),
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
              leading: Icon(Icons.play_circle,
                  size: 20, color: AppTheme.successGreen),
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
              leading: Icon(Icons.person_remove,
                  size: 20, color: AppTheme.errorRed),
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
