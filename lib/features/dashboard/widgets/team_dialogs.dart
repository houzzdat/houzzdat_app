import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Available languages for user preferences.
/// Key: ISO 639-1 code, Value: Display name.
const Map<String, String> kAvailableLanguages = {
  'en': 'English',
  'hi': 'Hindi',
  'te': 'Telugu',
  'ta': 'Tamil',
  'kn': 'Kannada',
  'mr': 'Marathi',
  'gu': 'Gujarati',
  'pa': 'Punjabi',
  'ml': 'Malayalam',
  'bn': 'Bengali',
  'ur': 'Urdu',
};

class TeamDialogs {
  static Future<bool?> showInviteStaffDialog(
    BuildContext context,
    String accountId,
  ) async {
    final supabase = Supabase.instance.client;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedRole;
    bool isLoading = false;
    bool isCheckingEmail = false;
    bool? existingUserDetected;
    String? existingUserName;
    List<String> selectedLanguages = ['en']; // English always included

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
              content: Text('No roles found. Please create roles first.'),
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
          builder: (context, setState) {
            // Function to check if email exists in the system
            Future<void> checkEmailExists(String email) async {
              if (email.isEmpty ||
                  !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                setState(() {
                  existingUserDetected = null;
                  existingUserName = null;
                });
                return;
              }

              setState(() => isCheckingEmail = true);

              try {
                // Check if user exists in users table
                final existingUser = await supabase
                    .from('users')
                    .select('id, email, full_name')
                    .eq('email', email.trim().toLowerCase())
                    .maybeSingle();

                if (existingUser != null) {
                  // Check if they already have an active association with this company
                  final existingAssoc = await supabase
                      .from('user_company_associations')
                      .select('id, status')
                      .eq('user_id', existingUser['id'])
                      .eq('account_id', accountId)
                      .maybeSingle();

                  if (existingAssoc != null &&
                      existingAssoc['status'] == 'active') {
                    setState(() {
                      existingUserDetected = null;
                      existingUserName = null;
                      isCheckingEmail = false;
                    });
                    // Will be caught by form validation
                    return;
                  }

                  setState(() {
                    existingUserDetected = true;
                    existingUserName =
                        existingUser['full_name'] ?? existingUser['email'];
                    isCheckingEmail = false;
                  });
                } else {
                  setState(() {
                    existingUserDetected = false;
                    existingUserName = null;
                    isCheckingEmail = false;
                  });
                }
              } catch (e) {
                setState(() {
                  existingUserDetected = null;
                  existingUserName = null;
                  isCheckingEmail = false;
                });
              }
            }

            return AlertDialog(
              title: const Text("Invite Staff Member"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Full Name field
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: "Full Name",
                          hintText: "John Doe",
                          prefixIcon: Icon(Icons.person),
                        ),
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      // Email field with existence check on blur
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          hintText: "user@example.com",
                          prefixIcon: const Icon(Icons.email),
                          suffixIcon: isCheckingEmail
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : existingUserDetected == true
                                  ? const Icon(Icons.check_circle,
                                      color: AppTheme.successGreen)
                                  : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                              .hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                        onEditingComplete: () {
                          checkEmailExists(emailController.text.trim());
                          FocusScope.of(context).nextFocus();
                        },
                        onFieldSubmitted: (_) {
                          checkEmailExists(emailController.text.trim());
                        },
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Existing user banner
                      if (existingUserDetected == true) ...[
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: BoxDecoration(
                            color: AppTheme.infoBlue.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(
                              color: AppTheme.infoBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info,
                                  color: AppTheme.infoBlue, size: 20),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Text(
                                  '${existingUserName ?? "This user"} already has an account. They\'ll be added to your company with the selected role.',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.infoBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                      ],

                      // Password field - hidden for existing users
                      if (existingUserDetected != true) ...[
                        const SizedBox(height: AppTheme.spacingS),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Temporary Password",
                            hintText: "Min 6 characters",
                            prefixIcon: Icon(Icons.lock),
                            helperText:
                                'User will be prompted to change on first login',
                          ),
                          validator: (value) {
                            // Password only required for new users
                            if (existingUserDetected != true) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required for new users';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                      ],

                      const SizedBox(height: AppTheme.spacingS),

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
                        onChanged: isLoading
                            ? null
                            : (v) => setState(() => selectedRole = v),
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a role';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppTheme.spacingL),
                      const Divider(),
                      const SizedBox(height: AppTheme.spacingS),

                      // Language Preferences
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Preferred Languages',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'English + up to 2 Indian languages',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: kAvailableLanguages.entries.map((entry) {
                          final code = entry.key;
                          final name = entry.value;
                          final isSelected =
                              selectedLanguages.contains(code);
                          final isEnglish = code == 'en';
                          // Disable if not selected and already at max (3)
                          final atMax =
                              selectedLanguages.length >= 3 && !isSelected;

                          return FilterChip(
                            label: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : atMax
                                        ? AppTheme.textSecondary
                                        : AppTheme.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryIndigo,
                            checkmarkColor: Colors.white,
                            backgroundColor: atMax
                                ? AppTheme.backgroundGrey
                                : null,
                            onSelected: isLoading || isEnglish
                                ? null // English can't be deselected
                                : (selected) {
                                    setState(() {
                                      if (selected && !atMax) {
                                        selectedLanguages.add(code);
                                      } else if (!selected) {
                                        selectedLanguages.remove(code);
                                      }
                                    });
                                  },
                          );
                        }).toList(),
                      ),

                      // Loading indicator
                      if (isLoading) ...[
                        const SizedBox(height: AppTheme.spacingL),
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          existingUserDetected == true
                              ? 'Adding user to company...'
                              : 'Creating user account...',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading || isCheckingEmail
                      ? null
                      : () async {
                          // If email hasn't been checked yet, check it first
                          if (existingUserDetected == null) {
                            await checkEmailExists(
                                emailController.text.trim());
                          }

                          // Validate form
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            final body = <String, dynamic>{
                              'email': emailController.text.trim(),
                              'role': selectedRole,
                              'account_id': accountId,
                            };

                            // Include full name if provided
                            if (nameController.text.trim().isNotEmpty) {
                              body['full_name'] = nameController.text.trim();
                            }

                            // Include preferred languages
                            body['preferred_languages'] = selectedLanguages;

                            // Only include password for new users
                            if (existingUserDetected != true &&
                                passwordController.text.isNotEmpty) {
                              body['password'] =
                                  passwordController.text.trim();
                            }

                            // Call edge function to create/add user
                            final response = await supabase.functions.invoke(
                              'invite-user',
                              body: body,
                            );

                            // Check response
                            if (response.status == 200) {
                              final data = response.data;

                              if (context.mounted) {
                                Navigator.pop(context, true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        data['message'] ??
                                            'User invited successfully!'),
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                );
                              }
                            } else {
                              // Handle error response
                              final errorMessage = response.data?['error'] ??
                                  'Failed to invite user';
                              throw Exception(errorMessage);
                            }
                          } catch (e) {
                            setState(() => isLoading = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(existingUserDetected == true
                          ? "Add to Company"
                          : "Send Invite"),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading roles: $e'),
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
    final nameController = TextEditingController(
      text: user['full_name']?.toString() ?? '',
    );
    String? selectedRole = user['role']?.toString();
    String? selectedProject = user['current_project_id'];
    bool geofenceExempt = user['geofence_exempt'] == true;
    bool isLoading = false;

    // Initialize language selection from user's current preferred_languages
    List<String> selectedLanguages;
    final existingLangs = user['preferred_languages'];
    if (existingLangs is List && existingLangs.isNotEmpty) {
      selectedLanguages = List<String>.from(existingLangs);
    } else {
      final singleLang = user['preferred_language']?.toString() ?? 'en';
      selectedLanguages = singleLang == 'en' ? ['en'] : [singleLang, 'en'];
    }
    // Ensure 'en' is always present
    if (!selectedLanguages.contains('en')) {
      selectedLanguages.add('en');
    }

    try {
      // Fetch projects and roles in parallel
      final results = await Future.wait([
        supabase.from('projects').select().eq('account_id', accountId),
        supabase.from('roles').select().eq('account_id', accountId),
      ]);

      final projects = results[0] as List;
      final roles = results[1] as List;

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("Edit ${user['full_name'] ?? user['email'] ?? 'User'}"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name field
                  Text("Name", style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.spacingS),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      hintText: "Enter user's name",
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: !isLoading,
                  ),

                  const SizedBox(height: AppTheme.spacingL),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacingM),

                  // Role Assignment Section
                  Text("Role", style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.spacingS),

                  if (roles.isNotEmpty)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Assigned Role",
                        prefixIcon: Icon(Icons.badge),
                        helperText: 'Change the user\'s role in this company',
                      ),
                      value: roles.any((r) => r['name'] == selectedRole)
                          ? selectedRole
                          : null,
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
                      onChanged: isLoading
                          ? null
                          : (v) => setState(() => selectedRole = v),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundGrey,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getRoleIcon(user['role'] ?? 'worker'),
                            size: 20,
                            color: AppTheme.primaryIndigo,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
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
                    onChanged: isLoading
                        ? null
                        : (v) => setState(() => selectedProject = v),
                  ),

                  const SizedBox(height: AppTheme.spacingL),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacingS),

                  // Geofence exemption
                  Text("Geofence Settings", style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.spacingS),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Exempt from Geofence",
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      "Allow this worker to check in from any location",
                      style: TextStyle(fontSize: 12),
                    ),
                    value: geofenceExempt,
                    activeColor: AppTheme.primaryIndigo,
                    onChanged: isLoading
                        ? null
                        : (v) => setState(() => geofenceExempt = v),
                  ),

                  const SizedBox(height: AppTheme.spacingL),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacingS),

                  // Language Preferences
                  Text("Preferred Languages",
                      style: AppTheme.headingSmall),
                  const SizedBox(height: 4),
                  const Text(
                    'English + up to 2 Indian languages',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children:
                        kAvailableLanguages.entries.map((entry) {
                      final code = entry.key;
                      final name = entry.value;
                      final isSelected =
                          selectedLanguages.contains(code);
                      final isEnglish = code == 'en';
                      final atMax = selectedLanguages.length >= 3 &&
                          !isSelected;

                      return FilterChip(
                        label: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : atMax
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryIndigo,
                        checkmarkColor: Colors.white,
                        backgroundColor:
                            atMax ? AppTheme.backgroundGrey : null,
                        onSelected: isLoading || isEnglish
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected && !atMax) {
                                    selectedLanguages.add(code);
                                  } else if (!selected) {
                                    selectedLanguages.remove(code);
                                  }
                                });
                              },
                      );
                    }).toList(),
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
                          // Update user record (name + project + geofence + languages)
                          final nameValue = nameController.text.trim();
                          await supabase.from('users').update({
                            'full_name': nameValue.isNotEmpty ? nameValue : null,
                            'current_project_id': selectedProject,
                            'geofence_exempt': geofenceExempt,
                            'preferred_languages': selectedLanguages,
                          }).eq('id', user['id']);

                          // Update role if it changed
                          final originalRole =
                              user['role']?.toString() ?? 'worker';
                          if (selectedRole != null &&
                              selectedRole != originalRole) {
                            // Update association role
                            await supabase
                                .from('user_company_associations')
                                .update({'role': selectedRole})
                                .eq('user_id', user['id'])
                                .eq('account_id', accountId);

                            // Also update users table role for backward compat
                            // (only if this is the user's active company)
                            await supabase.from('users').update({
                              'role': selectedRole,
                            }).eq('id', user['id']);
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User updated successfully!'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isLoading = false);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
            content: Text('Error loading data: $e'),
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
