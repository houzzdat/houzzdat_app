import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class TeamDialogs {
  static Future<bool?> showInviteStaffDialog(
    BuildContext context,
    String accountId,
  ) async {
    final supabase = Supabase.instance.client;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedRole;

    // Fetch roles
    final roles = await supabase
        .from('roles')
        .select()
        .eq('account_id', accountId);

    if (!context.mounted) return null;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Invite New Staff Member"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email Address",
                    hintText: "user@example.com",
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Temporary Password",
                    hintText: "Min 6 characters",
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Select Role",
                    prefixIcon: Icon(Icons.badge),
                  ),
                  value: selectedRole,
                  items: roles.map<DropdownMenuItem<String>>((r) {
                    return DropdownMenuItem(
                      value: r['name'],
                      child: Text(r['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedRole = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: selectedRole == null
                  ? null
                  : () async {
                      try {
                        await supabase.functions.invoke('invite-user', body: {
                          'email': emailController.text.trim(),
                          'password': passwordController.text.trim(),
                          'role': selectedRole,
                          'account_id': accountId,
                        });
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      }
                    },
              child: const Text("Send Invite"),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showEditUserDialog(
    BuildContext context,
    Map<String, dynamic> user,
    String accountId,
  ) async {
    final supabase = Supabase.instance.client;
    String? selectedProject = user['current_project_id'];

    // Fetch projects
    final projects = await supabase
        .from('projects')
        .select()
        .eq('account_id', accountId);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Edit ${user['email']}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Section
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundGrey,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge, size: 20),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            "Role",
                            style: AppTheme.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        user['role'] ?? 'worker',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                const Divider(),
                const SizedBox(height: AppTheme.spacingM),
                // Project Assignment
                Text(
                  "Project Assignment",
                  style: AppTheme.headingSmall,
                ),
                const SizedBox(height: AppTheme.spacingM),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Assigned Project",
                    prefixIcon: Icon(Icons.business),
                  ),
                  value: selectedProject,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("No Assignment"),
                    ),
                    ...projects.map((p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text(p['name']),
                        )),
                  ],
                  onChanged: (v) => setState(() => selectedProject = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await supabase.from('users').update({
                    'current_project_id': selectedProject,
                  }).eq('id', user['id']);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ User updated successfully!'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}