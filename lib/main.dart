import 'app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'providers/habit_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

// Application entry point
void main() async {
  // Required for async operations before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions.currentPlatform,
  );

  // Load Arabic locale data for date formatting
  await initializeDateFormatting('ar', null);

  // Launch app with state management providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => HabitProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
