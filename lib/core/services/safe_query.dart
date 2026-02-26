import 'dart:async';
import 'package:flutter/foundation.dart';

/// UX-audit CI-08: Query timeout wrapper for Supabase calls.
///
/// Wraps any async Supabase query with a configurable timeout (default 15s).
/// On timeout, throws a [TimeoutException] with a descriptive message
/// instead of hanging the spinner indefinitely.
///
/// Usage:
/// ```dart
/// final data = await SafeQuery.run(
///   () => _supabase.from('projects').select().eq('id', projectId).maybeSingle(),
///   label: 'load project',
/// );
/// ```
class SafeQuery {
  /// Default timeout duration for all Supabase queries.
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Executes [queryFn] with a timeout.
  ///
  /// - [queryFn]: The async Supabase query to execute.
  /// - [timeout]: Override the default 15s timeout.
  /// - [label]: Optional label for debug logging on timeout.
  ///
  /// Throws [TimeoutException] if the query doesn't complete in time.
  static Future<T> run<T>(
    Future<T> Function() queryFn, {
    Duration timeout = defaultTimeout,
    String? label,
  }) async {
    try {
      return await queryFn().timeout(
        timeout,
        onTimeout: () {
          final msg = label != null
              ? 'Query timed out after ${timeout.inSeconds}s: $label'
              : 'Query timed out after ${timeout.inSeconds}s';
          debugPrint(msg);
          throw TimeoutException(msg, timeout);
        },
      );
    } on TimeoutException {
      rethrow;
    }
  }

  /// Executes [queryFn] with a timeout, returning `null` on timeout
  /// instead of throwing. Useful for non-critical queries.
  ///
  /// - [queryFn]: The async Supabase query to execute.
  /// - [timeout]: Override the default 15s timeout.
  /// - [label]: Optional label for debug logging on timeout.
  static Future<T?> runOrNull<T>(
    Future<T> Function() queryFn, {
    Duration timeout = defaultTimeout,
    String? label,
  }) async {
    try {
      return await run(queryFn, timeout: timeout, label: label);
    } on TimeoutException {
      return null;
    } catch (e) {
      debugPrint('SafeQuery error${label != null ? ' ($label)' : ''}: $e');
      return null;
    }
  }
}
