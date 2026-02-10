import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/dashboard/tabs/actions_kanban_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/sites_management_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/users_management_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/feed_tab.dart';
import 'package:houzzdat_app/features/dashboard/widgets/logout_dialog.dart';
import 'package:houzzdat_app/features/dashboard/widgets/custom_bottom_nav.dart';
import 'package:houzzdat_app/features/dashboard/widgets/layout_toggle_button.dart';
import 'package:houzzdat_app/features/dashboard/widgets/critical_alert_banner.dart';

class ManagerDashboardKanban extends StatefulWidget {
  const ManagerDashboardKanban({super.key});
  
  @override
  State<ManagerDashboardKanban> createState() => _ManagerDashboardKanbanState();
}

class _ManagerDashboardKanbanState extends State<ManagerDashboardKanban> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  
  String? _accountId;
  String? _projectId;
  String? _projectName;
  int _currentIndex = 0;
  bool _isRecording = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('users')
            .select('account_id, current_project_id')
            .eq('id', user.id)
            .single();
        final accountId = data['account_id']?.toString();
        final projectId = data['current_project_id']?.toString();

        // Fetch project name if a project is assigned
        String? projectName;
        if (projectId != null) {
          try {
            final project = await _supabase
                .from('projects')
                .select('name')
                .eq('id', projectId)
                .single();
            projectName = project['name']?.toString();
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _accountId = accountId;
            _projectId = projectId;
            _projectName = projectName;
            _isInitializing = false;
          });
        }
      } catch (e) {
        debugPrint('Error initializing manager: $e');
        if (mounted) setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LogoutDialog(),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
    }
  }

  Future<void> _handleCentralMicTap() async {
    if (_projectId == null || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No project assigned. Contact admin.')),
      );
      return;
    }

    if (!_isRecording) {
      await _recorderService.startRecording();
      setState(() => _isRecording = true);
    } else {
      setState(() => _isRecording = false);
      final bytes = await _recorderService.stopRecording();
      
      if (bytes != null) {
        await _recorderService.uploadAudio(
          bytes: bytes,
          projectId: _projectId!,
          userId: _supabase.auth.currentUser!.id,
          accountId: _accountId!,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice note submitted'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _accountId == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
        ),
      );
    }

    final tabs = [
      ActionsKanbanTab(accountId: _accountId!),
      SitesManagementTab(accountId: _accountId!),
      const SizedBox.shrink(), // Placeholder for central FAB
      UsersManagementTab(accountId: _accountId!),
      FeedTab(accountId: _accountId),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MANAGER DASHBOARD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_projectName != null)
              Text(_projectName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const LayoutToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          CriticalAlertBanner(
            accountId: _accountId!,
            onViewActions: () {
              setState(() => _currentIndex = 0);
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: (index) {
          if (index != 2) { // Skip central FAB index
            setState(() => _currentIndex = index);
          }
        },
        onCentralMicTap: _handleCentralMicTap,
        isRecording: _isRecording,
      ),
    );
  }
}