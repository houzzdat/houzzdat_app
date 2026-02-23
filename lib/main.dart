import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:houzzdat_app/core/services/supabase_service.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/auth/screens/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  /// Allows descendant widgets to toggle theme mode.
  static void setThemeMode(BuildContext context, ThemeMode mode) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?._setThemeMode(mode);
  }

  /// Get current theme mode.
  static ThemeMode getThemeMode(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode') ?? 'system';
    setState(() {
      _themeMode = switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  void _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOUZZDAT',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
