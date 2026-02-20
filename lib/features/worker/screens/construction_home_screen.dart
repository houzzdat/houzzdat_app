import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/worker/tabs/my_logs_tab.dart';
import 'package:houzzdat_app/features/worker/tabs/daily_tasks_tab.dart';
import 'package:houzzdat_app/features/worker/tabs/attendance_tab.dart';
import 'package:houzzdat_app/features/worker/tabs/progress_tab.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/quick_tag_overlay.dart';

/// Worker Home Screen with persistent recording FAB visible on all tabs.
/// 4-tab BottomNavigationBar: My Logs, Tasks, Attendance, Progress.
/// Large 72px yellow FAB for voice recording on every screen.
class ConstructionHomeScreen extends StatefulWidget {
  const ConstructionHomeScreen({super.key});

  @override
  State<ConstructionHomeScreen> createState() => _ConstructionHomeScreenState();
}

class _ConstructionHomeScreenState extends State<ConstructionHomeScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();

  String? _accountId;
  String? _projectId;
  String? _userId;
  bool _isInitializing = true;
  int _currentIndex = 0;

  // Recording state
  bool _isRecording = false;
  bool _isUploading = false;
  bool _quickTagEnabled = true;

  // Pulsing animation for FAB
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Key to trigger reload on MyLogsTab after recording
  final _myLogsKey = GlobalKey<MyLogsTabState>();

  // Onboarding tooltip
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _checkOnboarding();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCount = prefs.getInt('worker_session_count') ?? 0;
    await prefs.setInt('worker_session_count', sessionCount + 1);
    // Show onboarding hint for the first 3 sessions
    if (sessionCount < 3 && mounted) {
      setState(() => _showOnboarding = true);
    }
  }

  void _dismissOnboarding() async {
    setState(() => _showOnboarding = false);
    // Mark as permanently dismissed after tap
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('worker_session_count', 3);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final companyService = CompanyContextService();
      if (companyService.isInitialized && companyService.activeAccountId != null) {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          final userData = await _supabase
              .from('users')
              .select('current_project_id, quick_tag_enabled')
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
          _resolveQuickTagSetting(userData['quick_tag_enabled']);
          return;
        }
      }

      // Fallback: legacy approach
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userData = await _supabase
            .from('users')
            .select('account_id, current_project_id, quick_tag_enabled')
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
        _resolveQuickTagSetting(userData['quick_tag_enabled']);
      }
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _resolveQuickTagSetting(dynamic userSetting) async {
    if (userSetting != null) {
      if (mounted) setState(() => _quickTagEnabled = userSetting as bool);
      return;
    }
    // Fall back to account-level default
    try {
      if (_accountId != null) {
        final accountData = await _supabase
            .from('accounts')
            .select('quick_tag_default')
            .eq('id', _accountId!)
            .single();
        final defaultVal = accountData['quick_tag_default'] ?? true;
        if (mounted) setState(() => _quickTagEnabled = defaultVal as bool);
      }
    } catch (e) {
      debugPrint('Error resolving quick-tag default: $e');
    }
  }

  Future<void> _handleLogout() async {
    await CompanyContextService().reset();
    await _supabase.auth.signOut();
  }

  /// Persistent recording handler — accessible from any tab via FAB.
  Future<void> _handleRecording() async {
    final hasPermission = await _recorderService.checkPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    if (!_isRecording) {
      if (_projectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No project assigned. Please contact your manager.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }
      await _recorderService.startRecording();
      setState(() {
        _isRecording = true;
        _showOnboarding = false;
      });
    } else {
      setState(() {
        _isRecording = false;
        _isUploading = true;
      });

      try {
        final audioBytes = await _recorderService.stopRecording();
        if (audioBytes != null && _projectId != null) {
          final result = await _recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: _projectId!,
            userId: _userId!,
            accountId: _accountId!,
          );

          if (mounted && result != null) {
            final voiceNoteId = result['id']!;

            if (_quickTagEnabled) {
              QuickTagOverlay.show(
                context,
                voiceNoteId: voiceNoteId,
                quickTagEnabled: true,
                onDismissed: () {
                  if (mounted) _showSuccessOverlay();
                },
              );
            } else {
              _showSuccessOverlay();
            }

            // Refresh My Logs tab if visible
            _myLogsKey.currentState?.refreshNotes();
          }
        }
      } catch (e) {
        debugPrint('Recording error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not send voice note. Please try again.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showSuccessOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successGreen, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'Sent!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    // Auto-dismiss after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? const Color(0xFF1A237E) : Colors.grey.shade400,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: isActive ? 12 : 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? const Color(0xFF1A237E) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
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
      MyLogsTab(key: _myLogsKey, accountId: _accountId!, userId: _userId!, projectId: _projectId),
      DailyTasksTab(accountId: _accountId!, userId: _userId!),
      AttendanceTab(accountId: _accountId!, userId: _userId!, projectId: _projectId),
      ProgressTab(accountId: _accountId!, userId: _userId!, projectId: _projectId),
    ];

    final titles = ['MY LOGS', 'DAILY TASKS', 'ATTENDANCE', 'PROGRESS'];

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
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: tabs,
          ),
          // Onboarding tooltip pointing at the FAB
          if (_showOnboarding && !_isRecording && !_isUploading)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _dismissOnboarding,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.handMetal, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Tap to record',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // Onboarding tooltip overlay
      resizeToAvoidBottomInset: false,

      // Persistent recording FAB — visible on ALL tabs
      floatingActionButton: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? 1.0 : _pulseAnimation.value,
            child: SizedBox(
              width: 72,
              height: 72,
              child: FloatingActionButton(
                onPressed: _isUploading ? null : _handleRecording,
                backgroundColor: _isRecording
                    ? Colors.red
                    : _isUploading
                        ? Colors.grey
                        : const Color(0xFFFFCA28),
                elevation: 6,
                shape: const CircleBorder(),
                child: _isUploading
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                      )
                    : Icon(
                        _isRecording ? LucideIcons.square : LucideIcons.mic,
                        size: 32,
                        color: Colors.black,
                      ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: LucideIcons.fileAudio,
                label: 'My Logs',
                index: 0,
              ),
              _buildNavItem(
                icon: LucideIcons.clipboardList,
                label: 'Tasks',
                index: 1,
              ),
              const SizedBox(width: 80), // Space for FAB
              _buildNavItem(
                icon: LucideIcons.userCheck,
                label: 'Attendance',
                index: 2,
              ),
              _buildNavItem(
                icon: LucideIcons.barChart2,
                label: 'Progress',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
