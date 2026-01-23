import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/features/dashboard/tabs/actions_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/projects_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/team_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/feed_tab.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final _supabase = Supabase.instance.client;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('users').select('account_id').eq('id', user.id).single();
      if (mounted) setState(() => _accountId = data['account_id']?.toString());
    }
  }

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
    // AuthWrapper will handle navigation automatically
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CRITICAL FIX: Show loading until accountId is ready
    // Changed condition to check for empty string too
    if (_accountId == null || _accountId!.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F4F4),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A237E)),
        ),
      );
    }

    // ✅ Now accountId is guaranteed to be valid
    // Use non-null assertion safely
    final accountId = _accountId!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: AppBar(
          title: const Text("MANAGER DASHBOARD"), 
          backgroundColor: const Color(0xFF1A237E), 
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.checklist), text: "ACTIONS"),
              Tab(icon: Icon(Icons.business), text: "SITES"),
              Tab(icon: Icon(Icons.people), text: "TEAM"),
              Tab(icon: Icon(Icons.feed), text: "FEED")
            ]
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout), 
              onPressed: _handleLogout
            )
          ],
        ),
        body: TabBarView(
          children: [ 
            ActionsTab(accountId: accountId), 
            ProjectsTab(accountId: accountId), 
            TeamTab(accountId: accountId), 
            FeedTab(accountId: accountId) 
          ]
        ),
      ),
    );
  }
}