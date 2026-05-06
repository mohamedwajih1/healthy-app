import 'package:flutter/material.dart';
import 'modern_stat_card.dart';

class QuickStatsGrid extends StatelessWidget {
  final int activeStreaks;
  final int totalHabits;

  const QuickStatsGrid({
    super.key,
    required this.activeStreaks,
    required this.totalHabits,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ModernStatCard(
              icon: Icons.local_fire_department_rounded,
              title: 'سلاسل نشطة',
              value: '$activeStreaks',
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ModernStatCard(
              icon: Icons.stars_rounded,
              title: 'إجمالي العادات',
              value: '$totalHabits',
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
