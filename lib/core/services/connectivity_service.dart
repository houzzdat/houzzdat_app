import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight connectivity service that checks internet by pinging Supabase.
/// Does not require the `connectivity_plus` package.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  Timer? _pollTimer;

  bool get isOnline => _isOnline;

  /// Start periodic connectivity checks (every 15 seconds).
  void startMonitoring() {
    _checkConnectivity();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkConnectivity();
    });
  }

  /// Stop monitoring.
  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Manual check — returns true if online.
  Future<bool> checkNow() async {
    await _checkConnectivity();
    return _isOnline;
  }

  Future<void> _checkConnectivity() async {
    try {
      // Quick lightweight query to Supabase to check connectivity
      await Supabase.instance.client
          .from('accounts')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      _setOnline(true);
    } catch (e) {
      _setOnline(false);
    }
  }

  void _setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
