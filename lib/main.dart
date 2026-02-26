import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houzzdat_app/core/services/supabase_service.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:houzzdat_app/core/routing/app_router.dart';
import 'package:houzzdat_app/providers/providers.dart';

// UX-audit CI-02: Global error boundary — prevents red error screen on field devices
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformError: $error\n$stack');
    return true;
  };

  await runZonedGuarded(() async {
    await SupabaseService.initialize();
    // CI-06: Wrap app with Riverpod ProviderScope
    runApp(const ProviderScope(child: MyApp()));
  }, (Object error, StackTrace stackTrace) {
    debugPrint('Unhandled zone error: $error\n$stackTrace');
  });
}

// UX-audit #1: Top-level router instance (created once, survives rebuilds)
final GoRouter _appRouter = createAppRouter();

/// CI-06: MyApp now uses Riverpod ConsumerWidget for theme management.
/// Legacy static methods preserved for backward compatibility during migration.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  /// Legacy: allows descendant widgets to toggle theme mode.
  /// Prefer using `ref.read(themeProvider.notifier).setThemeMode(mode)`.
  static void setThemeMode(BuildContext context, ThemeMode mode) {
    // Try Riverpod first via ProviderScope
    try {
      final container = ProviderScope.containerOf(context);
      container.read(themeProvider.notifier).setThemeMode(mode);
    } catch (_) {
      // Fallback: shouldn't happen since ProviderScope is always present
      debugPrint('Warning: Could not set theme mode via Riverpod');
    }
  }

  /// Legacy: get current theme mode.
  /// Prefer using `ref.watch(themeProvider)`.
  static ThemeMode getThemeMode(BuildContext context) {
    try {
      final container = ProviderScope.containerOf(context);
      return container.read(themeProvider);
    } catch (_) {
      return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    // UX-audit #1: go_router for named routes, deep linking, and analytics
    return MaterialApp.router(
      title: 'HOUZZDAT',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
