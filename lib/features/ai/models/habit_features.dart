class HabitFeatures {
  final double completionRate;
  final double activeStreaks;
  final int bestStreak;
  final int totalHabits;
  final double consistency;
  final double dropRate;

  HabitFeatures({
    required this.completionRate,
    required this.activeStreaks,
    required this.bestStreak,
    required this.totalHabits,
    required this.consistency,
    required this.dropRate,
  });

  Map<String, dynamic> toJson() => {
    "completionRate": completionRate.toDouble(),
    "activeStreaks": activeStreaks.toDouble(),
    "bestStreak": bestStreak.toDouble(),
    "totalHabits": totalHabits.toDouble(),
    "consistency": consistency.toDouble(),
    "dropRate": dropRate.toDouble(),
  };
}
