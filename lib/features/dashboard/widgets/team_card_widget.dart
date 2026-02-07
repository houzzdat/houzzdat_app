import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

class TeamCardWidget extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;

  const TeamCardWidget({
    super.key,
    required this.user,
    required this.onEdit,
  });

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
      case 'admin':
        return AppTheme.infoBlue;
      case 'worker':
        return AppTheme.primaryIndigo;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
      case 'admin':
        return Icons.admin_panel_settings;
      case 'worker':
        return Icons.construction;
      default:
        return Icons.person;
    }
  }

  String _getRoleDisplayName(String role) {
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? 'worker';
    final email = user['email'] ?? 'User';
    final roleColor = _getRoleColor(role);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor,
          child: Icon(
            _getRoleIcon(role),
            color: Colors.white,
          ),
        ),
        title: Text(
          email,
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            CategoryBadge(
              text: _getRoleDisplayName(role),
              color: roleColor,
              icon: _getRoleIcon(role),
            ),
            if (user['current_project_id'] != null) ...[
              const SizedBox(width: AppTheme.spacingS),
              const CategoryBadge(
                text: 'Assigned',
                color: AppTheme.successGreen,
                icon: Icons.check_circle,
              ),
            ],
            if (user['geofence_exempt'] == true) ...[
              const SizedBox(width: AppTheme.spacingS),
              CategoryBadge(
                text: 'No Geofence',
                color: AppTheme.warningOrange,
                icon: Icons.location_off,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: AppTheme.primaryIndigo),
          onPressed: onEdit,
          tooltip: 'Edit user',
        ),
      ),
    );
  }
}