import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:houzzdat_app/features/auth/screens/auth_wrapper.dart';
import 'package:houzzdat_app/features/dashboard/screens/manager_dashboard.dart';
import 'package:houzzdat_app/features/worker/screens/construction_home_screen.dart';
import 'package:houzzdat_app/features/owner/screens/owner_dashboard.dart';
import 'package:houzzdat_app/features/settings/screens/settings_screen.dart';
import 'package:houzzdat_app/features/reports/screens/reports_screen.dart';
import 'package:houzzdat_app/features/reports/screens/report_detail_screen.dart';
import 'package:houzzdat_app/features/reports/screens/prompts_management_screen.dart';
import 'package:houzzdat_app/features/reports/screens/generate_report_screen.dart';
import 'package:houzzdat_app/features/insights/screens/insights_screen.dart';
import 'package:houzzdat_app/features/insights/screens/plan_setup_screen.dart';
// Future deep-link routes (add imports when wiring):
// import 'package:houzzdat_app/features/dashboard/screens/manager_site_detail_screen.dart';
// import 'package:houzzdat_app/features/owner/screens/owner_project_detail.dart';
// import 'package:houzzdat_app/features/owner/screens/owner_report_view_screen.dart';

/// UX-audit #1: Centralized route configuration using go_router.
///
/// Named routes for type-safe navigation. Replaces ad-hoc Navigator.push calls.
///
/// Usage:
/// ```dart
/// context.goNamed(AppRoutes.settings, queryParameters: {'role': 'manager'});
/// context.pushNamed(AppRoutes.reportDetail, pathParameters: {'id': reportId});
/// ```

/// Route name constants for type-safe navigation.
class AppRoutes {
  AppRoutes._();

  static const auth = 'auth';
  static const managerDashboard = 'manager-dashboard';
  static const workerDashboard = 'worker-dashboard';
  static const ownerDashboard = 'owner-dashboard';
  static const settings = 'settings';
  static const reports = 'reports';
  static const reportDetail = 'report-detail';
  static const generateReport = 'generate-report';
  static const promptsManagement = 'prompts-management';
  static const insights = 'insights';
  static const planSetup = 'plan-setup';
  static const siteDetail = 'site-detail';
  static const ownerProjectDetail = 'owner-project-detail';
  static const ownerReportView = 'owner-report-view';
}

/// Creates the GoRouter instance.
///
/// Currently configured to work alongside the existing AuthWrapper.
/// The AuthWrapper handles auth state → dashboard routing internally.
/// Named routes are used for secondary navigation (settings, detail screens).
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      // Root: AuthWrapper handles auth flow
      GoRoute(
        path: '/',
        name: AppRoutes.auth,
        builder: (context, state) => const AuthWrapper(),
      ),

      // ── Manager routes ────────────────────────────────────────
      GoRoute(
        path: '/manager',
        name: AppRoutes.managerDashboard,
        builder: (context, state) => const ManagerDashboard(),
      ),

      // ── Worker routes ─────────────────────────────────────────
      GoRoute(
        path: '/worker',
        name: AppRoutes.workerDashboard,
        builder: (context, state) => const ConstructionHomeScreen(),
      ),

      // ── Owner routes ──────────────────────────────────────────
      GoRoute(
        path: '/owner',
        name: AppRoutes.ownerDashboard,
        builder: (context, state) => const OwnerDashboard(),
      ),

      // ── Settings ──────────────────────────────────────────────
      GoRoute(
        path: '/settings',
        name: AppRoutes.settings,
        pageBuilder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'worker';
          final accountId = state.uri.queryParameters['accountId'];
          return _fadeSlide(
            state,
            SettingsScreen(role: role, accountId: accountId),
          );
        },
      ),

      // ── Reports ───────────────────────────────────────────────
      GoRoute(
        path: '/reports/:accountId',
        name: AppRoutes.reports,
        pageBuilder: (context, state) {
          final accountId = state.pathParameters['accountId']!;
          return _fadeSlide(state, ReportsScreen(accountId: accountId));
        },
      ),
      GoRoute(
        path: '/reports/:accountId/detail/:id',
        name: AppRoutes.reportDetail,
        pageBuilder: (context, state) {
          final accountId = state.pathParameters['accountId']!;
          final reportId = state.pathParameters['id']!;
          return _fadeSlide(
            state,
            ReportDetailScreen(reportId: reportId, accountId: accountId),
          );
        },
      ),
      GoRoute(
        path: '/reports/:accountId/generate',
        name: AppRoutes.generateReport,
        pageBuilder: (context, state) {
          final accountId = state.pathParameters['accountId']!;
          return _fadeSlide(
            state,
            GenerateReportScreen(accountId: accountId),
          );
        },
      ),
      GoRoute(
        path: '/reports/:accountId/prompts',
        name: AppRoutes.promptsManagement,
        pageBuilder: (context, state) {
          final accountId = state.pathParameters['accountId']!;
          return _fadeSlide(
            state,
            PromptsManagementScreen(accountId: accountId),
          );
        },
      ),

      // ── Insights ──────────────────────────────────────────────
      GoRoute(
        path: '/insights/:accountId',
        name: AppRoutes.insights,
        pageBuilder: (context, state) {
          final accountId = state.pathParameters['accountId']!;
          return _fadeSlide(state, InsightsScreen(accountId: accountId));
        },
      ),
      GoRoute(
        path: '/insights/:accountId/plan-setup/:projectId',
        name: AppRoutes.planSetup,
        pageBuilder: (context, state) {
          final accountId = state.pathParameters['accountId']!;
          final projectId = state.pathParameters['projectId']!;
          final projectName =
              state.uri.queryParameters['projectName'] ?? 'Project';
          return _fadeSlide(
            state,
            PlanSetupScreen(
              accountId: accountId,
              projectId: projectId,
              projectName: projectName,
            ),
          );
        },
      ),
    ],
  );
}

/// Consistent fade+slide page transition matching FadeSlideRoute.
CustomTransitionPage<T> _fadeSlide<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
