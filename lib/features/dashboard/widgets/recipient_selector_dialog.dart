import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Dialog for selecting team members to receive a broadcast message.
/// Returns List<String> of selected user IDs, or null if cancelled.
class RecipientSelectorDialog extends StatefulWidget {
  final String accountId;
  final String managerId;

  const RecipientSelectorDialog({
    super.key,
    required this.accountId,
    required this.managerId,
  });

  @override
  State<RecipientSelectorDialog> createState() => _RecipientSelectorDialogState();
}

class _RecipientSelectorDialogState extends State<RecipientSelectorDialog> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _teamMembers = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Query active team members using the team_members_view
      final data = await _supabase
          .from('team_members_view')
          .select('user_id, full_name, email, role')
          .eq('account_id', widget.accountId)
          .eq('association_status', 'active')
          .neq('user_id', widget.managerId);

      if (mounted) {
        setState(() {
          _teamMembers = (data as List).map((item) {
            return {
              'id': item['user_id'],
              'full_name': item['full_name'] ?? item['email'] ?? 'Unknown',
              'email': item['email'],
              'role': item['role'] ?? 'worker',
            };
          }).toList();

          // Sort by name
          _teamMembers.sort((a, b) =>
            (a['full_name'] as String).compareTo(b['full_name'] as String)
          );

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading team members: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load team members';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _teamMembers.map((m) => m['id'] as String).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'manager': return 'Manager';
      case 'worker': return 'Worker';
      case 'owner': return 'Owner';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  LucideIcons.users,
                  color: AppTheme.primaryIndigo,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select Team Members',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose who will receive the broadcast',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Select All / Deselect All buttons
            if (!_isLoading && _teamMembers.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(LucideIcons.checkSquare, size: 18),
                      label: const Text('Select All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryIndigo,
                        side: const BorderSide(color: AppTheme.primaryIndigo),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(LucideIcons.square, size: 18),
                      label: const Text('Deselect All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Selection count
            if (!_isLoading && _teamMembers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.users,
                      size: 16,
                      color: AppTheme.primaryIndigo,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedIds.length} of ${_teamMembers.length} members selected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryIndigo,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Team members list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryIndigo,
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.alertCircle,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadTeamMembers,
                                icon: const Icon(LucideIcons.refreshCw, size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryIndigo,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _teamMembers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.users,
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No other team members',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _teamMembers.length,
                              itemBuilder: (context, index) {
                                final member = _teamMembers[index];
                                final userId = member['id'] as String;
                                final isSelected = _selectedIds.contains(userId);
                                final fullName = member['full_name'] as String;
                                final role = _getRoleLabel(member['role'] as String);

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (value) => _toggleSelection(userId),
                                  title: Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    role,
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  activeColor: AppTheme.primaryIndigo,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                );
                              },
                            ),
            ),

            const Divider(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedIds.toList()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
