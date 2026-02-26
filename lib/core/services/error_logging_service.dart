import 'package:flutter/foundation.dart';

/// UX-audit #9: Centralized structured error logging service.
///
/// Provides a single interface for error reporting that can be swapped
/// to Sentry, Crashlytics, or any other provider without changing call sites.
///
/// Usage:
/// ```dart
/// try {
///   await someOperation();
/// } catch (e, st) {
///   ErrorLogging.capture(e, stackTrace: st, context: 'loadProjects');
/// }
/// ```
class ErrorLogging {
  ErrorLogging._();

  static ErrorLoggingProvider _provider = _DebugPrintProvider();

  /// Initialize with a specific provider (call once in main.dart).
  /// Defaults to debug-print logging in development.
  static void init({ErrorLoggingProvider? provider}) {
    if (provider != null) {
      _provider = provider;
    }
  }

  /// Capture an exception with optional stack trace and context.
  static void capture(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extras,
  }) {
    _provider.captureException(
      exception,
      stackTrace: stackTrace,
      context: context,
      extras: extras,
    );
  }

  /// Log a non-fatal message for diagnostics.
  static void log(String message, {String? context}) {
    _provider.logMessage(message, context: context);
  }

  /// Set user context for error reports.
  static void setUser({String? id, String? email, String? role}) {
    _provider.setUser(id: id, email: email, role: role);
  }

  /// Add a breadcrumb for navigation/action tracking.
  static void addBreadcrumb(String message, {String? category}) {
    _provider.addBreadcrumb(message, category: category);
  }
}

/// Abstract provider interface — implement for Sentry, Crashlytics, etc.
abstract class ErrorLoggingProvider {
  void captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extras,
  });

  void logMessage(String message, {String? context});

  void setUser({String? id, String? email, String? role});

  void addBreadcrumb(String message, {String? category});
}

/// Default provider: structured debugPrint output for development.
class _DebugPrintProvider implements ErrorLoggingProvider {
  @override
  void captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extras,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('[ErrorLogging] Exception captured');
    if (context != null) buffer.writeln('  Context: $context');
    buffer.writeln('  Error: $exception');
    if (extras != null && extras.isNotEmpty) {
      buffer.writeln('  Extras: $extras');
    }
    if (stackTrace != null) {
      buffer.writeln('  StackTrace: ${stackTrace.toString().split('\n').take(5).join('\n  ')}');
    }
    debugPrint(buffer.toString());
  }

  @override
  void logMessage(String message, {String? context}) {
    debugPrint('[ErrorLogging] ${context != null ? '[$context] ' : ''}$message');
  }

  @override
  void setUser({String? id, String? email, String? role}) {
    debugPrint('[ErrorLogging] User set: id=$id, email=$email, role=$role');
  }

  @override
  void addBreadcrumb(String message, {String? category}) {
    debugPrint('[ErrorLogging] Breadcrumb: ${category != null ? '[$category] ' : ''}$message');
  }
}
