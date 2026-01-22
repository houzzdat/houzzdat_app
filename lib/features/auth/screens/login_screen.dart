import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/features/auth/screens/auth_wrapper.dart';
import 'package:houzzdat_app/features/auth/screens/super_admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // Attempt to sign in
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      final userId = response.user?.id;
      
      if (userId != null && mounted) {
        // Check if user is a super admin first
        final superAdminCheck = await Supabase.instance.client
            .from('super_admins')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
        
        if (superAdminCheck != null) {
          // User is a super admin
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const SuperAdminScreen())
          );
          return;
        }
        
        // Check if user exists in users table
        final userRecord = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
        
        if (userRecord != null) {
          // Regular user - go to AuthWrapper which will route based on role
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const AuthWrapper())
          );
        } else {
          // User exists in auth but not in any table
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User account not properly configured"))
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: $e"))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 80, color: Color(0xFFFFC107)),
            const SizedBox(height: 20),
            const Text(
              "HOUZZDAT", 
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController, 
              decoration: const InputDecoration(filled: true, fillColor: Colors.white, hintText: "Email")
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController, 
              obscureText: true, 
              decoration: const InputDecoration(filled: true, fillColor: Colors.white, hintText: "Password")
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107)),
                onPressed: _isLoading ? null : _signIn,
                child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text("SIGN IN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}