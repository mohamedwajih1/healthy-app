import 'dart:math';
import 'package:healty_app/models/habit_model.dart';
import 'package:healty_app/models/daily_log_model.dart';
import 'package:healty_app/features/ai/models/habit_features.dart';

HabitFeatures extractFeatures(
  List<HabitModel> habits,
  List<DailyLogModel> logs,
) {
  // 📊 Completion rate across provided logs (expected: last 14 days)
  final sortedLogs = List<DailyLogModel>.from(
    logs,
  )..sort((a, b) => a.date.compareTo(b.date));

  final normalizedRates = sortedLogs
      .map(
        (l) =>
            l.completedHabitIds.length
                .toDouble() /
            (l.totalHabits == 0
                ? 1.0
                : l.totalHabits.toDouble()),
      )
      .toList();

  // 📊 Completion rate (LATEST LOG ONLY for immediate feedback)
  final double completionRate =
      normalizedRates.isEmpty
      ? 0.0
      : normalizedRates.last
            .clamp(0.0, 1.0)
            .toDouble();

  // 📈 Historical average (for internal consistency check if needed, but not exported)
  final double averageRate =
      normalizedRates.isEmpty
      ? 0.0
      : (normalizedRates.reduce((a, b) => a + b) /
                normalizedRates.length)
            .clamp(0.0, 1.0)
            .toDouble();

  // DEBUG (MANDATORY)
  print("=== FEATURES INPUT WINDOW ===");
  print("logs_count: ${sortedLogs.length}");
  if (sortedLogs.isNotEmpty) {
    print("first_log: ${sortedLogs.first.date}");
    print("last_log: ${sortedLogs.last.date}");
  }
  print(
    "completionRate (Today): $completionRate",
  );
  print("averageRate (14d): $averageRate");

  // 🔥 Active streaks (WEIGHTED + NORMALIZED)
  final rawStreaks = habits.fold<int>(
    0,
    (sum, h) =>
        sum +
        (h.currentStreak > 0
            ? h.currentStreak
            : 0),
  );
  double activeStreaks = habits.isEmpty
      ? 0.0
      : (rawStreaks / (habits.length * 5)).clamp(
          0.0,
          1.0,
        );

  // 🏆 Best streak
  final bestStreak = habits.isEmpty
      ? 0
      : habits
            .map((h) => h.bestStreak)
            .reduce((a, b) => a > b ? a : b);

  // 📦 Total habits
  final totalHabits = habits.length;

  // 📈 Consistency (كل ما كان ثابت = رقم أعلى) - ensure 0-1 range
  double consistency = 0.0;
  if (sortedLogs.length > 1) {
    final avg =
        normalizedRates.reduce((a, b) => a + b) /
        normalizedRates.length;
    final variance =
        normalizedRates
            .map((l) => (l - avg) * (l - avg))
            .reduce((a, b) => a + b) /
        normalizedRates.length;
    consistency = pow(
      1 / (1 + variance),
      1.5,
    ).toDouble().clamp(0.0, 1.0);
  } else if (sortedLogs.length == 1) {
    consistency = completionRate;
  }
  // 📉 Drop rate (REAL TREND across ALL logs)
  double dropRate = 0.0;
  if (sortedLogs.length > 1) {
    final deltas = <double>[];
    for (int i = 1; i < sortedLogs.length; i++) {
      final prev = sortedLogs[i - 1];
      final curr = sortedLogs[i];
      final prevRate =
          prev.completedHabitIds.length
              .toDouble() /
          (prev.totalHabits == 0
              ? 1.0
              : prev.totalHabits.toDouble());
      final currRate =
          curr.completedHabitIds.length
              .toDouble() /
          (curr.totalHabits == 0
              ? 1.0
              : curr.totalHabits.toDouble());
      deltas.add(prevRate - currRate);
    }
    if (deltas.isNotEmpty) {
      dropRate =
          deltas.reduce((a, b) => a + b) /
          deltas.length;
      if (dropRate < 0) dropRate = 0.0;
      dropRate = (dropRate * 1.3).clamp(0.0, 1.0);
    }
  }

  // SMART BUCKETING + MICRO VARIATION
  double smartBucket(double v) {
    if (v < 0.3) return 0.2;
    if (v < 0.5) return 0.45;
    if (v < 0.7) return 0.65;
    if (v < 0.85) return 0.8;
    return 0.95;
  }

  final rawConsistency = consistency;
  final rawDropRate = dropRate;
  final rawActiveStreaks = activeStreaks;

  consistency =
      (smartBucket(consistency) +
              (consistency * 0.05))
          .clamp(0.0, 1.0);
  dropRate =
      (smartBucket(dropRate) + (dropRate * 0.05))
          .clamp(0.0, 1.0);
  activeStreaks =
      (smartBucket(activeStreaks) +
              (activeStreaks * 0.05))
          .clamp(0.0, 1.0);

  // DEBUG (RAW vs BUCKETED)
  print("=== SIGNAL DEBUG (RAW vs BUCKETED) ===");
  print("completionRate: $completionRate");
  print("consistency RAW: $rawConsistency");
  print("consistency FINAL: $consistency");
  print("dropRate RAW: $rawDropRate");
  print("dropRate FINAL: $dropRate");
  print("activeStreaks RAW: $rawActiveStreaks");
  print("activeStreaks FINAL: $activeStreaks");

  return HabitFeatures(
    completionRate: completionRate,
    activeStreaks: activeStreaks,
    bestStreak: bestStreak,
    totalHabits: totalHabits,
    consistency: consistency,
    dropRate: dropRate,
  );
}
