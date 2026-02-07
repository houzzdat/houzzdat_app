import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing in-app notifications.
/// Handles creating, reading, and listening for notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _supabase = Supabase.instance.client;

  /// Stream controller for unread notification count
  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  RealtimeChannel? _channel;
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// Initialize real-time listener for the current user's notifications
  void initialize(String userId) {
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _unreadCount++;
            _unreadCountController.add(_unreadCount);
          },
        )
        .subscribe();

    // Load initial count
    _loadUnreadCount(userId);
  }

  /// Load the current unread notification count
  Future<void> _loadUnreadCount(String userId) async {
    try {
      final result = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      _unreadCount = (result as List).length;
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  /// Fetch notifications for the current user
  Future<List<Map<String, dynamic>>> getNotifications({
    required String userId,
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final data = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      _unreadCount = (_unreadCount - 1).clamp(0, double.maxFinite.toInt());
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);

      _unreadCount = 0;
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Create a notification (used by action handlers)
  static Future<void> create({
    required String userId,
    required String accountId,
    required String type,
    required String title,
    String? projectId,
    String? body,
    String? referenceId,
    String? referenceType,
  }) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'account_id': accountId,
        'project_id': projectId,
        'type': type,
        'title': title,
        'body': body,
        'reference_id': referenceId,
        'reference_type': referenceType,
      });
    } catch (e) {
      debugPrint('Warning: Could not create notification: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _channel?.unsubscribe();
    _unreadCountController.close();
  }
}
