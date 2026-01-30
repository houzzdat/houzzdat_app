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
    final formKey = GlobalKey<FormState>();
    String? selectedRole;
    bool isLoading = false;

    // Fetch roles
    try {
      final roles = await supabase
          .from('roles')
          .select()
          .eq('account_id', accountId);

      if (!context.mounted) return null;

      // If no roles exist, show error and suggest creating roles first
      if (roles.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No roles found. Please create roles first.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return null;
      }

      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Invite New Staff Member"),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email field with validation
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email Address",
                        hintText: "user@example.com",
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        // Basic email validation
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Password field with validation
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Temporary Password",
                        hintText: "Min 6 characters",
                        prefixIcon: Icon(Icons.lock),
                        helperText: 'User will be prompted to change on first login',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Role dropdown with validation
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select Role",
                        prefixIcon: Icon(Icons.badge),
                      ),
                      value: selectedRole,
                      items: roles.map<DropdownMenuItem<String>>((r) {
                        return DropdownMenuItem(
                          value: r['name'],
                          child: Row(
                            children: [
                              Icon(
                                _getRoleIcon(r['name']),
                                size: 20,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(r['name'] ?? ''),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: isLoading ? null : (v) => setState(() => selectedRole = v),
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a role';
                        }
                        return null;
                      },
                    ),
                    
                    // Loading indicator
                    if (isLoading) ...[
                      const SizedBox(height: AppTheme.spacingL),
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppTheme.spacingS),
                      const Text(
                        'Creating user account...',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        // Validate form
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        setState(() => isLoading = true);

                        try {
                          // Call edge function to create user
                          final response = await supabase.functions.invoke(
                            'invite-user',
                            body: {
                              'email': emailController.text.trim(),
                              'password': passwordController.text.trim(),
                              'role': selectedRole,
                              'account_id': accountId,
                            },
                          );

                          // Check response
                          if (response.status == 200) {
                            final data = response.data;
                            
                            if (context.mounted) {
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ ${data['message'] ?? 'User invited successfully!'}'),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            }
                          } else {
                            // Handle error response
                            final errorMessage = response.data?['error'] ?? 'Failed to invite user';
                            throw Exception(errorMessage);
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Error: ${e.toString()}'),
                                backgroundColor: AppTheme.errorRed,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text("Send Invite"),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error loading roles: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return null;
    }
  }

  static Future<void> showEditUserDialog(
    BuildContext context,
    Map<String, dynamic> user,
    String accountId,
  ) async {
    final supabase = Supabase.instance.client;
    String? selectedProject = user['current_project_id'];
    bool isLoading = false;

    try {
      // Fetch projects
      final projects = await supabase
          .from('projects')
          .select()
          .eq('account_id', accountId);

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("Edit ${user['email'] ?? 'User'}"),
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
                            Icon(
                              _getRoleIcon(user['role'] ?? 'worker'),
                              size: 20,
                              color: AppTheme.primaryIndigo,
                            ),
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
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryIndigo,
                            fontWeight: FontWeight.w600,
                          ),
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
                      helperText: 'Assign user to a specific project',
                    ),
                    value: selectedProject,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text("No Assignment"),
                          ],
                        ),
                      ),
                      ...projects.map((p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p['name'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    onChanged: isLoading ? null : (v) => setState(() => selectedProject = v),
                  ),
                  
                  // Loading indicator
                  if (isLoading) ...[
                    const SizedBox(height: AppTheme.spacingL),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: AppTheme.spacingS),
                    const Center(
                      child: Text(
                        'Updating user...',
                        style: AppTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);

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
                          setState(() => isLoading = false);
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Error: $e'),
                                backgroundColor: AppTheme.errorRed,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text("Save"),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error loading projects: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // Helper function to get appropriate icon for role
  static IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
      case 'admin':
        return Icons.admin_panel_settings;
      case 'worker':
      case 'site_engineer':
        return Icons.construction;
      case 'supervisor':
        return Icons.supervised_user_circle;
      default:
        return Icons.person;
    }
  }
}