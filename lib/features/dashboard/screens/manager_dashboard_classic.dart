import 'dart:async';
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
import 'package:houzzdat_app/core/widgets/offline_banner.dart';
import 'package:houzzdat_app/features/dashboard/widgets/custom_bottom_nav.dart';
import 'package:houzzdat_app/features/dashboard/widgets/recipient_selector_dialog.dart';
import 'package:houzzdat_app/features/dashboard/widgets/broadcast_voice_dialog.dart';
import 'package:houzzdat_app/features/reports/screens/reports_screen.dart';
import 'package:houzzdat_app/features/insights/screens/insights_screen.dart';
import 'package:houzzdat_app/features/documents/screens/documents_screen.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/quick_tag_overlay.dart';
import 'package:houzzdat_app/features/dashboard/widgets/recording_preview_dialog.dart';
import 'package:houzzdat_app/features/settings/screens/settings_screen.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';
import 'package:houzzdat_app/core/widgets/responsive_layout.dart';
import 'package:houzzdat_app/core/widgets/onboarding_overlay.dart';
import 'package:houzzdat_app/core/services/error_logging_service.dart';
import 'package:houzzdat_app/l10n/app_strings.dart';

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
  int _currentIndex = 1;
  bool _isRecording = false;
  bool _isUploading = false;
  bool _quickTagEnabled = true;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

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
    _recordingTimer?.cancel();
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
      _showOnboardingIfNeeded();
      return;
    }

    // Fallback: legacy approach
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('users').select('account_id').eq('id', user.id).maybeSingle(); // UX-audit CI-01
      if (data == null) return;
      if (mounted) setState(() => _accountId = data['account_id']?.toString());
      _loadQuickTagSetting();
    }
  }

  // UX-audit #11: First-login onboarding coach marks
  Future<void> _showOnboardingIfNeeded() async {
    // Slight delay so UI renders first
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await OnboardingOverlay.maybeShow(
      context,
      key: 'manager_dashboard',
      steps: const [
        OnboardingStep(
          title: AppStrings.onboardingRecordTitle,
          subtitle: AppStrings.onboardingRecordSubtitle,
          icon: Icons.mic,
        ),
        OnboardingStep(
          title: AppStrings.onboardingTriageTitle,
          subtitle: AppStrings.onboardingTriageSubtitle,
          icon: Icons.checklist,
        ),
        OnboardingStep(
          title: AppStrings.onboardingTrackTitle,
          subtitle: AppStrings.onboardingTrackSubtitle,
          icon: Icons.insights,
        ),
        OnboardingStep(
          title: AppStrings.onboardingReportsTitle,
          subtitle: AppStrings.onboardingReportsSubtitle,
          icon: Icons.assessment,
        ),
      ],
    );
  }

  Future<void> _loadQuickTagSetting() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || _accountId == null) return;

      final userData = await _supabase
          .from('users')
          .select('quick_tag_enabled')
          .eq('id', user.id)
          .maybeSingle(); // UX-audit CI-01

      final accountData = await _supabase
          .from('accounts')
          .select('quick_tag_default')
          .eq('id', _accountId!)
          .maybeSingle(); // UX-audit CI-01

      final enabled = userData?['quick_tag_enabled']
          ?? accountData?['quick_tag_default']
          ?? true;

      if (mounted) setState(() => _quickTagEnabled = enabled == true); // UX-audit CI-04: safe bool
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ManagerDashboardClassicState._loadQuickTagSetting');
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

  /// Handles recording a project note with preview before submit.
  Future<void> _handleProjectNote() async {
    if (!_isRecording) {
      await _recorderService.startRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordingDuration = Duration(seconds: timer.tick));
        }
      });
    } else {
      _recordingTimer?.cancel();
      setState(() => _isRecording = false);
      final bytes = await _recorderService.stopRecording();

      if (bytes != null && mounted) {
        // Show preview dialog before uploading
        final shouldSubmit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RecordingPreviewDialog(
            audioBytes: bytes,
            recordingDuration: _recordingDuration,
            contextLabel: 'Project voice note',
          ),
        );

        if (shouldSubmit != true || !mounted) return;

        // User confirmed — proceed with upload
        setState(() => _isUploading = true);
        final user = _supabase.auth.currentUser;
        if (user != null) {
          try {
            final userData = await _supabase
                .from('users')
                .select('current_project_id')
                .eq('id', user.id)
                .maybeSingle(); // UX-audit CI-01
            final projectId = userData?['current_project_id']?.toString();

            if (projectId != null) {
              final result = await _recorderService.uploadAudio(
                bytes: bytes,
                projectId: projectId,
                userId: user.id,
                accountId: _accountId!,
              );

              if (mounted) {
                setState(() => _isUploading = false);
                if (result != null) {
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
            } else {
              if (mounted) setState(() => _isUploading = false);
            }
          } catch (e, st) {
            ErrorLogging.capture(e, stackTrace: st, context: '_ManagerDashboardClassicState._handleProjectNote');
            if (mounted) setState(() => _isUploading = false);
          }
        } else {
          if (mounted) setState(() => _isUploading = false);
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
          .maybeSingle(); // UX-audit CI-01
      final projectId = userData?['current_project_id']?.toString() ?? '';

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
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_ManagerDashboardClassicState._handleBroadcast');
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
        body: ShimmerLoadingList(), // UX-audit #4: shimmer instead of spinner
      );
    }

    final accountId = _accountId!;

    // Map bottom nav indices to tabs:
    // 0 = Actions, 1 = Insights, 2 = Central FAB (placeholder), 3 = Team, 4 = Finance, 5 = Documents
    final tabs = [
      ActionsTab(accountId: accountId),
      InsightsTabBody(accountId: accountId),
      const SizedBox.shrink(), // Placeholder for central FAB
      TeamTab(accountId: accountId),
      FinanceTab(accountId: accountId),
      DocumentsTabBody(accountId: accountId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MANAGER DASHBOARD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.business_rounded),
            onPressed: () {
              Navigator.of(context).push(
                FadeSlideRoute(
                  page: Scaffold(
                    appBar: AppBar(
                      title: const Text('SITES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      backgroundColor: AppTheme.primaryIndigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    body: ProjectsTab(accountId: accountId),
                  ),
                ),
              );
            },
            tooltip: 'Sites',
          ),
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () {
              Navigator.of(context).push(
                FadeSlideRoute(page: ReportsScreen(accountId: accountId)),
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
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                FadeSlideRoute(page: SettingsScreen(
                  role: 'manager',
                  accountId: accountId,
                )),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= Breakpoints.tablet;

          if (isTablet) {
            // UX-audit #2: NavigationRail on tablet
            // Map real tab indices (0,1,3,4) to rail indices (0,1,2,3), skipping FAB placeholder at 2
            final railIndex = _currentIndex > 2 ? _currentIndex - 1 : _currentIndex;

            return Column(
              children: [
                const OfflineBanner(),
                CriticalAlertBanner(
                  accountId: accountId,
                  onViewActions: () => setState(() => _currentIndex = 0),
                ),
                Expanded(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: railIndex.clamp(0, 3),
                        onDestinationSelected: (index) {
                          // Map rail index back: 0→0, 1→1, 2→3, 3→4
                          final tabIndex = index >= 2 ? index + 1 : index;
                          setState(() => _currentIndex = tabIndex);
                        },
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Theme.of(context).cardColor,
                        selectedIconTheme: const IconThemeData(color: AppTheme.primaryIndigo),
                        unselectedIconTheme: const IconThemeData(color: AppTheme.textSecondary),
                        selectedLabelTextStyle: const TextStyle(
                          color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600, fontSize: 12,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12,
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.checklist_outlined),
                            selectedIcon: Icon(Icons.checklist),
                            label: Text('Actions'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.insights_outlined),
                            selectedIcon: Icon(Icons.insights),
                            label: Text('Insights'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.people_outlined),
                            selectedIcon: Icon(Icons.people),
                            label: Text('Team'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            selectedIcon: Icon(Icons.account_balance_wallet),
                            label: Text('Finance'),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ContentConstraint(
                          maxContentWidth: 1200,
                          child: IndexedStack(
                            index: _currentIndex,
                            children: tabs,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Phone: standard layout
          return Column(
            children: [
              const OfflineBanner(),
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
          );
        },
      ),
      // Persistent recording FAB — visible on ALL tabs
      floatingActionButton: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? 1.0 : _pulseAnimation.value,
            child: Semantics(
              label: _isRecording
                  ? 'Stop recording voice note'
                  : _isUploading
                      ? 'Uploading voice note'
                      : 'Record voice note. Long press to broadcast.',
              button: true,
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
                            : AppTheme.accentAmberLight,
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
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // UX-audit #2: Hide bottom nav on tablet (NavigationRail used instead)
      bottomNavigationBar: MediaQuery.of(context).size.width >= Breakpoints.tablet
          ? null
          : CustomBottomNav(
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
