import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/features/dashboard/tabs/actions_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/projects_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/team_tab.dart';
import 'package:houzzdat_app/features/finance/tabs/finance_tab.dart';
import 'package:houzzdat_app/features/dashboard/widgets/critical_alert_banner.dart';
import 'package:houzzdat_app/features/dashboard/widgets/custom_bottom_nav.dart';
import 'package:houzzdat_app/features/dashboard/widgets/logout_dialog.dart';
import 'package:houzzdat_app/features/reports/screens/reports_screen.dart';

class ManagerDashboardClassic extends StatefulWidget {
  const ManagerDashboardClassic({super.key});
  @override
  State<ManagerDashboardClassic> createState() => _ManagerDashboardClassicState();
}

class _ManagerDashboardClassicState extends State<ManagerDashboardClassic> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  final _companyService = CompanyContextService();

  String? _accountId;
  int _currentIndex = 0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeManager();
    _companyService.addListener(_onCompanyChanged);
  }

  @override
  void dispose() {
    _companyService.removeListener(_onCompanyChanged);
    super.dispose();
  }

  void _onCompanyChanged() {
    if (mounted && _companyService.activeAccountId != _accountId) {
      setState(() => _accountId = _companyService.activeAccountId);
    }
  }

  Future<void> _initializeManager() async {
    // Use CompanyContextService (already initialized by AuthWrapper)
    final companyService = CompanyContextService();
    if (companyService.isInitialized && companyService.activeAccountId != null) {
      if (mounted) {
        setState(() => _accountId = companyService.activeAccountId);
      }
      return;
    }

    // Fallback: legacy approach
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('users').select('account_id').eq('id', user.id).single();
      if (mounted) setState(() => _accountId = data['account_id']?.toString());
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LogoutDialog(),
    );

    if (confirm == true) {
      await CompanyContextService().reset();
      await _supabase.auth.signOut();
    }
  }

  void _handleSwitchCompany() {
    // Navigate back to AuthWrapper which will show the company selector
    CompanyContextService().reset().then((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    });
  }

  Future<void> _handleCentralMicTap() async {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account found. Contact admin.')),
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
        // Get current user's project
        final user = _supabase.auth.currentUser;
        if (user != null) {
          try {
            final userData = await _supabase
                .from('users')
                .select('current_project_id')
                .eq('id', user.id)
                .single();
            final projectId = userData['current_project_id']?.toString();

            if (projectId != null) {
              await _recorderService.uploadAudio(
                bytes: bytes,
                projectId: projectId,
                userId: user.id,
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
          } catch (e) {
            debugPrint('Error uploading voice note: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accountId == null || _accountId!.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
        ),
      );
    }

    final accountId = _accountId!;

    // Map bottom nav indices to tabs:
    // 0 = Actions, 1 = Sites, 2 = Central FAB (placeholder), 3 = Team, 4 = Feed
    final tabs = [
      ActionsTab(accountId: accountId),
      ProjectsTab(accountId: accountId),
      const SizedBox.shrink(), // Placeholder for central FAB
      TeamTab(accountId: accountId),
      FinanceTab(accountId: accountId),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('MANAGER DASHBOARD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ReportsScreen(accountId: accountId),
                ),
              );
            },
            tooltip: 'Reports',
          ),
          if (_companyService.hasMultipleCompanies)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: _handleSwitchCompany,
              tooltip: 'Switch Company',
            ),
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
            accountId: accountId,
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
          if (index != 2) {
            setState(() => _currentIndex = index);
          }
        },
        onCentralMicTap: _handleCentralMicTap,
        isRecording: _isRecording,
      ),
    );
  }
}
