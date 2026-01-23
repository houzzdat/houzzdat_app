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
    // Listen to Auth State changes reactively
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // If no session, show Login
        if (session == null) {
          return const LoginScreen();
        }

        // If there is a session, determine the role
        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserRole(session.user.id),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userData = roleSnapshot.data;

            // Handle Super Admin (returns null in your current logic)
            if (userData == null) {
              return const SuperAdminScreen();
            }

            final role = userData['role'];
            if (role == 'manager' || role == 'admin') {
              return const ManagerDashboard();
            } else {
              return const ConstructionHomeScreen();
            }
          },
        );
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