import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/tabs/actions_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/projects_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/team_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/feed_tab.dart';
import 'package:houzzdat_app/features/dashboard/widgets/layout_toggle_button.dart'; // Add this import

class ManagerDashboardClassic extends StatefulWidget {
  const ManagerDashboardClassic({super.key});
  @override
  State<ManagerDashboardClassic> createState() => _ManagerDashboardClassicState();
}

class _ManagerDashboardClassicState extends State<ManagerDashboardClassic> {
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
        backgroundColor: AppTheme.backgroundGrey,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
        ),
      );
    }

    // ✅ Now accountId is guaranteed to be valid
    // Use non-null assertion safely
    final accountId = _accountId!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        appBar: AppBar(
          title: const Text("MANAGER DASHBOARD"),
          backgroundColor: AppTheme.primaryIndigo,
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
            const LayoutToggleButton(),
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