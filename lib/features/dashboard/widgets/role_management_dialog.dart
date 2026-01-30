import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

class RoleManagementDialog extends StatefulWidget {
  final String accountId;

  const RoleManagementDialog({
    super.key,
    required this.accountId,
  });

  @override
  State<RoleManagementDialog> createState() => _RoleManagementDialogState();
}

class _RoleManagementDialogState extends State<RoleManagementDialog> {
  final _supabase = Supabase.instance.client;
  final _roleNameController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _roleNameController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await _supabase
          .from('roles')
          .select()
          .eq('account_id', widget.accountId)
          .order('name');

      setState(() {
        _roles = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading roles: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _addRole() async {
    final roleName = _roleNameController.text.trim();
    
    if (roleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a role name'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    // Check for duplicates
    if (_roles.any((r) => r['name'].toString().toLowerCase() == roleName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This role already exists'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.from('roles').insert({
        'name': roleName,
        'account_id': widget.accountId,
      });

      _roleNameController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Role added successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }

      await _loadRoles();
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding role: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteRole(String roleId, String roleName) async {
    // Check if role is in use
    final usersWithRole = await _supabase
        .from('users')
        .select('id')
        .eq('role', roleName)
        .eq('account_id', widget.accountId);

    if (usersWithRole.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete "$roleName" - ${usersWithRole.length} user(s) assigned'),
          backgroundColor: AppTheme.warningOrange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role?'),
        content: Text('Are you sure you want to delete "$roleName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('roles').delete().eq('id', roleId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Role deleted successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }

      await _loadRoles();
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting role: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _loadDefaultRoles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Default Roles?'),
        content: const Text(
          'This will add standard construction site roles to your account. '
          'Existing roles will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Load Roles'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final defaultRoles = [
      'Project Manager',
      'Site Manager',
      'Admin',
      'Site Engineer',
      'Civil Engineer',
      'Site Supervisor',
      'Safety Officer',
      'Foreman',
      'Mason',
      'Carpenter',
      'Electrician',
      'Plumber',
      'Worker',
      'Helper',
      'Store Keeper',
    ];

    try {
      // Insert roles that don't already exist
      final existingRoleNames = _roles.map((r) => r['name'].toString().toLowerCase()).toSet();
      final newRoles = defaultRoles
          .where((name) => !existingRoleNames.contains(name.toLowerCase()))
          .map((name) => {
                'name': name,
                'account_id': widget.accountId,
              })
          .toList();

      if (newRoles.isNotEmpty) {
        await _supabase.from('roles').insert(newRoles);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Added ${newRoles.length} default roles'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }

        await _loadRoles();
      } else {
        setState(() => _isLoading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All default roles already exist'),
              backgroundColor: AppTheme.infoBlue,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading default roles: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: const BoxDecoration(
                color: AppTheme.primaryIndigo,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusM),
                  topRight: Radius.circular(AppTheme.radiusM),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge, color: Colors.white),
                  const SizedBox(width: AppTheme.spacingM),
                  const Expanded(
                    child: Text(
                      'Manage Roles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Add Role Section
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _roleNameController,
                      decoration: const InputDecoration(
                        labelText: 'New Role Name',
                        hintText: 'e.g., Site Engineer',
                        prefixIcon: Icon(Icons.add_circle_outline),
                      ),
                      onSubmitted: (_) => _addRole(),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addRole,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Load Defaults Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _loadDefaultRoles,
                  icon: const Icon(Icons.download),
                  label: const Text('Load Default Construction Roles'),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Roles List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _roles.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 64,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(height: AppTheme.spacingM),
                              Text(
                                'No roles yet',
                                style: AppTheme.headingSmall,
                              ),
                              SizedBox(height: AppTheme.spacingS),
                              Text(
                                'Add your first role or load defaults',
                                style: AppTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingL,
                          ),
                          itemCount: _roles.length,
                          itemBuilder: (context, index) {
                            final role = _roles[index];
                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppTheme.spacingS,
                              ),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.primaryIndigo,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  role['name'],
                                  style: AppTheme.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.errorRed,
                                  ),
                                  onPressed: () => _deleteRole(
                                    role['id'],
                                    role['name'],
                                  ),
                                  tooltip: 'Delete role',
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      '${_roles.length} role(s) available',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension method to show the dialog easily
extension RoleManagementExtension on BuildContext {
  Future<void> showRoleManagementDialog(String accountId) async {
    await showDialog(
      context: this,
      builder: (context) => RoleManagementDialog(accountId: accountId),
    );
  }
}