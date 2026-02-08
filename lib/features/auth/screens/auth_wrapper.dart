import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/features/auth/screens/login_screen.dart';
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

        // If there is a session, resolve user context
        return FutureBuilder<_AuthResult>(
          future: _resolveUserContext(session.user.id),
          builder: (context, resultSnapshot) {
            if (resultSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (resultSnapshot.hasError || !resultSnapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading account',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        resultSnapshot.error?.toString() ?? 'Unknown error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Supabase.instance.client.auth.signOut(),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
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
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.business_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No active companies',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You are not associated with any active company.\nContact your administrator.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Supabase.instance.client.auth.signOut(),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                );
            }
          },
        );
      },
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
