import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/notification_service.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/core/widgets/responsive_layout.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/owner/tabs/owner_projects_tab.dart';
import 'package:houzzdat_app/features/owner/tabs/owner_approvals_tab.dart';
import 'package:houzzdat_app/features/owner/tabs/owner_messages_tab.dart';
import 'package:houzzdat_app/features/owner/tabs/owner_reports_tab.dart';
import 'package:houzzdat_app/features/insights/screens/insights_screen.dart';
import 'package:houzzdat_app/features/settings/screens/settings_screen.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';
import 'package:houzzdat_app/core/services/error_logging_service.dart';

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
  int _projectCount = 0;
  int _pendingApprovalCount = 0;
  int _unreadMessageCount = 0;
  int _newReportCount = 0;
  double? _netCashPosition; // UX-audit PP-10: net cash position across all projects
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
      // Use CompanyContextService if available
      final companyService = CompanyContextService();
      String? accountId;
      if (companyService.isInitialized && companyService.activeAccountId != null) {
        accountId = companyService.activeAccountId;
      }

      final data = await _supabase
          .from('users')
          .select('account_id, full_name, email')
          .eq('id', user.id)
          .maybeSingle(); // UX-audit CI-01

      if (mounted) {
        setState(() {
          _accountId = accountId ?? data?['account_id']?.toString();
          _ownerId = user.id;
          _ownerName = data?['full_name'] ?? data?['email'] ?? 'Owner';
        });
      }

      _loadProjectCount();
      _loadPendingApprovalCount();
      _loadUnreadMessageCount();
      _loadNewReportCount();
      _loadNetCashPosition(); // UX-audit PP-10

      // Initialize notification service for real-time badge updates
      _notificationService.initialize(user.id);
      _notifSubscription = _notificationService.unreadCountStream.listen((count) {
        if (mounted) setState(() {});
      });
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_OwnerDashboardState._initializeOwner');
    }
  }

  Future<void> _loadProjectCount() async {
    if (_ownerId == null) return;
    try {
      final result = await _supabase
          .from('project_owners')
          .select('project_id')
          .eq('owner_id', _ownerId!);
      if (mounted) {
        setState(() => _projectCount = (result is List ? result.length : 0));
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_OwnerDashboardState._loadProjectCount');
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
        setState(() => _pendingApprovalCount = (result is List ? result.length : 0)); // UX-audit CI-04: safe cast
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_OwnerDashboardState._loadPendingApprovalCount');
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

      // UX-audit CI-04: safe casting
      final projectIds = (projectOwners is List ? projectOwners : <dynamic>[])
          .map((po) => po['project_id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (projectIds.isEmpty) return;

      final result = await _supabase
          .from('voice_notes')
          .select('id')
          .eq('recipient_id', _ownerId!)
          .inFilter('project_id', projectIds)
          .gte('created_at', sevenDaysAgo);

      if (mounted) {
        setState(() => _unreadMessageCount = (result is List ? result.length : 0)); // UX-audit CI-04: safe cast
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_OwnerDashboardState._loadUnreadMessageCount');
    }
  }

  Future<void> _loadNewReportCount() async {
    if (_ownerId == null || _accountId == null) return;
    try {
      // Count sent reports in the last 7 days for this owner's projects
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      // Get owner's project IDs
      final projectOwners = await _supabase
          .from('project_owners')
          .select('project_id')
          .eq('owner_id', _ownerId!);

      final ownerProjectIds = (projectOwners is List ? projectOwners : <dynamic>[]) // UX-audit CI-04: safe cast
          .map((po) => po['project_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Fetch recent sent reports for this account
      final reports = await _supabase
          .from('reports')
          .select('id, project_ids')
          .eq('account_id', _accountId!)
          .eq('owner_report_status', 'sent')
          .gte('sent_at', sevenDaysAgo);

      int count = 0;
      for (final report in reports) {
        final projectIds = (report['project_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // Empty project_ids means all projects — visible to all owners
        if (projectIds.isEmpty) {
          count++;
        } else if (projectIds.any((pid) => ownerProjectIds.contains(pid))) {
          count++;
        }
      }

      if (mounted) {
        setState(() => _newReportCount = count);
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_OwnerDashboardState._loadNewReportCount');
    }
  }

  /// UX-audit PP-10: Compute net cash position scoped to this owner's projects only.
  Future<void> _loadNetCashPosition() async {
    if (_accountId == null || _ownerId == null) return;
    try {
      // Fetch only this owner's project IDs
      final projectOwners = await _supabase
          .from('project_owners')
          .select('project_id')
          .eq('owner_id', _ownerId!);

      final projectIds = (projectOwners as List? ?? [])
          .map((po) => po['project_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (projectIds.isEmpty) {
        if (mounted) setState(() => _netCashPosition = 0);
        return;
      }

      // Owner payments received — scoped to owner's projects
      final payments = await _supabase
          .from('owner_payments')
          .select('amount')
          .eq('account_id', _accountId!)
          .inFilter('project_id', projectIds);

      final totalReceived = (payments as List? ?? [])
          .fold<double>(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

      // Approved fund requests — scoped to owner's projects
      final requests = await _supabase
          .from('fund_requests')
          .select('amount')
          .eq('account_id', _accountId!)
          .eq('status', 'approved')
          .inFilter('project_id', projectIds);

      final totalApprovedRequests = (requests as List? ?? [])
          .fold<double>(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));

      if (mounted) {
        setState(() => _netCashPosition = totalReceived - totalApprovedRequests);
      }
    } catch (e, st) {
      ErrorLogging.capture(e, stackTrace: st, context: '_OwnerDashboardState._loadNetCashPosition');
    }
  }

  // UX-audit PP-06: contextual time-of-day greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // PP-11: Build the list of tab content widgets
  List<Widget> _buildTabs() {
    return [
      OwnerProjectsTab(ownerId: _ownerId!, accountId: _accountId!),
      OwnerApprovalsTab(
        ownerId: _ownerId!,
        accountId: _accountId!,
        onApprovalChanged: _loadPendingApprovalCount,
      ),
      OwnerMessagesTab(ownerId: _ownerId!, accountId: _accountId!),
      OwnerReportsTab(ownerId: _ownerId!, accountId: _accountId!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_accountId == null || _ownerId == null) {
      return const Scaffold(
        body: ShimmerLoadingList(), // UX-audit #4: shimmer instead of spinner
      );
    }

    final tabs = _buildTabs();

    return Scaffold(
      appBar: AppBar(
        title: Text('${_getGreeting()}, ${_ownerName ?? "Owner"}'), // UX-audit PP-06
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        actions: [
          if (_accountId != null)
            IconButton(
              icon: const Icon(Icons.insights),
              onPressed: () {
                Navigator.of(context).push(
                  FadeSlideRoute(page: InsightsScreen(accountId: _accountId!)),
                );
              },
              tooltip: 'Insights',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                FadeSlideRoute(page: SettingsScreen(
                  role: 'owner',
                  accountId: _accountId,
                )),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      // PP-11: Responsive body — NavigationRail on tablet, BottomNav on phone
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= Breakpoints.tablet;

          if (isTablet) {
            // Tablet: NavigationRail on the left + content area
            return Column(
              children: [
                // KPI bar stretches full width on tablet
                _OwnerKpiBar(
                  projectCount: _projectCount,
                  pendingApprovals: _pendingApprovalCount,
                  unreadMessages: _unreadMessageCount,
                  newReports: _newReportCount,
                  netCashPosition: _netCashPosition,
                  onTapApprovals: () => setState(() => _currentIndex = 1),
                  onTapMessages: () => setState(() => _currentIndex = 2),
                  onTapReports: () => setState(() => _currentIndex = 3),
                ),
                Expanded(
                  child: Row(
                    children: [
                      // NavigationRail for tablet
                      NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) =>
                            setState(() => _currentIndex = index),
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Theme.of(context).cardColor,
                        selectedIconTheme: const IconThemeData(
                          color: AppTheme.primaryIndigo,
                        ),
                        unselectedIconTheme: const IconThemeData(
                          color: AppTheme.textSecondary,
                        ),
                        selectedLabelTextStyle: const TextStyle(
                          color: AppTheme.primaryIndigo,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        destinations: [
                          const NavigationRailDestination(
                            icon: Icon(Icons.business_outlined),
                            selectedIcon: Icon(Icons.business),
                            label: Text('Projects'),
                          ),
                          NavigationRailDestination(
                            icon: Badge(
                              isLabelVisible: _pendingApprovalCount > 0,
                              label: Text('$_pendingApprovalCount'),
                              child: const Icon(Icons.approval_outlined),
                            ),
                            selectedIcon: Badge(
                              isLabelVisible: _pendingApprovalCount > 0,
                              label: Text('$_pendingApprovalCount'),
                              child: const Icon(Icons.approval),
                            ),
                            label: const Text('Approvals'),
                          ),
                          NavigationRailDestination(
                            icon: Badge(
                              isLabelVisible: _unreadMessageCount > 0,
                              label: Text('$_unreadMessageCount'),
                              child: const Icon(Icons.message_outlined),
                            ),
                            selectedIcon: Badge(
                              isLabelVisible: _unreadMessageCount > 0,
                              label: Text('$_unreadMessageCount'),
                              child: const Icon(Icons.message),
                            ),
                            label: const Text('Messages'),
                          ),
                          NavigationRailDestination(
                            icon: Badge(
                              isLabelVisible: _newReportCount > 0,
                              label: Text('$_newReportCount'),
                              child: const Icon(Icons.assessment_outlined),
                            ),
                            selectedIcon: Badge(
                              isLabelVisible: _newReportCount > 0,
                              label: Text('$_newReportCount'),
                              child: const Icon(Icons.assessment),
                            ),
                            label: const Text('Reports'),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      // Main content with max width constraint for desktop
                      Expanded(
                        child: ContentConstraint(
                          maxContentWidth: 1200,
                          child: tabs[_currentIndex],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Phone: standard layout with bottom nav
          return Column(
            children: [
              // UX-audit PP-01: Executive KPI bar above the fold
              _OwnerKpiBar(
                projectCount: _projectCount,
                pendingApprovals: _pendingApprovalCount,
                unreadMessages: _unreadMessageCount,
                newReports: _newReportCount,
                netCashPosition: _netCashPosition,
                onTapApprovals: () => setState(() => _currentIndex = 1),
                onTapMessages: () => setState(() => _currentIndex = 2),
                onTapReports: () => setState(() => _currentIndex = 3),
              ),
              Expanded(child: tabs[_currentIndex]),
            ],
          );
        },
      ),
      // PP-11: Only show BottomNavigationBar on phone-sized screens
      bottomNavigationBar: MediaQuery.of(context).size.width >= Breakpoints.tablet
          ? null
          : BottomNavigationBar(
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
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: _newReportCount > 0,
                    label: Text('$_newReportCount'),
                    child: const Icon(Icons.assessment_outlined),
                  ),
                  label: 'Reports',
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

/// UX-audit PP-01: Executive KPI bar showing portfolio health at a glance.
/// Displays 5 metric cards: Active Projects, Pending Approvals, Net Cash, Messages, Reports.
/// UX-audit PP-10: Added Net Cash Position KPI.
/// Tappable cards navigate directly to the relevant tab.
class _OwnerKpiBar extends StatelessWidget {
  final int projectCount;
  final int pendingApprovals;
  final int unreadMessages;
  final int newReports;
  final double? netCashPosition;
  final VoidCallback? onTapApprovals;
  final VoidCallback? onTapMessages;
  final VoidCallback? onTapReports;

  static final _compactCurrencyFormat =
      NumberFormat.compactCurrency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  const _OwnerKpiBar({
    required this.projectCount,
    required this.pendingApprovals,
    required this.unreadMessages,
    required this.newReports,
    this.netCashPosition,
    this.onTapApprovals,
    this.onTapMessages,
    this.onTapReports,
  });

  @override
  Widget build(BuildContext context) {
    // UX-audit PP-10: format net cash position
    final cashLabel = netCashPosition != null
        ? _compactCurrencyFormat.format(netCashPosition)
        : '--';
    final cashColor = netCashPosition == null
        ? AppTheme.textSecondary
        : netCashPosition! >= 0
            ? AppTheme.successGreen
            : AppTheme.errorRed;

    return LayoutBuilder(
      builder: (context, constraints) {
        // PP-11: More spacious KPI bar on tablet
        final isTablet = constraints.maxWidth >= Breakpoints.tablet;
        final horizontalPadding = isTablet ? AppTheme.spacingL : AppTheme.spacingM;
        final cardSpacing = isTablet ? AppTheme.spacingM : AppTheme.spacingS;

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding, AppTheme.spacingS, horizontalPadding, AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: AppTheme.borderLight, // UX-audit #20
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _KpiCard(
                icon: Icons.business,
                label: 'Sites',
                value: '$projectCount',
                color: AppTheme.primaryIndigo,
                isTablet: isTablet,
              ),
              SizedBox(width: cardSpacing),
              _KpiCard(
                icon: Icons.approval,
                label: 'Pending',
                value: '$pendingApprovals',
                color: pendingApprovals > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
                highlight: pendingApprovals > 0,
                onTap: onTapApprovals,
                isTablet: isTablet,
              ),
              SizedBox(width: cardSpacing),
              // UX-audit PP-10: Net Cash Position
              _KpiCard(
                icon: Icons.account_balance_wallet,
                label: 'Net Cash',
                value: cashLabel,
                color: cashColor,
                compact: true,
                isTablet: isTablet,
              ),
              SizedBox(width: cardSpacing),
              _KpiCard(
                icon: Icons.message,
                label: 'Messages',
                value: '$unreadMessages',
                color: unreadMessages > 0 ? AppTheme.infoBlue : AppTheme.textSecondary,
                onTap: onTapMessages,
                isTablet: isTablet,
              ),
              SizedBox(width: cardSpacing),
              _KpiCard(
                icon: Icons.assessment_outlined,
                label: 'Reports',
                value: '$newReports',
                color: newReports > 0 ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                onTap: onTapReports,
                isTablet: isTablet,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool highlight;
  final bool compact; // UX-audit PP-10: smaller font for currency values
  final bool isTablet; // PP-11: tablet sizing
  final VoidCallback? onTap;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
    this.compact = false,
    this.isTablet = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // PP-11: Scale up sizes on tablet for better readability at distance
    final iconSize = isTablet ? 24.0 : 20.0;
    final valueFontSize = compact
        ? (isTablet ? 16.0 : 14.0)
        : (isTablet ? 22.0 : 18.0);
    final labelFontSize = isTablet ? 12.0 : 11.0;
    final verticalPad = isTablet ? 14.0 : 10.0;
    final horizontalPad = isTablet ? 10.0 : 6.0;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPad, horizontal: horizontalPad),
          decoration: BoxDecoration(
            color: highlight
                ? color.withValues(alpha: 0.08)
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: highlight
                ? Border.all(color: color.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
