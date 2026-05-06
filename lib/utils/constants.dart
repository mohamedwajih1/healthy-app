import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'حياة صحية';
  static const String appVersion = '1.0.0';

  // Colors
  static const Color primaryColor = Color(
    0xFF6C63FF,
  );
  static const Color secondaryColor = Color(
    0xFF4CAF50,
  );
  static const Color accentColor = Color(
    0xFFFF6B9D,
  );
  static const Color backgroundColor = Color(
    0xFFF5F7FA,
  );
  static const Color cardColor = Colors.white;
  static const Color errorColor = Color(
    0xFFE53935,
  );
  static const Color successColor = Color(
    0xFF43A047,
  );
  static const Color warningColor = Color(
    0xFFFB8C00,
  );

  // Gradient Colors
  static const LinearGradient primaryGradient =
      LinearGradient(
        colors: [
          Color(0xFF6C63FF),
          Color(0xFF4E47D9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const LinearGradient successGradient =
      LinearGradient(
        colors: [
          Color(0xFF4CAF50),
          Color(0xFF388E3C),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Text Sizes
  static const double textSizeSmall = 12.0;
  static const double textSizeMedium = 14.0;
  static const double textSizeLarge = 16.0;
  static const double textSizeXLarge = 20.0;
  static const double textSizeXXLarge = 24.0;

  // Animation Durations
  static const Duration animationFast = Duration(
    milliseconds: 150,
  );
  static const Duration animationMedium =
      Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(
    milliseconds: 500,
  );

  // Categories with icons and colors
  static const Map<String, Map<String, dynamic>>
  categoryInfo = {
    'exercise': {
      'name': 'رياضة',
      'icon': '🏃',
      'color': Color(0xFF2196F3),
    },
    'nutrition': {
      'name': 'تغذية',
      'icon': '🥗',
      'color': Color(0xFF4CAF50),
    },
    'sleep': {
      'name': 'نوم',
      'icon': '😴',
      'color': Color(0xFF9C27B0),
    },
    'reading': {
      'name': 'قراءة',
      'icon': '📚',
      'color': Color(0xFFFF9800),
    },
    'thinking': {
      'name': 'تفكر',
      'icon': '�',
      'color': Color(0xFF00BCD4),
    },
    'water': {
      'name': 'ماء',
      'icon': '💧',
      'color': Color(0xFF03A9F4),
    },
    'other': {
      'name': 'أخرى',
      'icon': '✨',
      'color': Color(0xFF607D8B),
    },
  };

  // Validation
  static const int minPasswordLength = 6;
  static const int maxHabitNameLength = 50;
  static const int maxDescriptionLength = 200;

  // Streak milestones
  static const List<int> streakMilestones = [
    7,
    14,
    30,
    60,
    100,
    365,
  ];

  // Messages
  static const String successMessage =
      'تم بنجاح! ✅';
  static const String errorMessage =
      'حدث خطأ، حاول مرة أخرى';
  static const String emptyHabitsMessage =
      'لا توجد عادات بعد\nابدأ بإضافة عادة جديدة!';
  static const String loadingMessage =
      'جاري التحميل...';

  // Achievements titles
  static const Map<int, String>
  achievementTitles = {
    7: '🔥 أسبوع من الالتزام!',
    14: '⭐ أسبوعين متواصلين!',
    30: '🏆 شهر كامل!',
    60: '💎 شهرين رائعين!',
    100: '👑 100 يوم متتالي!',
    365: '🌟 سنة كاملة - أسطورة!',
  };
}

// Extensions
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

extension DateTimeExtension on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year &&
        month == other.month &&
        day == other.day;
  }

  bool isToday() {
    return isSameDay(DateTime.now());
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(
      const Duration(days: 1),
    );
    return isSameDay(yesterday);
  }
}
