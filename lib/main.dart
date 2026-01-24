import 'package:flutter/material.dart';
// FIX 1: Import the new service file so 'SupabaseService' is found
import 'package:houzzdat_app/core/services/supabase_service.dart';
// FIX 2: Import the AuthWrapper file
import 'package:houzzdat_app/features/auth/screens/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIX 1 Explanation: This line failed before because main.dart 
  // didn't know where to look for 'SupabaseService'. The import above fixes it.
  await SupabaseService.initialize();

  // FIX 3 Explanation: We remove 'const' here. 
  // Since AuthWrapper may rely on runtime data (like User sessions), 
  // it cannot be a compile-time constant.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOUZZDAT',
      theme: ThemeData(primarySwatch: Colors.indigo),
      // FIX 3: Remove 'const' here too
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}