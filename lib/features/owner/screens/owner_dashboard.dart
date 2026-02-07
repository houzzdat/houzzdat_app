import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/notification_service.dart';
import 'package:houzzdat_app/features/owner/tabs/owner_projects_tab.dart';
import 'package:houzzdat_app/features/owner/tabs/owner_approvals_tab.dart';
import 'package:houzzdat_app/features/owner/tabs/owner_messages_tab.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();
  String? _accountId;
  String? _ownerId;
  String? _ownerName;
  int _currentIndex = 0;
  int _pendingApprovalCount = 0;
  int _unreadMessageCount = 0;
  StreamSubscription<int>? _notifSubscription;

  @override
  void initState() {
    super.initState();
    _initializeOwner();
  }

  Future<void> _initializeOwner() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('users')
          .select('account_id, full_name, email')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _accountId = data['account_id']?.toString();
          _ownerId = user.id;
          _ownerName = data['full_name'] ?? data['email'] ?? 'Owner';
        });
      }

      _loadPendingApprovalCount();
      _loadUnreadMessageCount();

      // Initialize notification service for real-time badge updates
      _notificationService.initialize(user.id);
      _notifSubscription = _notificationService.unreadCountStream.listen((count) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Error initializing owner: $e');
    }
  }

  Future<void> _loadPendingApprovalCount() async {
    if (_ownerId == null) return;
    try {
      final result = await _supabase
          .from('owner_approvals')
          .select('id')
          .eq('owner_id', _ownerId!)
          .eq('status', 'pending');

      if (mounted) {
        setState(() => _pendingApprovalCount = (result as List).length);
      }
    } catch (e) {
      debugPrint('Error loading approval count: $e');
    }
  }

  Future<void> _loadUnreadMessageCount() async {
    if (_ownerId == null) return;
    try {
      // Count voice notes directed to this owner that are recent (last 7 days)
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      // Get owner's project IDs
      final projectOwners = await _supabase
          .from('project_owners')
          .select('project_id')
          .eq('owner_id', _ownerId!);

      final projectIds = (projectOwners as List)
          .map((po) => po['project_id'] as String)
          .toList();

      if (projectIds.isEmpty) return;

      final result = await _supabase
          .from('voice_notes')
          .select('id')
          .eq('recipient_id', _ownerId!)
          .inFilter('project_id', projectIds)
          .gte('created_at', sevenDaysAgo);

      if (mounted) {
        setState(() => _unreadMessageCount = (result as List).length);
      }
    } catch (e) {
      debugPrint('Error loading unread message count: $e');
    }
  }

  Future<void> _handleLogout() async {
    _notifSubscription?.cancel();
    await _supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_accountId == null || _ownerId == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
        ),
      );
    }

    final tabs = [
      OwnerProjectsTab(ownerId: _ownerId!, accountId: _accountId!),
      OwnerApprovalsTab(
        ownerId: _ownerId!,
        accountId: _accountId!,
        onApprovalChanged: _loadPendingApprovalCount,
      ),
      OwnerMessagesTab(ownerId: _ownerId!, accountId: _accountId!),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text('Welcome, ${_ownerName ?? "Owner"}'),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryIndigo,
        unselectedItemColor: AppTheme.textSecondary,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingApprovalCount > 0,
              label: Text('$_pendingApprovalCount'),
              child: const Icon(Icons.approval),
            ),
            label: 'Approvals',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadMessageCount > 0,
              label: Text('$_unreadMessageCount'),
              child: const Icon(Icons.message),
            ),
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }
}
