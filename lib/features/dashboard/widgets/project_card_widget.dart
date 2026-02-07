import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class ProjectCardWidget extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssignUsers;
  final VoidCallback? onAssignOwner;

  const ProjectCardWidget({
    super.key,
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignUsers,
    this.onAssignOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.primaryIndigo,
          child: Icon(Icons.business, color: Colors.white),
        ),
        title: Text(
          project['name'] ?? 'Site',
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          project['location'] ?? 'No location set',
          style: AppTheme.bodySmall,
        ),
        trailing: PopupMenuButton(
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
            if (onAssignOwner != null)
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
                onAssignUsers();
                break;
              case 'assign_owner':
                onAssignOwner?.call();
                break;
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
        ),
      ),
    );
  }
}