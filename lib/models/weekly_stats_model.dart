import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyStatsModel {
  final String id;
  final String userId;
  final int weekNumber;
  final int year;
  final DateTime weekStart;
  final DateTime weekEnd;
  final double overallCompletionRate;
  final Map<String, int> categoryCompletion; // category -> count
  final List<String> topHabits; // أكثر العادات التزاماً
  final List<String> needsImprovement; // عادات تحتاج تحسين
  final List<String> insights; // ملاحظات وتحليلات
  final List<String> suggestions; // اقتراحات للأسبوع القادم
  final Map<String, double> dailyCompletionRates; // يوم -> نسبة

  WeeklyStatsModel({
    required this.id,
    required this.userId,
    required this.weekNumber,
    required this.year,
    required this.weekStart,
    required this.weekEnd,
    required this.overallCompletionRate,
    required this.categoryCompletion,
    required this.topHabits,
    required this.needsImprovement,
    required this.insights,
    required this.suggestions,
    required this.dailyCompletionRates,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'weekNumber': weekNumber,
      'year': year,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'overallCompletionRate': overallCompletionRate,
      'categoryCompletion': categoryCompletion,
      'topHabits': topHabits,
      'needsImprovement': needsImprovement,
      'insights': insights,
      'suggestions': suggestions,
      'dailyCompletionRates': dailyCompletionRates,
    };
  }

  factory WeeklyStatsModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WeeklyStatsModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      weekNumber: data['weekNumber'] ?? 0,
      year: data['year'] ?? DateTime.now().year,
      weekStart: (data['weekStart'] as Timestamp).toDate(),
      weekEnd: (data['weekEnd'] as Timestamp).toDate(),
      overallCompletionRate: (data['overallCompletionRate'] ?? 0.0).toDouble(),
      categoryCompletion: Map<String, int>.from(
        data['categoryCompletion'] ?? {},
      ),
      topHabits: List<String>.from(data['topHabits'] ?? []),
      needsImprovement: List<String>.from(data['needsImprovement'] ?? []),
      insights: List<String>.from(data['insights'] ?? []),
      suggestions: List<String>.from(data['suggestions'] ?? []),
      dailyCompletionRates: Map<String, double>.from(
        (data['dailyCompletionRates'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0.0).toDouble()),
        ),
      ),
    );
  }

  // Helper: Get best day of the week
  String getBestDay() {
    if (dailyCompletionRates.isEmpty) return 'لا توجد بيانات';

    var sortedEntries = dailyCompletionRates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.first.key;
  }

  // Helper: Get improvement percentage from last week
  double getImprovementRate(double lastWeekRate) {
    return overallCompletionRate - lastWeekRate;
  }
}
