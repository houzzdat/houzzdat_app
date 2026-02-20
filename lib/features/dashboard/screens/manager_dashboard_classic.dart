import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/core/services/broadcast_service.dart';
import 'package:houzzdat_app/features/dashboard/tabs/actions_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/projects_tab.dart';
import 'package:houzzdat_app/features/dashboard/tabs/team_tab.dart';
import 'package:houzzdat_app/features/finance/tabs/finance_tab.dart';
import 'package:houzzdat_app/features/dashboard/widgets/critical_alert_banner.dart';
import 'package:houzzdat_app/features/dashboard/widgets/custom_bottom_nav.dart';
import 'package:houzzdat_app/features/dashboard/widgets/logout_dialog.dart';
import 'package:houzzdat_app/features/dashboard/widgets/recipient_selector_dialog.dart';
import 'package:houzzdat_app/features/dashboard/widgets/broadcast_voice_dialog.dart';
import 'package:houzzdat_app/features/reports/screens/reports_screen.dart';
import 'package:houzzdat_app/features/insights/screens/insights_screen.dart';
import 'package:houzzdat_app/features/dashboard/widgets/confidence_calibration_widget.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/quick_tag_overlay.dart';
import 'package:houzzdat_app/features/insights/services/review_queue_service.dart';

class ManagerDashboardClassic extends StatefulWidget {
  const ManagerDashboardClassic({super.key});
  @override
  State<ManagerDashboardClassic> createState() => _ManagerDashboardClassicState();
}

class _ManagerDashboardClassicState extends State<ManagerDashboardClassic>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  final _companyService = CompanyContextService();

  String? _accountId;
  int _currentIndex = 0;
  bool _isRecording = false;
  bool _isUploading = false;
  bool _quickTagEnabled = true;
  int _reviewBadgeCount = 0;

  // Pulsing animation for FAB
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeManager();
    _companyService.addListener(_onCompanyChanged);

    // Initialize pulsing animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
      _loadQuickTagSetting();
      _loadReviewBadgeCount();
      return;
    }

    // Fallback: legacy approach
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('users').select('account_id').eq('id', user.id).single();
      if (mounted) setState(() => _accountId = data['account_id']?.toString());
      _loadQuickTagSetting();
      _loadReviewBadgeCount();
    }
  }

  Future<void> _loadQuickTagSetting() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || _accountId == null) return;

      final userData = await _supabase
          .from('users')
          .select('quick_tag_enabled')
          .eq('id', user.id)
          .single();

      final accountData = await _supabase
          .from('accounts')
          .select('quick_tag_default')
          .eq('id', _accountId!)
          .single();

      final enabled = userData['quick_tag_enabled']
          ?? accountData['quick_tag_default']
          ?? true;

      if (mounted) setState(() => _quickTagEnabled = enabled as bool);
    } catch (e) {
      debugPrint('Error loading quick-tag setting: $e');
    }
  }

  Future<void> _loadReviewBadgeCount() async {
    if (_accountId == null) return;
    try {
      final count = await ReviewQueueService().getUnreviewedCount(_accountId!);
      if (mounted) setState(() => _reviewBadgeCount = count);
    } catch (e) {
      debugPrint('Error loading review badge count: $e');
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

  /// Show settings bottom sheet with AI calibration widget.
  void _showSettingsSheet(String accountId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('AI SETTINGS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: ConfidenceCalibrationWidget(accountId: accountId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single tap on central mic → project note (most common action).
  Future<void> _handleCentralMicTap() async {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account found. Contact admin.')),
      );
      return;
    }
    await _handleProjectNote();
  }

  /// Long-press on central mic → broadcast to team members.
  Future<void> _handleCentralMicLongPress() async {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account found. Contact admin.')),
      );
      return;
    }
    await _handleBroadcast();
  }

  /// Handles recording a project note (existing behavior)
  Future<void> _handleProjectNote() async {
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
              final result = await _recorderService.uploadAudio(
                bytes: bytes,
                projectId: projectId,
                userId: user.id,
                accountId: _accountId!,
              );

              if (mounted && result != null) {
                final voiceNoteId = result['id']!;

                void showSuccessSnackbar() {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice note submitted'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                }

                if (_quickTagEnabled) {
                  QuickTagOverlay.show(
                    context,
                    voiceNoteId: voiceNoteId,
                    quickTagEnabled: true,
                    onDismissed: showSuccessSnackbar,
                  );
                } else {
                  showSuccessSnackbar();
                }
              }
            }
          } catch (e) {
            debugPrint('Error uploading voice note: $e');
          }
        }
      }
    }
  }

  /// Handles broadcasting a message to selected team members
  Future<void> _handleBroadcast() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Step 1: Select recipients
    if (!mounted) return;
    final recipients = await showDialog<List<String>>(
      context: context,
      builder: (context) => RecipientSelectorDialog(
        accountId: _accountId!,
        managerId: user.id,
      ),
    );

    if (!mounted) return;
    if (recipients == null || recipients.isEmpty) return;

    // Step 2: Record voice with confirmation
    if (!mounted) return;
    final recordingResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BroadcastVoiceDialog(
        accountId: _accountId!,
        projectId: '', // Broadcasts aren't tied to specific projects
        recipientCount: recipients.length,
      ),
    );

    if (!mounted) return;
    if (recordingResult == null) return; // User cancelled

    final audioBytes = recordingResult['audioBytes'] as Uint8List;
    final textNote = recordingResult['textNote'] as String?;

    // Step 3: Send broadcast
    try {
      // Get current project ID for the broadcast
      final userData = await _supabase
          .from('users')
          .select('current_project_id')
          .eq('id', user.id)
          .single();
      final projectId = userData['current_project_id']?.toString() ?? '';

      final result = await BroadcastService().sendBroadcast(
        audioBytes: audioBytes,
        accountId: _accountId!,
        projectId: projectId,
        senderId: user.id,
        recipientIds: recipients,
        textNote: textNote,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Broadcast sent to ${result.recipientCount} team members'),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send broadcast'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
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
            icon: Badge(
              isLabelVisible: _reviewBadgeCount > 0,
              label: Text(
                _reviewBadgeCount > 99 ? '99+' : '$_reviewBadgeCount',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.insights),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InsightsScreen(accountId: accountId),
                ),
              ).then((_) => _loadReviewBadgeCount());
            },
            tooltip: 'Insights',
          ),
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
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showSettingsSheet(accountId),
            tooltip: 'Settings',
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
      // Persistent recording FAB — visible on ALL tabs
      floatingActionButton: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? 1.0 : _pulseAnimation.value,
            child: GestureDetector(
              onTap: _isUploading ? null : _handleCentralMicTap,
              onLongPress: _isUploading ? null : _handleCentralMicLongPress,
              child: SizedBox(
                width: 72,
                height: 72,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red
                        : _isUploading
                            ? Colors.grey
                            : const Color(0xFFFFCA28),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _isUploading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 3),
                          ),
                        )
                      : Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 32,
                          color: Colors.black,
                        ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: (index) {
          if (index != 2) {
            setState(() => _currentIndex = index);
          }
        },
      ),
    );
  }
}
