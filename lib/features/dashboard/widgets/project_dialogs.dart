import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class ProjectDialogs {
  static Future<Map<String, String>?> showAddProjectDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create New Site"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Site Name",
                hintText: "e.g., Downtown Office Building",
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: "Location (Optional)",
                hintText: "e.g., 123 Main St",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'location': locationController.text.trim(),
                });
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  static Future<Map<String, String>?> showEditProjectDialog(
    BuildContext context,
    Map<String, dynamic> project,
  ) async {
    final nameController = TextEditingController(text: project['name']);
    final locationController = TextEditingController(text: project['location'] ?? '');

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Site"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Site Name"),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: "Location"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'location': locationController.text.trim(),
              });
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  static Future<void> showAssignUserDialog(
    BuildContext context,
    Map<String, dynamic> project,
    String accountId,
  ) async {
    final supabase = Supabase.instance.client;
    final users = await supabase
        .from('users')
        .select()
        .eq('account_id', accountId)
        .neq('role', 'admin');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Assign Users to ${project['name']}"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, i) {
                final user = users[i];
                final isAssigned = user['current_project_id'] == project['id'];

                return CheckboxListTile(
                  title: Text(user['email'] ?? 'User'),
                  subtitle: Text(user['role'] ?? 'worker'),
                  value: isAssigned,
                  onChanged: (bool? value) async {
                    if (value == true) {
                      await supabase.from('users').update({
                        'current_project_id': project['id']
                      }).eq('id', user['id']);
                    } else {
                      await supabase.from('users').update({
                        'current_project_id': null
                      }).eq('id', user['id']);
                    }
                    // Refresh the dialog
                    Navigator.pop(context);
                    showAssignUserDialog(context, project, accountId);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }
}