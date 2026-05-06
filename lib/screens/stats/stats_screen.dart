import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/habit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/daily_log_model.dart';
import '../../widgets/category_distribution_chart.dart';
import 'weekly_report_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() =>
      _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, double> _weekData = {};
  Map<DateTime, double> _heatmapData = {};
  List<double> _trendData = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadChartData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadChartData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context
          .read<AuthProvider>();
      if (authProvider.user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = authProvider.user!.uid;
      final now = DateTime.now();
      final startDate = now.subtract(
        const Duration(days: 83),
      );

      print(
        '📊 Loading chart data (last 84 days)...',
      );

      // Load ALL logs for user (no date filter = no index needed)
      final snapshot = await FirebaseFirestore
          .instance
          .collection('dailyLogs')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter by date range in code
      final allLogs = snapshot.docs
          .map((doc) {
            try {
              return DailyLogModel.fromFirestore(
                doc,
              );
            } catch (e) {
              print('Error parsing log: $e');
              return null;
            }
          })
          .whereType<DailyLogModel>()
          .where((log) {
            final logDate = DateTime(
              log.date.year,
              log.date.month,
              log.date.day,
            );
            final filterStart = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            return logDate.isAfter(
              filterStart.subtract(
                const Duration(days: 1),
              ),
            );
          })
          .toList();

      // Sort by date
      allLogs.sort(
        (a, b) => a.date.compareTo(b.date),
      );

      print('✅ Loaded ${allLogs.length} logs');

      // Process data for weekly chart (last 7 days)
      Map<String, double> tempWeekData = {};
      final weekStart = now.subtract(
        const Duration(days: 6),
      );
      final weekLogs = allLogs.where((log) {
        return log.date.isAfter(
          weekStart.subtract(
            const Duration(days: 1),
          ),
        );
      }).toList();

      for (var log in weekLogs) {
        final dayKey = log.date.weekday
            .toString();
        tempWeekData[dayKey] =
            log.completedHabitIds.length /
            (log.totalHabits == 0
                ? 1
                : log.totalHabits);
      }

      // Process data for heatmap (all logs)
      Map<DateTime, double> tempHeatmapData = {};
      for (var log in allLogs) {
        final normalizedDate = DateTime(
          log.date.year,
          log.date.month,
          log.date.day,
        );
        tempHeatmapData[normalizedDate] =
            log.completedHabitIds.length /
            (log.totalHabits == 0
                ? 1
                : log.totalHabits);
      }

      // Process data for trend (last 30 days)
      List<double> tempTrendData = List.filled(
        30,
        0,
      );
      final trendStart = now.subtract(
        const Duration(days: 29),
      );

      for (var log in allLogs) {
        if (log.date.isAfter(
          trendStart.subtract(
            const Duration(days: 1),
          ),
        )) {
          final daysDiff = now
              .difference(log.date)
              .inDays;
          if (daysDiff < 30 && daysDiff >= 0) {
            tempTrendData[29 - daysDiff] =
                log.completedHabitIds.length /
                (log.totalHabits == 0
                    ? 1
                    : log.totalHabits);
          }
        }
      }

      if (mounted) {
        setState(() {
          _weekData = tempWeekData;
          _heatmapData = tempHeatmapData;
          _trendData = tempTrendData;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      print('❌ Error loading chart data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitProvider = context
        .watch<HabitProvider>();

    return Scaffold(
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadChartData,
              child: CustomScrollView(
                physics:
                    const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(
                    habitProvider,
                  ),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildQuickStatsGrid(
                        habitProvider,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child:
                          _buildTodayProgressCard(
                            habitProvider,
                          ),
                    ),
                  ),
                  if (habitProvider
                          .getBestPerformingHabit() !=
                      null)
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child:
                            _buildBestHabitCard(
                              habitProvider,
                            ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child:
                          _buildWeeklyReportCard(
                            context,
                          ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                            20,
                            24,
                            20,
                            8,
                          ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.pie_chart,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            'توزيع العادات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Theme.of(
                                        context,
                                      )
                                      .colorScheme
                                      .primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                        child:
                            CategoryDistributionChart(
                              habits:
                                  habitProvider
                                      .habits,
                            ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(
                  context,
                ).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'جاري تحليل بياناتك...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'بناء تقرير شامل',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    HabitProvider habitProvider,
  ) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(
          right: 20,
          bottom: 16,
          left: 20,
        ),
        title: const Text(
          'التقارير والإحصائيات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.1),
                Theme.of(
                  context,
                ).scaffoldBackgroundColor,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsGrid(
    HabitProvider habitProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildModernStatCard(
              icon: Icons
                  .local_fire_department_rounded,
              title: 'سلاسل نشطة',
              value:
                  '${habitProvider.getActiveStreaksCount()}',
              color: const Color(0xFFFF6B6B),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF6B6B),
                  Color(0xFFFF8E53),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModernStatCard(
              icon: Icons.spa_rounded,
              title: 'إجمالي العادات',
              value:
                  '${habitProvider.totalHabits}',
              color: const Color(0xFF4ECDC4),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4ECDC4),
                  Color(0xFF44A08D),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModernStatCard(
              icon: Icons.trending_up_rounded,
              title: 'معدل اليوم',
              value:
                  '${habitProvider.todayCompletionRate.toStringAsFixed(0)}%',
              color: const Color(0xFF6C5CE7),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C5CE7),
                  Color(0xFFA29BFE),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Gradient gradient,
  }) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -15,
            right: -15,
            child: Icon(
              icon,
              size: 80,
              color: Colors.white.withOpacity(
                0.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white
                              .withOpacity(0.9),
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgressCard(
    HabitProvider habitProvider,
  ) {
    final percentage =
        habitProvider.totalHabits > 0
        ? (habitProvider.completedToday /
              habitProvider.totalHabits)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF667EEA),
            Color(0xFF764BA2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF667EEA,
            ).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تقدم اليوم',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.2,
                  ),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '${habitProvider.completedToday}/${habitProvider.totalHabits}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.3,
                  ),
                  borderRadius:
                      BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white
                            .withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getMotivationalMessage(
              percentage * 100,
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(
                0.95,
              ),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestHabitCard(
    HabitProvider habitProvider,
  ) {
    final bestHabit = habitProvider
        .getBestPerformingHabit()!;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFA751),
            Color(0xFFFFE259),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFFFA751,
            ).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.3,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              bestHabit.getCategoryIcon(),
              style: const TextStyle(
                fontSize: 32,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏆 أفضل عادة',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bestHabit.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      '🔥',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'سلسلة ${bestHabit.bestStreak} يوم',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build weekly report card with navigation to detailed weekly report
  Widget _buildWeeklyReportCard(
    BuildContext context,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade400,
            Colors.blue.shade500,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const WeeklyReportScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(
                    12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.2),
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.calendar_view_week,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التقرير الأسبوعي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عرض إنجازاتك وتحليل أدائك لهذا الأسبوع',
                        style: TextStyle(
                          color: Colors.white
                              .withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(
                    0.8,
                  ),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMotivationalMessage(
    double percentage,
  ) {
    if (percentage == 100) {
      return '🎉 مذهل! أكملت كل عاداتك اليوم!';
    }
    if (percentage >= 80) {
      return '💪 أداء رائع! استمر في التقدم!';
    }
    if (percentage >= 60) {
      return '⭐ تقدم جيد! أنت على الطريق الصحيح!';
    }
    if (percentage >= 40) {
      return '🚀 بداية جيدة! لا تستسلم!';
    }
    if (percentage >= 20) {
      return '🌱 كل خطوة تقربك من هدفك!';
    }
    if (percentage > 0) {
      return '✨ البداية دائماً صعبة، استمر!';
    }
    return '🌟 ابدأ الآن، اليوم فرصة جديدة!';
  }
}
