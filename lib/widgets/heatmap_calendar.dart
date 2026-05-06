import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HeatmapCalendar extends StatelessWidget {
  final Map<DateTime, double> data; // date -> completion rate
  final int weeksToShow;

  const HeatmapCalendar({super.key, required this.data, this.weeksToShow = 12});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'خريطة النشاط',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // للعربي
              child: _buildHeatmap(),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap() {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: weeksToShow * 7));

    List<Widget> columns = [];

    for (int week = 0; week < weeksToShow; week++) {
      List<Widget> dayBoxes = [];

      for (int day = 0; day < 7; day++) {
        final date = startDate.add(Duration(days: week * 7 + day));
        final rate = _getCompletionRate(date);

        dayBoxes.add(
          Tooltip(
            message:
                '${DateFormat('d MMM', 'ar').format(date)}\n${rate.toStringAsFixed(0)}%',
            child: Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _getHeatmapColor(rate),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.grey[300]!, width: 0.5),
              ),
            ),
          ),
        );
      }

      columns.add(Column(mainAxisSize: MainAxisSize.min, children: dayBoxes));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: columns);
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('أقل', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          return Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _getHeatmapColor(index * 25.0),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 8),
        const Text('أكثر', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  double _getCompletionRate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    for (var entry in data.entries) {
      final entryDate = DateTime(
        entry.key.year,
        entry.key.month,
        entry.key.day,
      );
      if (entryDate == normalizedDate) {
        return entry.value;
      }
    }

    return 0.0;
  }

  Color _getHeatmapColor(double rate) {
    if (rate >= 90) return const Color(0xFF216e39);
    if (rate >= 70) return const Color(0xFF30a14e);
    if (rate >= 50) return const Color(0xFF40c463);
    if (rate >= 30) return const Color(0xFF9be9a8);
    if (rate > 0) return const Color(0xFFc6e48b);
    return Colors.grey[200]!;
  }
}
