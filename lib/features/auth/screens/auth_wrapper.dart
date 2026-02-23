import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/features/auth/screens/login_screen.dart';
import 'package:houzzdat_app/features/auth/screens/set_password_screen.dart';
import 'package:houzzdat_app/features/auth/screens/super_admin_screen.dart';
import 'package:houzzdat_app/features/auth/screens/company_selector_screen.dart';
import 'package:houzzdat_app/features/dashboard/screens/manager_dashboard.dart';
import 'package:houzzdat_app/features/worker/screens/construction_home_screen.dart';
import 'package:houzzdat_app/features/owner/screens/owner_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to Auth State changes reactively
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // If no session, show Login
        if (session == null) {
          return const LoginScreen();
        }

        // First login: user has temp password and must set their own
        final mustChangePassword =
            session.user.userMetadata?['must_change_password'] == true;
        if (mustChangePassword) {
          return const SetPasswordScreen(
            purpose: SetPasswordPurpose.firstLogin,
          );
        }

        // If there is a session, resolve user context
        return FutureBuilder<_AuthResult>(
          future: _resolveUserContext(session.user.id),
          builder: (context, resultSnapshot) {
            if (resultSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: AppTheme.backgroundGrey,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primaryIndigo),
                      const SizedBox(height: AppTheme.spacingL),
                      Text(
                        'Setting up your workspace...',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (resultSnapshot.hasError || !resultSnapshot.hasData) {
              return _buildErrorScreen(
                context,
                error: resultSnapshot.error,
                onRetry: () {
                  // Force the StreamBuilder to rebuild, which re-triggers FutureBuilder
                  (context as Element).markNeedsBuild();
                },
              );
            }

            final result = resultSnapshot.data!;

            switch (result.type) {
              case _AuthResultType.superAdmin:
                return const SuperAdminScreen();
              case _AuthResultType.companySelector:
                return const CompanySelectorScreen();
              case _AuthResultType.dashboard:
                return _buildDashboard(result.role ?? 'worker');
              case _AuthResultType.noCompanies:
                return Scaffold(
                  backgroundColor: AppTheme.backgroundGrey,
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            'No Active Companies',
                            style: AppTheme.headingMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            'Your account is not linked to any active company.\nAsk your company administrator to add you.',
                            textAlign: TextAlign.center,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXL),
                          OutlinedButton.icon(
                            onPressed: () {
                              (context as Element).markNeedsBuild();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check Again'),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          TextButton(
                            onPressed: () => Supabase.instance.client.auth.signOut(),
                            child: Text(
                              'Sign Out',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
            }
          },
        );
      },
    );
  }

  Widget _buildErrorScreen(BuildContext context, {Object? error, VoidCallback? onRetry}) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppTheme.errorRed),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Something went wrong',
                style: AppTheme.headingMedium,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'We couldn\'t load your account. Please try again.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      'Show technical details',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                        child: Text(
                          error.toString(),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: Text(
                  'Sign Out',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(String role) {
    if (role == 'owner') {
      return const OwnerDashboard();
    } else if (role == 'manager' || role == 'admin') {
      return const ManagerDashboard();
    } else {
      return const ConstructionHomeScreen();
    }
  }

  Future<_AuthResult> _resolveUserContext(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final companyService = CompanyContextService();

      // 1. Check if user is a super admin
      final superAdminCheck = await supabase
          .from('super_admins')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (superAdminCheck != null) {
        return _AuthResult(type: _AuthResultType.superAdmin);
      }

      // 2. Initialize company context service
      await companyService.initialize(userId);

      // 3. Check active companies
      if (companyService.activeCompanies.isEmpty) {
        return _AuthResult(type: _AuthResultType.noCompanies);
      }

      // 4. Single company - auto-select and route to dashboard
      if (!companyService.hasMultipleCompanies) {
        // Auto-select the only company
        final company = companyService.activeCompanies.first;
        await companyService.switchCompany(company.accountId);
        return _AuthResult(
          type: _AuthResultType.dashboard,
          role: company.role,
        );
      }

      // 5. Multiple companies - check for saved selection
      final hasSaved = await companyService.hasSavedSelection();
      if (hasSaved && companyService.hasActiveCompany) {
        return _AuthResult(
          type: _AuthResultType.dashboard,
          role: companyService.activeRole,
        );
      }

      // 6. Multiple companies, no saved selection - show selector
      return _AuthResult(type: _AuthResultType.companySelector);
    } catch (e) {
      debugPrint("Error resolving user context: $e");

      // Fallback: try legacy single-company approach
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('role, account_id')
            .eq('id', userId)
            .maybeSingle();

        if (response == null) {
          return _AuthResult(type: _AuthResultType.noCompanies);
        }

        // Initialize context service with fallback
        final companyService = CompanyContextService();
        await companyService.initialize(userId);

        return _AuthResult(
          type: _AuthResultType.dashboard,
          role: response['role']?.toString(),
        );
      } catch (fallbackError) {
        debugPrint("Fallback also failed: $fallbackError");
        return _AuthResult(type: _AuthResultType.noCompanies);
      }
    }
  }
}

enum _AuthResultType {
  superAdmin,
  companySelector,
  dashboard,
  noCompanies,
}

class _AuthResult {
  final _AuthResultType type;
  final String? role;

  _AuthResult({required this.type, this.role});
}
