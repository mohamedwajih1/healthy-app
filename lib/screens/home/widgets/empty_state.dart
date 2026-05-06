import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final VoidCallback? onAddHabit;

  const EmptyState({super.key, this.onAddHabit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.spa_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'لا توجد عادات بعد',
          style: TextStyle(
            fontSize: 24,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ابدأ رحلتك بإضافة عادة جديدة!',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        if (onAddHabit != null) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddHabit,
            icon: const Icon(Icons.add),
            label: const Text('إضافة عادة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
