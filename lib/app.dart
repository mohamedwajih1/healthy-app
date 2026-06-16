import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'package:healty_app/utils/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:healty_app/widgets/follow_listener.dart';
import 'package:healty_app/services/fcm_service.dart';
import 'services/ai_insights_service.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/notifications/notifications_screen.dart';

// Root application widget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// Manages app lifecycle and online status tracking
class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register this class as an observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Mark user as online when app starts (if logged in)
    final user =
        FirebaseAuth.instance.currentUser;
    if (user != null) {
      _updateOnlineStatus(user.uid, true);
    }
  }

  // Called when app state changes (foreground, background, etc.)
  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final user =
        FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Update online status based on app state
    final isOnline =
        state == AppLifecycleState.resumed;
    _updateOnlineStatus(user.uid, isOnline);
  }

  // Helper to update user online status in Firestore
  // Only updates existing users - never creates new ones
  void _updateOnlineStatus(
    String userId,
    bool isOnline,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      // Check if user exists first
      final doc = await docRef.get();
      if (!doc.exists) {
        // Don't create ghost users
        print(
          'User $userId not found - skipping online status update',
        );
        return;
      }

      // Only update existing users
      await docRef.update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  @override
  void dispose() {
    // Clean up observer when app closes
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حياة صحية',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: themeData(),

      routes: {
        '/home': (_) => const HomeScreen(),
        '/chat': (_) => const ChatListScreen(),
        '/stats': (_) => const StatsScreen(),
        '/ai_insights': (_) =>
            const AIInsightsScreen(),
        '/notifications': (_) =>
            const NotificationsScreen(),
      },

      // Handle auth state changes and route accordingly
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance
            .authStateChanges(),
        builder: (context, snapshot) {
          // Show loading while checking auth state
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child:
                    CircularProgressIndicator(),
              ),
            );
          }

          // User not logged in - show login screen
          if (!snapshot.hasData) {
            return const LoginScreen();
          }

          // User logged in - show main app with follow request listener
          return FollowRequestListener(
            child: const HomeScreen(),
          );
        },
      ),
    );
  }
}
