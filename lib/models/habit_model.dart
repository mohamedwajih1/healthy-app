// Data model representing a user habit
// Handles serialization to/from Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

// Categories for organizing habits
enum HabitCategory {
  exercise,
  nutrition,
  sleep,
  reading,
  thinking,
  water,
  other,
  health,
  productivity,
  mindfulness,
}

enum HabitFrequency { daily, weekly, custom }

class HabitModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final HabitCategory category;
  final HabitFrequency frequency;
  final int targetCount;
  final DateTime createdAt;
  final DateTime? lastCompleted;
  final int currentStreak;
  final int bestStreak;
  final bool isActive;
  final String? reminderTime;
  final List<String>? reminderDays;
  // List of reminder configurations for this habit
  final List<Map<String, dynamic>>? reminders;
  final int targetDays;

  // Constructor with all habit properties
  HabitModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.category,
    required this.frequency,
    this.targetCount = 1,
    required this.createdAt,
    this.lastCompleted,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.isActive = true,
    this.reminderTime,
    this.reminderDays,
    this.reminders,
    required this.targetDays,
  });
  factory HabitModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return HabitModel(
      id: id,
      userId: '',
      name: map['name'] ?? '',
      category: HabitCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => HabitCategory.other,
      ),
      frequency: HabitFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => HabitFrequency.daily,
      ),
      createdAt: (map['createdAt'] as Timestamp)
          .toDate(),
      currentStreak: map['currentStreak'] ?? 0,
      bestStreak: map['bestStreak'] ?? 0,
      isActive: map['isActive'] ?? true,

      // 🔥 مهم جدًا
      targetDays: map['targetDays'] ?? 7,
    );
  }

  factory HabitModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    Map<String, dynamic> data =
        doc.data() as Map<String, dynamic>;
    return HabitModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],

      category: HabitCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => HabitCategory.other,
      ),

      frequency: HabitFrequency.values.firstWhere(
        (e) => e.name == data['frequency'],
        orElse: () => HabitFrequency.daily,
      ),

      targetCount: data['targetCount'] ?? 1,

      // 🔥 هنا المكان الصح
      targetDays: data['targetDays'] ?? 7,

      createdAt: (data['createdAt'] as Timestamp)
          .toDate(),

      lastCompleted: data['lastCompleted'] != null
          ? (data['lastCompleted'] as Timestamp)
                .toDate()
          : null,

      currentStreak: data['currentStreak'] ?? 0,
      bestStreak: data['bestStreak'] ?? 0,
      isActive: data['isActive'] ?? true,

      reminderTime: data['reminderTime'],

      reminderDays: data['reminderDays'] != null
          ? List<String>.from(
              data['reminderDays'],
            )
          : null,

      reminders: data['reminders'] != null
          ? List<Map<String, dynamic>>.from(
              (data['reminders'] as List).map(
                (r) => Map<String, dynamic>.from(
                  r as Map,
                ),
              ),
            )
          : null,
    );
  }

  HabitModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    HabitCategory? category,
    HabitFrequency? frequency,
    int? targetCount,
    DateTime? createdAt,
    DateTime? lastCompleted,
    int? currentStreak,
    int? bestStreak,
    bool? isActive,
    String? reminderTime,
    List<String>? reminderDays,
    int? targetDays,
    List<Map<String, dynamic>>?
    reminders, // ✅ إضافة
  }) {
    return HabitModel(
      targetDays: targetDays ?? this.targetDays,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description:
          description ?? this.description,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      targetCount:
          targetCount ?? this.targetCount,
      createdAt: createdAt ?? this.createdAt,
      lastCompleted:
          lastCompleted ?? this.lastCompleted,
      currentStreak:
          currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      isActive: isActive ?? this.isActive,
      reminderTime:
          reminderTime ?? this.reminderTime,
      reminderDays:
          reminderDays ?? this.reminderDays,
      reminders:
          reminders ?? this.reminders, // ✅ إضافة
    );
  }

  // Helper methods
  String getCategoryIcon() {
    switch (category) {
      case HabitCategory.exercise:
        return '🏃';
      case HabitCategory.nutrition:
        return '🥗';
      case HabitCategory.sleep:
        return '😴';
      case HabitCategory.reading:
        return '📚';
      case HabitCategory.thinking:
        return '�';
      case HabitCategory.water:
        return '💧';
      case HabitCategory.health:
        return '💪';
      case HabitCategory.productivity:
        return '⚡';
      case HabitCategory.mindfulness:
        return '🌟';
      default:
        return '✨';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'category': category.name,
      'frequency': frequency.name,
      'targetCount': targetCount,
      'targetDays': targetDays, // 🔥 مهم جدًا
      'createdAt': Timestamp.fromDate(createdAt),
      'lastCompleted': lastCompleted != null
          ? Timestamp.fromDate(lastCompleted!)
          : null,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'isActive': isActive,
      'reminderTime': reminderTime,
      'reminderDays': reminderDays,
      'reminders': reminders,
    };
  }

  String getCategoryName() {
    switch (category) {
      case HabitCategory.exercise:
        return 'رياضة';
      case HabitCategory.nutrition:
        return 'تغذية';
      case HabitCategory.sleep:
        return 'نوم';
      case HabitCategory.reading:
        return 'قراءة';
      case HabitCategory.thinking:
        return 'تفكر';
      case HabitCategory.water:
        return 'ماء';
      case HabitCategory.health:
        return 'صحة';
      case HabitCategory.productivity:
        return 'إنتاجية';
      case HabitCategory.mindfulness:
        return 'يقظة ذهنية';
      default:
        return 'أخرى';
    }
  }
}
