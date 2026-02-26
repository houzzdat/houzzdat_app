import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/main.dart';
import 'package:houzzdat_app/features/dashboard/widgets/logout_dialog.dart';
import 'package:houzzdat_app/features/dashboard/widgets/confidence_calibration_widget.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// Unified Settings screen used across all roles.
///
/// **Manager** sees: User Profile, Dark Mode, AI Settings, Logout.
/// **Worker / Owner** sees: User Profile, Dark Mode, Logout.
///
/// The [role] parameter controls which sections appear.
/// The [accountId] is required for the AI Settings section (manager only).
class SettingsScreen extends StatefulWidget {
  final String role;
  final String? accountId;

  const SettingsScreen({
    super.key,
    required this.role,
    this.accountId,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  String _fullName = '';
  String _email = '';
  String _userRole = '';
  String _companyName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('users')
          .select('full_name, email, role')
          .eq('id', user.id)
          .maybeSingle(); // UX-audit CI-01

      final companyService = CompanyContextService();
      final companyName = companyService.activeCompanyName ?? '';

      if (mounted) {
        setState(() {
          _fullName = data?['full_name']?.toString() ?? '';
          _email = data?['email']?.toString() ?? user.email ?? '';
          _userRole = data?['role']?.toString() ?? widget.role;
          _companyName = companyName;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _email = _supabase.auth.currentUser?.email ?? '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LogoutDialog(),
    );

    if (confirm == true && mounted) {
      await CompanyContextService().reset();
      await _supabase.auth.signOut();
      if (mounted) {
        // Pop all imperative navigator routes first, then let GoRouter go to root
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
        GoRouter.of(context).go('/');
      }
    }
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return 'Manager';
      case 'worker':
        return 'Worker';
      case 'owner':
        return 'Owner';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role.isNotEmpty
            ? '${role[0].toUpperCase()}${role.substring(1)}'
            : 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentThemeMode = MyApp.getThemeMode(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const ShimmerLoadingList() // UX-audit #4: shimmer instead of spinner
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ─── User Profile Card ───
                _buildProfileCard(theme, isDark),

                const SizedBox(height: 16),

                // ─── Appearance Section ───
                _buildSectionHeader('APPEARANCE'),
                _buildThemeTile(currentThemeMode, isDark),

                const SizedBox(height: 16),

                // ─── AI Settings (Manager only) ───
                if (widget.role == 'manager' && widget.accountId != null) ...[
                  _buildSectionHeader('AI SETTINGS'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: ConfidenceCalibrationWidget(
                        accountId: widget.accountId!),
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── Account Section ───
                _buildSectionHeader('ACCOUNT'),
                _buildLogoutTile(isDark),

                const SizedBox(height: 32),

                // ─── App Version ───
                Center(
                  child: Text(
                    'Sitevoice v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade600 : AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  // ──────────── Profile Card ────────────

  Widget _buildProfileCard(ThemeData theme, bool isDark) {
    final initials = _getInitials(_fullName.isNotEmpty ? _fullName : _email);
    final avatarBg = isDark ? const Color(0xFF5C6BC0) : AppTheme.primaryIndigo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: avatarBg,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name + email + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_fullName.isNotEmpty)
                  Text(
                    _fullName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                if (_fullName.isNotEmpty) const SizedBox(height: 2),
                Text(
                  _email,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildBadge(_formatRole(_userRole), AppTheme.primaryIndigo, isDark),
                    if (_companyName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: _buildBadge(
                            _companyName, AppTheme.accentAmber, isDark),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? color.withValues(alpha: 0.9) : color,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ──────────── Section Header ────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ──────────── Theme / Dark Mode Tile ────────────

  Widget _buildThemeTile(ThemeMode currentMode, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Column(
        children: [
          _buildThemeOption(
            icon: Icons.light_mode_rounded,
            label: 'Light',
            subtitle: 'Always use light theme',
            isSelected: currentMode == ThemeMode.light,
            onTap: () => _setTheme(ThemeMode.light),
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          _buildThemeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            subtitle: 'Always use dark theme',
            isSelected: currentMode == ThemeMode.dark,
            onTap: () => _setTheme(ThemeMode.dark),
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          _buildThemeOption(
            icon: Icons.settings_brightness_rounded,
            label: 'System',
            subtitle: 'Follow device setting',
            isSelected: currentMode == ThemeMode.system,
            onTap: () => _setTheme(ThemeMode.system),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryIndigo : AppTheme.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade500 : AppTheme.textSecondary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppTheme.primaryIndigo)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
    );
  }

  void _setTheme(ThemeMode mode) {
    MyApp.setThemeMode(context, mode);
    // setState triggers rebuild to update selected indicator
    setState(() {});
  }

  // ──────────── Logout Tile ────────────

  Widget _buildLogoutTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: AppTheme.errorRed),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: AppTheme.errorRed,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Sign out of your account',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade500 : AppTheme.textSecondary,
          ),
        ),
        onTap: _handleLogout,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
      ),
    );
  }
}
