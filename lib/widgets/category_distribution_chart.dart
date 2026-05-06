import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/habit_model.dart';
import '../utils/constants.dart';

class CategoryDistributionChart extends StatelessWidget {
  final List<HabitModel> habits;

  const CategoryDistributionChart({super.key, required this.habits});

  @override
  Widget build(BuildContext context) {
    final categoryData = _getCategoryData();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع العادات حسب التصنيف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (habits.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'لا توجد عادات بعد',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildPieSections(categoryData),
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {},
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: _buildLegend(categoryData)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Map<HabitCategory, int> _getCategoryData() {
    Map<HabitCategory, int> data = {};

    for (var habit in habits) {
      data[habit.category] = (data[habit.category] ?? 0) + 1;
    }

    return data;
  }

  List<PieChartSectionData> _buildPieSections(Map<HabitCategory, int> data) {
    final total = data.values.fold<int>(0, (sum, count) => sum + count);

    return data.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      final categoryInfo = AppConstants.categoryInfo[entry.key.name];
      final color = categoryInfo?['color'] as Color? ?? Colors.grey;

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<HabitCategory, int> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: data.entries.map((entry) {
        final categoryInfo = AppConstants.categoryInfo[entry.key.name];
        final color = categoryInfo?['color'] as Color? ?? Colors.grey;
        final icon = categoryInfo?['icon'] ?? '✨';
        final name = categoryInfo?['name'] ?? 'أخرى';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${entry.value}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
