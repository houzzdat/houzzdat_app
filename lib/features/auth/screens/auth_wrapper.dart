import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/features/auth/screens/login_screen.dart';
import 'package:houzzdat_app/features/auth/screens/super_admin_screen.dart';
import 'package:houzzdat_app/features/dashboard/screens/manager_dashboard.dart';
import 'package:houzzdat_app/features/worker/screens/construction_home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserRole(session.user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Auth Sync Error: ${snapshot.error}"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(), 
                    child: const Text("Reset Session")
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = snapshot.data;
        
        // Check if user is super admin
        if (userData == null) {
          // User might be a super admin (not in users table)
          return const SuperAdminScreen();
        }

        final role = userData['role'];

        // Managers and Admins go to the Dashboard
        if (role == 'manager' || role == 'admin') {
          return const ManagerDashboard();
        } else {
          return const ConstructionHomeScreen();
        }
      },
    );
  }

  Future<Map<String, dynamic>?> _getUserRole(String userId) async {
    try {
      // First check if user is a super admin
      final superAdminCheck = await Supabase.instance.client
          .from('super_admins')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      
      if (superAdminCheck != null) {
        // User is a super admin, return null to trigger super admin screen
        return null;
      }
      
      // Check regular users table
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint("Error fetching user role: $e");
      // If user not found in either table, return null
      return null;
    }
  }
}