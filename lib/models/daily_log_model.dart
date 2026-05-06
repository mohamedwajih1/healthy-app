import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLogModel {
  final String id;
  final String userId;
  final DateTime date;
  final List<String> completedHabitIds;
  final String? mood; // 😊 😐 😢 etc
  final String? notes;
  final int totalHabits;

  DailyLogModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.completedHabitIds,
    this.mood,
    this.notes,
    required this.totalHabits,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'completedHabitIds': completedHabitIds,
      'mood': mood,
      'notes': notes,
      'totalHabits': totalHabits,
    };
  }

  factory DailyLogModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    Map<String, dynamic> data =
        doc.data() as Map<String, dynamic>;
    return DailyLogModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      completedHabitIds: List<String>.from(
        data['completedHabitIds'] ?? [],
      ),
      mood: data['mood'],
      notes: data['notes'],
      totalHabits: data['totalHabits'] ?? 0,
    );
  }

  DailyLogModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    List<String>? completedHabitIds,
    String? mood,
    String? notes,
    int? totalHabits,
  }) {
    return DailyLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      completedHabitIds:
          completedHabitIds ??
          this.completedHabitIds,
      mood: mood ?? this.mood,
      notes: notes ?? this.notes,
      totalHabits:
          totalHabits ?? this.totalHabits,
    );
  }

  // Helper: Check if habit is completed today
  bool isHabitCompleted(String habitId) {
    return completedHabitIds.contains(habitId);
  }
}
