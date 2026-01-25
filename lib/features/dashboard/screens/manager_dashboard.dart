import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/services/dashboard_settings_service.dart';
import 'package:houzzdat_app/features/dashboard/screens/manager_dashboard_classic.dart';
import 'package:houzzdat_app/features/dashboard/screens/manager_dashboard_kanban.dart';

/// Adaptive Manager Dashboard that switches between Classic and Kanban layouts
/// Based on user preference stored in DashboardSettingsService
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});
  
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final _settingsService = DashboardSettingsService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await _settingsService.initialize();
    if (mounted) {
      setState(() => _isInitializing = false);
    }
    
    // Listen to layout changes
    _settingsService.addListener(_onLayoutChanged);
  }

  void _onLayoutChanged() {
    if (mounted) {
      setState(() {}); // Rebuild when layout changes
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onLayoutChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Switch between layouts based on setting
    return _settingsService.isKanbanMode
        ? const ManagerDashboardKanban()
        : const ManagerDashboardClassic();
  }
}