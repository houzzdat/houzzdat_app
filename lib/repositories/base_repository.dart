import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/models/db_tables.dart';

/// CI-09: Base repository providing shared Supabase access and utilities.
///
/// All domain repositories extend this class. Centralises the Supabase
/// client instance and common query patterns (timeout, error logging).
abstract class BaseRepository {
  @protected
  SupabaseClient get supabase => Supabase.instance.client;

  /// Default query timeout.
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Execute a query with timeout and error logging.
  @protected
  Future<T> safeQuery<T>(
    Future<T> Function() queryFn, {
    String? label,
    Duration timeout = defaultTimeout,
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
    } catch (e) {
      debugPrint('Repository error${label != null ? ' ($label)' : ''}: $e');
      rethrow;
    }
  }

  /// Execute a query returning null on timeout instead of throwing.
  @protected
  Future<T?> safeQueryOrNull<T>(
    Future<T> Function() queryFn, {
    String? label,
    Duration timeout = defaultTimeout,
  }) async {
    try {
      return await safeQuery(queryFn, label: label, timeout: timeout);
    } catch (e) {
      debugPrint('SafeQueryOrNull failed${label != null ? ' ($label)' : ''}: $e');
      return null;
    }
  }

  /// Get the current authenticated user's ID, or null.
  @protected
  String? get currentUserId => supabase.auth.currentUser?.id;
}

/// Unused but reserved — placeholder reference for [DbTables] usage.
/// This ensures the import is not flagged as unused while repositories
/// gradually adopt constants.
// ignore: unused_element
const _dbTablesRef = DbTables;
