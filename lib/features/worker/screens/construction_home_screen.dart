import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/features/worker/tabs/my_logs_tab.dart';
import 'package:houzzdat_app/features/worker/tabs/daily_tasks_tab.dart';
import 'package:houzzdat_app/features/worker/tabs/attendance_tab.dart';

/// Redesigned Worker Home Screen.
/// Theme: Primary 0xFF1A237E, Accent 0xFFFFCA28, Background 0xFFF5F7FA.
/// 3-tab BottomNavigationBar: My Logs, Tasks, Attendance.
/// Sticky AppBar with white bold text and a LogOut icon.
class ConstructionHomeScreen extends StatefulWidget {
  const ConstructionHomeScreen({super.key});

  @override
  State<ConstructionHomeScreen> createState() => _ConstructionHomeScreenState();
}

class _ConstructionHomeScreenState extends State<ConstructionHomeScreen> {
  final _supabase = Supabase.instance.client;

  String? _accountId;
  String? _projectId;
  String? _userId;
  bool _isInitializing = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      // Use CompanyContextService if available
      final companyService = CompanyContextService();
      if (companyService.isInitialized && companyService.activeAccountId != null) {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          // Still need project_id from users table
          final userData = await _supabase
              .from('users')
              .select('current_project_id')
              .eq('id', user.id)
              .single();
          if (mounted) {
            setState(() {
              _accountId = companyService.activeAccountId;
              _projectId = userData['current_project_id']?.toString();
              _userId = user.id;
              _isInitializing = false;
            });
          }
          return;
        }
      }

      // Fallback: legacy approach
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userData = await _supabase
            .from('users')
            .select('account_id, current_project_id')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _accountId = userData['account_id']?.toString();
            _projectId = userData['current_project_id']?.toString();
            _userId = user.id;
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _handleLogout() async {
    await CompanyContextService().reset();
    await _supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _accountId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A237E)),
        ),
      );
    }

    final tabs = [
      MyLogsTab(accountId: _accountId!, userId: _userId!, projectId: _projectId),
      DailyTasksTab(accountId: _accountId!, userId: _userId!),
      AttendanceTab(accountId: _accountId!, userId: _userId!, projectId: _projectId),
    ];

    final titles = ['MY LOGS', 'DAILY TASKS', 'ATTENDANCE'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1A237E),
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.fileAudio),
              activeIcon: Icon(LucideIcons.fileAudio),
              label: 'My Logs',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.clipboardList),
              activeIcon: Icon(LucideIcons.clipboardList),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.userCheck),
              activeIcon: Icon(LucideIcons.userCheck),
              label: 'Attendance',
            ),
          ],
        ),
      ),
    );
  }
}
