import '../utils/constants.dart';
import '../models/habit_model.dart';
import 'package:flutter/material.dart';

class HabitCard extends StatelessWidget {
  final HabitModel habit;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCompleted,
    required this.onToggle,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categoryInfo = AppConstants
        .categoryInfo[habit.category.name];
    final categoryColor =
        categoryInfo?['color'] ?? Colors.grey;

    // Wrap with Dismissible for swipe actions
    return Dismissible(
      key: Key(habit.id),
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.edit,
          color: Colors.white,
          size: 32,
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction ==
            DismissDirection.endToStart) {
          // Delete - show confirmation
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('حذف العادة'),
              content: const Text(
                'هل أنت متأكد من حذف هذه العادة؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    false,
                  ),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    true,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('حذف'),
                ),
              ],
            ),
          );
        } else {
          // Edit
          if (onEdit != null) {
            onEdit!();
          }
          return false; // Don't dismiss
        }
      },
      onDismissed: (direction) {
        if (direction ==
                DismissDirection.endToStart &&
            onDelete != null) {
          onDelete!();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.grey[50]
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isCompleted
              ? Border.all(
                  color: Colors.green.shade200,
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: categoryColor.withOpacity(
                0.15,
              ),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Modern Checkbox Button
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 200,
                    ),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: isCompleted
                          ? LinearGradient(
                              colors: [
                                Colors
                                    .green
                                    .shade400,
                                Colors
                                    .green
                                    .shade600,
                              ],
                              begin: Alignment
                                  .topLeft,
                              end: Alignment
                                  .bottomRight,
                            )
                          : null,
                      color: isCompleted
                          ? null
                          : Colors.grey[100],
                      shape: BoxShape.circle,
                      boxShadow: isCompleted
                          ? [
                              BoxShadow(
                                color: Colors
                                    .green
                                    .withOpacity(
                                      0.4,
                                    ),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.grey
                                    .withOpacity(
                                      0.2,
                                    ),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      color: isCompleted
                          ? Colors.white
                          : Colors.grey[500],
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Habit Info
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Habit Name
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w700,
                          decoration: isCompleted
                              ? TextDecoration
                                    .lineThrough
                              : null,
                          color: isCompleted
                              ? Colors.grey[500]
                              : Colors.grey[800],
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Category & Streak
                      Row(
                        children: [
                          // Category
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                            decoration: BoxDecoration(
                              color: categoryColor
                                  .withOpacity(
                                    0.1,
                                  ),
                              borderRadius:
                                  BorderRadius.circular(
                                    8,
                                  ),
                            ),
                            child: Row(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                Text(
                                  habit
                                      .getCategoryIcon(),
                                  style:
                                      const TextStyle(
                                        fontSize:
                                            12,
                                      ),
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Text(
                                  habit
                                      .getCategoryName(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        categoryColor,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),

                          // Streak
                          if (habit
                                  .currentStreak >
                              0)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                              decoration: BoxDecoration(
                                color: Colors
                                    .orange
                                    .withOpacity(
                                      0.1,
                                    ),
                                borderRadius:
                                    BorderRadius.circular(
                                      8,
                                    ),
                              ),
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize
                                        .min,
                                children: [
                                  const Text(
                                    '🔥',
                                    style:
                                        TextStyle(
                                          fontSize:
                                              12,
                                        ),
                                  ),
                                  const SizedBox(
                                    width: 4,
                                  ),
                                  Text(
                                    '${habit.currentStreak} يوم',
                                    style: const TextStyle(
                                      fontSize:
                                          12,
                                      color: Colors
                                          .orange,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Best Streak Badge
                if (habit.bestStreak >= 7)
                  Container(
                    padding: const EdgeInsets.all(
                      10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade300,
                          Colors.orange.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(
                            0,
                            2,
                          ),
                        ),
                      ],
                    ),
                    child: Text(
                      _getStreakBadge(
                        habit.bestStreak,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),

                // Menu button for edit/delete
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit' &&
                        onEdit != null) {
                      onEdit!();
                    } else if (value ==
                            'delete' &&
                        onDelete != null) {
                      _showDeleteConfirmation(
                        context,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color:
                                Colors.blue[600],
                            size: 18,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          const Text('تعديل'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color:
                                Colors.red[400],
                            size: 18,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          const Text(
                            'حذف',
                            style: TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('حذف العادة'),
        content: Text(
          'هل أنت متأكد من حذف "${habit.name}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onDelete != null) onDelete!();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  String _getStreakBadge(int streak) {
    if (streak >= 365) return '👑';
    if (streak >= 100) return '💎';
    if (streak >= 60) return '⭐';
    if (streak >= 30) return '🏆';
    if (streak >= 14) return '🎯';
    if (streak >= 7) return '✨';
    return '';
  }
}
