import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/habit_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/daily_log_model.dart';
import '../../models/habit_model.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() =>
      _WeeklyReportScreenState();
}

class _WeeklyReportScreenState
    extends State<WeeklyReportScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<DailyLogModel> _weekLogs = [];
  Map<String, int> _categoryCompletion = {};
  List<HabitModel> _topHabits = [];
  List<HabitModel> _needsImprovement = [];
  double _weeklyAverage = 0;
  String _bestDay = '';
  String _worstDay = '';

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadWeeklyReport();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyReport() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context
          .read<AuthProvider>();
      final habitProvider = context
          .read<HabitProvider>();

      if (authProvider.user == null) return;

      final now = DateTime.now();
      final weekStart = now.subtract(
        Duration(days: now.weekday - 1),
      );
      final weekEnd = weekStart.add(
        const Duration(days: 6),
      );

      // Load ALL logs for user, then filter in code (no index needed)
      final snapshot = await FirebaseFirestore
          .instance
          .collection('dailyLogs')
          .where(
            'userId',
            isEqualTo: authProvider.user!.uid,
          )
          .get();

      // Filter by date range in code
      _weekLogs = snapshot.docs
          .map((doc) {
            try {
              return DailyLogModel.fromFirestore(
                doc,
              );
            } catch (e) {
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
            final startDate = DateTime(
              weekStart.year,
              weekStart.month,
              weekStart.day,
            );
            final endDate = DateTime(
              weekEnd.year,
              weekEnd.month,
              weekEnd.day,
            );
            return logDate.isAfter(
                  startDate.subtract(
                    const Duration(days: 1),
                  ),
                ) &&
                logDate.isBefore(
                  endDate.add(
                    const Duration(days: 1),
                  ),
                );
          })
          .toList();

      // Sort by date
      _weekLogs.sort(
        (a, b) => a.date.compareTo(b.date),
      );

      // Calculate weekly average
      if (_weekLogs.isNotEmpty) {
        _weeklyAverage =
            _weekLogs
                .map(
                  (log) =>
                      log
                          .completedHabitIds
                          .length /
                      (log.totalHabits == 0
                          ? 1
                          : log.totalHabits),
                )
                .reduce((a, b) => a + b) /
            _weekLogs.length;
      }

      // Find best and worst days
      if (_weekLogs.isNotEmpty) {
        var sortedLogs =
            List<DailyLogModel>.from(
              _weekLogs,
            )..sort(
              (a, b) =>
                  (b.completedHabitIds.length /
                          (b.totalHabits == 0
                              ? 1
                              : b.totalHabits))
                      .compareTo(
                        (a
                                .completedHabitIds
                                .length /
                            (a.totalHabits == 0
                                ? 1
                                : a.totalHabits)),
                      ),
            );
        _bestDay = _getDayName(
          sortedLogs.first.date.weekday,
        );
        _worstDay = _getDayName(
          sortedLogs.last.date.weekday,
        );
      }

      // Category completion analysis
      _categoryCompletion = {};
      final habits = habitProvider.habits;

      for (var habit in habits) {
        final categoryName = habit
            .getCategoryName();
        final completed = _weekLogs
            .where(
              (log) => log.completedHabitIds
                  .contains(habit.id),
            )
            .length;
        _categoryCompletion[categoryName] =
            (_categoryCompletion[categoryName] ??
                0) +
            completed;
      }

      // Top performing habits
      _topHabits =
          habits
              .where((h) => h.currentStreak >= 7)
              .toList()
            ..sort(
              (a, b) => b.currentStreak.compareTo(
                a.currentStreak,
              ),
            );
      _topHabits = _topHabits.take(3).toList();

      // Needs improvement
      _needsImprovement =
          habits
              .where((h) => h.currentStreak < 3)
              .toList()
            ..sort(
              (a, b) => a.currentStreak.compareTo(
                b.currentStreak,
              ),
            );
      _needsImprovement = _needsImprovement
          .take(3)
          .toList();

      setState(() => _isLoading = false);
      _animationController.forward();
    } catch (e) {
      print('Error loading weekly report: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getDayName(int weekday) {
    const days = [
      '',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return weekday < days.length
        ? days[weekday]
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingState()
          : CustomScrollView(
              physics:
                  const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),

                // Hero Score Card
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildHeroScoreCard(),
                  ),
                ),

                // Week Overview
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildWeekOverview(),
                  ),
                ),

                // Best & Worst Days
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildBestWorstDays(),
                  ),
                ),

                // Category Performance
                if (_categoryCompletion
                    .isNotEmpty)
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child:
                          _buildCategoryPerformance(),
                    ),
                  ),

                // Top Habits
                if (_topHabits.isNotEmpty)
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildTopHabits(),
                    ),
                  ),

                // Needs Improvement
                if (_needsImprovement.isNotEmpty)
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child:
                          _buildNeedsImprovement(),
                    ),
                  ),

                // Insights & Tips
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildInsightsTips(),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
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
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 8,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(
                  context,
                ).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'جاري إنشاء تقريرك الأسبوعي...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تحليل بيانات 7 أيام',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final now = DateTime.now();
    final weekStart = now.subtract(
      Duration(days: now.weekday - 1),
    );
    final weekEnd = weekStart.add(
      const Duration(days: 6),
    );

    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(
          right: 56,
          bottom: 16,
          left: 16,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'التقرير الأسبوعي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${DateFormat('d MMM', 'ar').format(weekStart)} - ${DateFormat('d MMM', 'ar').format(weekEnd)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.15),
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

  Widget _buildHeroScoreCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradientColors(
            _weeklyAverage,
          ),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _getGradientColors(
              _weeklyAverage,
            )[0].withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🎯',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            '${_weeklyAverage.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'معدل الإنجاز الأسبوعي',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.2,
              ),
              borderRadius: BorderRadius.circular(
                20,
              ),
            ),
            child: Text(
              _getPerformanceLabel(
                _weeklyAverage,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'نظرة سريعة على الأسبوع',
          ),
          const SizedBox(height: 16),
          Row(
            children: _weekLogs.asMap().entries.map((
              entry,
            ) {
              final log = entry.value;
              return Expanded(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                  child: Column(
                    children: [
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: _getColorForRate(
                            log
                                    .completedHabitIds
                                    .length /
                                (log.totalHabits ==
                                        0
                                    ? 1
                                    : log.totalHabits),
                          ),
                          borderRadius:
                              BorderRadius.circular(
                                12,
                              ),
                          boxShadow: [
                            BoxShadow(
                              color: _getColorForRate(
                                log
                                        .completedHabitIds
                                        .length /
                                    (log.totalHabits ==
                                            0
                                        ? 1
                                        : log.totalHabits),
                              ).withOpacity(0.3),
                              blurRadius: 8,
                              offset:
                                  const Offset(
                                    0,
                                    4,
                                  ),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${(log.completedHabitIds.length / (log.totalHabits == 0 ? 1 : log.totalHabits) * 100).toInt()}%',
                            style:
                                const TextStyle(
                                  color: Colors
                                      .white,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 14,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getDayName(
                          log.date.weekday,
                        ).substring(0, 1),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBestWorstDays() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('أفضل وأسوأ أيامك'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDayCard(
                  icon: '🌟',
                  title: 'أفضل يوم',
                  day: _bestDay,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFA751),
                      Color(0xFFFFE259),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDayCard(
                  icon: '💪',
                  title: 'يحتاج تحسين',
                  day: _worstDay,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF667EEA),
                      Color(0xFF764BA2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard({
    required String icon,
    required String title,
    required String day,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPerformance() {
    final sortedCategories =
        _categoryCompletion.entries.toList()
          ..sort(
            (a, b) => b.value.compareTo(a.value),
          );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'الأداء حسب التصنيف',
          ),
          const SizedBox(height: 16),
          ...sortedCategories.take(5).map((
            entry,
          ) {
            final maxValue = sortedCategories
                .first
                .value
                .toDouble();
            final percentage =
                (entry.value / maxValue);

            return Container(
              margin: const EdgeInsets.only(
                bottom: 12,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${entry.value} مرة',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 10,
                      backgroundColor:
                          Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation(
                            _getCategoryColor(
                              entry.key,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopHabits() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('🏆 أفضل 3 عادات'),
          const SizedBox(height: 16),
          ..._topHabits.asMap().entries.map((
            entry,
          ) {
            final index = entry.key;
            final habit = entry.value;
            return _buildHabitListItem(
              habit: habit,
              rank: index + 1,
              isTop: true,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNeedsImprovement() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '💡 عادات تحتاج اهتمام',
          ),
          const SizedBox(height: 16),
          ..._needsImprovement.map((habit) {
            return _buildHabitListItem(
              habit: habit,
              isTop: false,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHabitListItem({
    required HabitModel habit,
    int? rank,
    required bool isTop,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (rank != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: rank == 1
                      ? [
                          const Color(0xFFFFD700),
                          const Color(0xFFFFE259),
                        ]
                      : rank == 2
                      ? [
                          const Color(0xFFC0C0C0),
                          const Color(0xFFE8E8E8),
                        ]
                      : [
                          const Color(0xFFCD7F32),
                          const Color(0xFFDDA76A),
                        ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          if (rank != null)
            const SizedBox(width: 12),
          Text(
            habit.getCategoryIcon(),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${habit.currentStreak} يوم متتالي',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '🔥',
            style: TextStyle(
              fontSize: isTop ? 24 : 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTips() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF11998E),
            Color(0xFF38EF7D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF11998E,
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
          const Row(
            children: [
              Text(
                '💡',
                style: TextStyle(fontSize: 28),
              ),
              SizedBox(width: 12),
              Text(
                'نصيحة الأسبوع',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getWeeklyTip(_weeklyAverage),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  List<Color> _getGradientColors(double rate) {
    if (rate >= 80) {
      return [
        const Color(0xFF11998E),
        const Color(0xFF38EF7D),
      ];
    }
    if (rate >= 60) {
      return [
        const Color(0xFF667EEA),
        const Color(0xFF764BA2),
      ];
    }
    if (rate >= 40) {
      return [
        const Color(0xFFFF6B6B),
        const Color(0xFFFFE66D),
      ];
    }
    return [
      const Color(0xFFFF6B6B),
      const Color(0xFFC44569),
    ];
  }

  String _getPerformanceLabel(double rate) {
    if (rate >= 90) return 'أداء استثنائي! 🌟';
    if (rate >= 75) return 'أداء ممتاز! 💪';
    if (rate >= 60) return 'أداء جيد جداً! ⭐';
    if (rate >= 40) return 'أداء مقبول 👍';
    return 'يحتاج تحسين 🌱';
  }

  Color _getColorForRate(double rate) {
    if (rate >= 80) {
      return const Color(0xFF38EF7D);
    }
    if (rate >= 60) {
      return const Color(0xFF667EEA);
    }
    if (rate >= 40) {
      return const Color(0xFFFFE66D);
    }
    return const Color(0xFFFF6B6B);
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'رياضة': const Color(0xFF2196F3),
      'تغذية': const Color(0xFF4CAF50),
      'نوم': const Color(0xFF9C27B0),
      'قراءة': const Color(0xFFFF9800),
      'تأمل': const Color(0xFF00BCD4),
      'ماء': const Color(0xFF03A9F4),
    };
    return colors[category] ?? Colors.grey;
  }

  String _getWeeklyTip(double rate) {
    if (rate >= 80) {
      return 'أنت في المسار الصحيح! حافظ على هذا الزخم وفكر في إضافة تحدٍ جديد لنفسك. النجاح يولد النجاح! 🚀';
    } else if (rate >= 60) {
      return 'أداء جيد! حاول تحديد العادة الأصعب بالنسبة لك واجعلها أولوية هذا الأسبوع. التركيز يصنع الفرق! 🎯';
    } else if (rate >= 40) {
      return 'لا تستسلم! اختر عادة واحدة فقط وركز عليها لمدة أسبوع كامل. الاتساق أهم من الكمال! 💪';
    } else {
      return 'كل خطوة صغيرة تحسب! ابدأ بأبسط عادة لديك واجعلها روتيناً يومياً. الرحلة تبدأ بخطوة واحدة! 🌱';
    }
  }
}
