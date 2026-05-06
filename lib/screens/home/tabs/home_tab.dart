import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/habit_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/habit_provider.dart';
import '../../../widgets/habit_card.dart';
import '../../habits/add_habit_screen.dart';
import '../../habits/edit_habit_screen.dart';
import '../widgets/modern_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/modern_progress_card.dart';
import '../widgets/quick_stats_grid.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((
      _,
    ) {
      final authProvider = context
          .read<AuthProvider>();
      final habitProvider = context
          .read<HabitProvider>();

      if (authProvider.user != null &&
          habitProvider.currentUserId !=
              authProvider.user!.uid) {
        habitProvider.listenToHabits(
          authProvider.user!.uid,
        );
      }
    });
    final authProvider = context
        .watch<AuthProvider>();
    final habitProvider = context
        .watch<HabitProvider>();

    if (habitProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
        ),
      );
    }

    // Empty State
    if (habitProvider.habits.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final authProvider = context
              .read<AuthProvider>();
          final habitProvider = context
              .read<HabitProvider>();

          if (authProvider.user != null) {
            await habitProvider.refreshAllData(
              authProvider.user!.uid,
            );
          }
        },
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ModernHeader(user: authProvider.user),
            const SizedBox(height: 40),
            EmptyState(
              onAddHabit: () =>
                  _navigateToAddHabit(context),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = context
            .read<AuthProvider>();
        final habitProvider = context
            .read<HabitProvider>();

        if (authProvider.user != null) {
          await habitProvider.refreshAllData(
            authProvider.user!.uid,
          );
        }
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ModernHeader(
              user: authProvider.user,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: ModernProgressCard(
                completed:
                    habitProvider
                        .todayLog
                        ?.completedHabitIds
                        .length ??
                    0,
                total:
                    habitProvider.habits.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          SliverToBoxAdapter(
            child: QuickStatsGrid(
              activeStreaks:
                  _calculateActiveStreaks(
                    habitProvider.habits,
                  ),
              totalHabits:
                  habitProvider.habits.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          SliverToBoxAdapter(
            child: _buildHabitsHeader(
              context,
              habitProvider.habits.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 12),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final habit =
                    habitProvider.habits[index];
                final isCompleted =
                    habitProvider
                        .todayLog
                        ?.completedHabitIds
                        .contains(habit.id) ??
                    false;

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: HabitCard(
                    habit: habit,
                    isCompleted: isCompleted,
                    onToggle: () => _toggleHabit(
                      context,
                      habit,
                    ),
                    onEdit: () =>
                        _navigateToEditHabit(
                          context,
                          habit,
                        ),
                    onDelete: () => _deleteHabit(
                      context,
                      habit,
                    ),
                  ),
                );
              },
              childCount:
                  habitProvider.habits.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  int _calculateActiveStreaks(
    List<HabitModel> habits,
  ) {
    return habits
        .where((h) => h.currentStreak > 0)
        .length;
  }

  Widget _buildHabitsHeader(
    BuildContext context,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          // Title with modern styling
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary,
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'عاداتي',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 22,
                        ),
                  ),
                  Text(
                    '$count عادات نشطة',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Modern floating action button style
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(
              16,
            ),
            color: Theme.of(
              context,
            ).colorScheme.primary,
            child: InkWell(
              onTap: () =>
                  _navigateToAddHabit(context),
              borderRadius: BorderRadius.circular(
                16,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'عادة جديدة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddHabit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddHabitScreen(),
      ),
    );
  }

  void _navigateToEditHabit(
    BuildContext context,
    HabitModel habit,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditHabitScreen(habit: habit),
      ),
    );
  }

  void _toggleHabit(
    BuildContext context,
    HabitModel habit,
  ) {
    final authProvider = context
        .read<AuthProvider>();
    final habitProvider = context
        .read<HabitProvider>();
    habitProvider.toggleHabitCompletion(
      authProvider.user!.uid,
      habit,
    );
  }

  void _deleteHabit(
    BuildContext context,
    HabitModel habit,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              context
                  .read<HabitProvider>()
                  .deleteHabit(habit.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
