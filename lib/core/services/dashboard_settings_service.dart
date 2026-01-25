import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service to manage dashboard UI preferences
/// Allows toggling between Classic and Kanban layouts
class DashboardSettingsService extends ChangeNotifier {
  static final DashboardSettingsService _instance = DashboardSettingsService._internal();
  factory DashboardSettingsService() => _instance;
  DashboardSettingsService._internal();

  static const String _keyDashboardLayout = 'dashboard_layout';
  
  DashboardLayout _currentLayout = DashboardLayout.classic;
  bool _isInitialized = false;

  DashboardLayout get currentLayout => _currentLayout;
  bool get isKanbanMode => _currentLayout == DashboardLayout.kanban;
  bool get isClassicMode => _currentLayout == DashboardLayout.classic;

  /// Initialize settings from persistent storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLayout = prefs.getString(_keyDashboardLayout);
      
      if (savedLayout != null) {
        _currentLayout = DashboardLayout.values.firstWhere(
          (e) => e.toString() == savedLayout,
          orElse: () => DashboardLayout.classic,
        );
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing dashboard settings: $e');
    }
  }

  /// Toggle between Classic and Kanban layouts
  Future<void> toggleLayout() async {
    _currentLayout = _currentLayout == DashboardLayout.classic
        ? DashboardLayout.kanban
        : DashboardLayout.classic;
    
    await _saveLayout();
    notifyListeners();
  }

  /// Set specific layout
  Future<void> setLayout(DashboardLayout layout) async {
    if (_currentLayout == layout) return;
    
    _currentLayout = layout;
    await _saveLayout();
    notifyListeners();
  }

  /// Save layout preference to persistent storage
  Future<void> _saveLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDashboardLayout, _currentLayout.toString());
    } catch (e) {
      debugPrint('Error saving dashboard layout: $e');
    }
  }

  /// Reset to default (Classic)
  Future<void> reset() async {
    _currentLayout = DashboardLayout.classic;
    await _saveLayout();
    notifyListeners();
  }
}

/// Available dashboard layout modes
enum DashboardLayout {
  classic,  // Original tab-based design
  kanban,   // New Kanban workflow design
}

extension DashboardLayoutExtension on DashboardLayout {
  String get displayName {
    switch (this) {
      case DashboardLayout.classic:
        return 'Classic View';
      case DashboardLayout.kanban:
        return 'Kanban View';
    }
  }

  String get description {
    switch (this) {
      case DashboardLayout.classic:
        return 'Traditional tab-based layout with Actions, Sites, Team, and Feed';
      case DashboardLayout.kanban:
        return 'Workflow-focused layout with Queue, Active, and Logs stages';
    }
  }

  IconData get icon {
    switch (this) {
      case DashboardLayout.classic:
        return Icons.view_list_rounded;
      case DashboardLayout.kanban:
        return Icons.view_kanban_rounded;
    }
  }
}