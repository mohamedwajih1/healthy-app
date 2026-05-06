import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/daily_log_model.dart';
import '../../models/habit_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/habit_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healty_app/features/ai/logic/feature_extractor.dart';
import 'package:healty_app/screens/ai/ai_insights_screen.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  State<AIInsightsScreen> createState() =>
      _AIInsightsScreenState();
}

class _AIInsightsScreenState
    extends State<AIInsightsScreen> {
  // final MLAIService _aiService = MLAIService();
  // final AIInsightsService _aiService = AIInsightsService();
  AIInsights? _insights;
  bool _isLoading = false;
  String? _error;
  // Stores completion rate for generating dynamic UI messages
  double _completionRate = 0.0;

  // Base URL for AI backend - auto-detects emulator vs real device
  String get baseUrl {
    // Production Replit backend URL
    const String replitUrl =
        'https://healthy-ai-backend--mohamedsaadytr.replit.app';

    // Check if running on emulator (Android emulator uses 10.0.2.2 for localhost)
    if (Platform.isAndroid) {
      // For Android emulator, use localhost bridge
      // For real device, use the production URL
      return replitUrl;
    }
    return replitUrl;
  }

  @override
  void initState() {
    super.initState();
    _generateInsights();
  }

  Future<void> _generateInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context
          .read<AuthProvider>();
      final habitProvider = context
          .read<HabitProvider>();

      if (authProvider.user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final userId = authProvider.user!.uid;

      // Force sync habit data before AI analysis
      habitProvider.listenToHabits(userId);

      // STEP 2: WAIT FOR SYNC
      await Future.delayed(
        Duration(milliseconds: 200),
      );

      // STEP 3: REBUILD DATA (use fresh data)
      final habits = habitProvider.habits;
      final todayLog = habitProvider.todayLog;

      // STEP 1: LOAD REAL LOGS (last 14 days)
      final List<DailyLogModel> logs =
          await _loadRecentLogs(userId);

      // STEP 1: PRINT ALL LOGS BEFORE PROCESSING
      print("=== ALL LOGS ===");
      for (final log in logs) {
        print("Log date: ${log.date}");
        print(
          "Completed: ${log.completedHabitIds}",
        );
        print("Total: ${log.totalHabits}");
      }

      // STEP 2: PRINT TODAY DATE FOR VERIFICATION
      print("Today: ${DateTime.now()}");

      // Use last 14 days logs (NOT today-only) for features and server completion_rate.
      // Keep today log only for completion list mapping.
      print(
        "=== SELECTED TODAY LOG (OPTIONAL) ===",
      );
      print(todayLog?.date);
      print(todayLog?.completedHabitIds);

      // STEP 2: CALL FEATURE EXTRACTOR
      final features = extractFeatures(
        habits,
        logs,
      );

      // Save completion rate for use in UI messages
      _completionRate = features.completionRate
          .toDouble();

      final completedHabitsKeys =
          _getCompletedHabitsForToday(
            todayLog,
            habits,
          );

      // DEBUG (MANDATORY)
      print("=== HABIT MAPPING DEBUG ===");
      print(
        "Habit IDs: ${todayLog?.completedHabitIds}",
      );
      print("Mapped Keys: $completedHabitsKeys");

      // Build request with real feature values from extractor
      final requestData = {
        "completionRate": features.completionRate
            .toDouble(),
        "activeStreaks": features.activeStreaks
            .toDouble(),
        "bestStreak": features.bestStreak
            .toDouble(),
        "totalHabits": features.totalHabits
            .toDouble(),
        "consistency": features.consistency
            .toDouble(),
        "dropRate": features.dropRate.toDouble(),
        "habit_names": _normalizeHabitNames(
          habitProvider.habits,
        ),
        "completed_habits": completedHabitsKeys,
        "completion_rate": features.completionRate
            .toDouble(),
      };

      // DATA CHECK
      final habitNames = _normalizeHabitNames(
        habitProvider.habits,
      );
      print("=== DATA CHECK ===");
      print("habit_names: $habitNames");
      print(
        "completed_habits: $completedHabitsKeys",
      );
      if (habitNames.isEmpty) {
        print("WARNING: habit_names is EMPTY");
      }
      if (completedHabitsKeys.isEmpty) {
        print(
          "WARNING: completed_habits is EMPTY",
        );
      }

      // REQUEST DEBUG
      print("=== REQUEST DEBUG ===");
      print(jsonEncode(features.toJson()));

      // Ensure all values are normalized to 0-1 range
      final normalizedData =
          Map<String, dynamic>.from(requestData);

      // Ensure completionRate is always 0-1
      if (normalizedData['completionRate'] >
          1.0) {
        normalizedData['completionRate'] =
            (normalizedData['completionRate']
                as double) /
            100.0;
      }

      // Ensure consistency is always 0-1
      if (normalizedData['consistency'] > 1.0) {
        normalizedData['consistency'] =
            (normalizedData['consistency']
                as double) /
            100.0;
      }

      // Ensure dropRate is always 0-1
      if (normalizedData['dropRate'] > 1.0) {
        normalizedData['dropRate'] =
            (normalizedData['dropRate']
                as double) /
            100.0;
      }

      // Ensure all values are proper doubles and clamp to valid range
      normalizedData['completionRate'] =
          double.parse(
            normalizedData['completionRate']
                .toString(),
          ).clamp(0.0, 1.0);
      normalizedData['consistency'] =
          double.parse(
            normalizedData['consistency']
                .toString(),
          ).clamp(0.0, 1.0);
      normalizedData['dropRate'] = double.parse(
        normalizedData['dropRate'].toString(),
      ).clamp(0.0, 1.0);
      normalizedData['activeStreaks'] =
          double.parse(
            normalizedData['activeStreaks']
                .toString(),
          ).clamp(0.0, 999.0);
      normalizedData['bestStreak'] = double.parse(
        normalizedData['bestStreak'].toString(),
      ).clamp(0.0, 999.0);
      normalizedData['totalHabits'] =
          double.parse(
            normalizedData['totalHabits']
                .toString(),
          ).clamp(0.0, 99.0);

      print(
        "FLUTTER DEBUG: REQUEST BODY (ENSURED DOUBLES): $normalizedData",
      );

      // Prevent same response bug with timestamp
      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      // FULL JSON DEBUG
      print("=== FULL REQUEST JSON ===");
      print(
        jsonEncode({
          ...normalizedData,
          "t": timestamp,
        }),
      );

      // Clear state before request
      setState(() {
        _insights = null;
        _isLoading = true;
      });

      final response = await http
          .post(
            Uri.parse("$baseUrl/analyze"),
            headers: {
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              ...normalizedData,
              "t": timestamp,
            }),
          )
          .timeout(const Duration(seconds: 10));

      // RESPONSE DEBUG
      print("=== RESPONSE DEBUG ===");
      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        // Parse response
        final data = jsonDecode(response.body);

        if (!data['success']) {
          print("SERVER ERROR: ${response.body}");
          throw Exception(
            "Server failed: ${response.body}",
          );
        }

        // TRACE 1: AFTER API RESPONSE
        print("=== AFTER API ===");
        print(
          "summary: ${data['data']['summary']}",
        );

        final rawSummary =
            data['data']['summary']
                ?.toString()
                .trim() ??
            "";

        // Provide fallback summary if server returns empty
        String safeSummary;
        if (rawSummary.isEmpty) {
          if (features.completionRate == 0) {
            safeSummary =
                "لم تبدأ رحلتك بعد، البداية أهم خطوة";
          } else if (features.completionRate <
              0.4) {
            safeSummary =
                "بدأت بالفعل، لكن تحتاج دفعة للاستمرار";
          } else if (features.completionRate <
              0.8) {
            safeSummary =
                "أداؤك جيد ويمكنك تحسينه أكثر";
          } else {
            safeSummary =
                "أداء ممتاز! استمر بنفس القوة";
          }
        } else {
          safeSummary = rawSummary;
        }

        final motivation =
            data['data']['motivation'] ?? '';
        final strengths = List<String>.from(
          data['data']['strengths'] ?? [],
        );
        final improvements = List<String>.from(
          data['data']['improvements'] ?? [],
        );
        final suggestions = List<String>.from(
          data['data']['suggestions'] ?? [],
        );

        // BEHAVIOR INTERPRETATION LAYER
        final double rate =
            features.completionRate;
        String userZone;
        if (rate < 0.3) {
          userZone = "LOW";
        } else if (rate < 0.7) {
          userZone = "MEDIUM";
        } else {
          userZone = "HIGH";
        }

        // 👇 APPLY ZONE STYLE AFTER FIX
        String finalSummary;

        if (userZone == "LOW") {
          finalSummary =
              "واضح إنك محتاج تبدأ بجد 👇\n$safeSummary";
        } else if (userZone == "MEDIUM") {
          finalSummary =
              "أنت ماشي كويس بس محتاج تركيز أكتر 👇\n$safeSummary";
        } else {
          finalSummary =
              "🔥 ممتاز! كمل بنفس المستوى 👇\n$safeSummary";
        }

        // ZONE-BASED SUGGESTION FILTERING
        List<String> finalSuggestions;
        if (userZone == "LOW") {
          finalSuggestions = suggestions
              .take(2)
              .toList();
        } else if (userZone == "MEDIUM") {
          finalSuggestions = suggestions
              .take(3)
              .toList();
        } else {
          finalSuggestions = suggestions
              .take(2)
              .toList();
        }

        final recommendedHabits = finalSuggestions
            .map((habit) {
              return RecommendedHabit(
                name: habit,
                reason: 'بناءً على تحليلك',
              );
            })
            .toList();

        // TRACE 2: MODEL BUILD
        print("=== MODEL BUILD ===");
        print("summary: $finalSummary");

        // DEBUG (MANDATORY)
        print("=== BEHAVIOR LAYER ===");
        print("completionRate: $rate");
        print("userZone: $userZone");
        print("finalSummary: $finalSummary");

        setState(() {
          _insights = AIInsights(
            summary: finalSummary,
            motivation: motivation,
            strengths: strengths,
            improvements: improvements,
            suggestions: finalSuggestions,
            recommendedHabits: recommendedHabits,
          );
          _isLoading = false;
          _error = null;
        });

        // Force UI rebuild (IMPORTANT)
        WidgetsBinding.instance
            .addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });
      } else {
        print(
          "DEBUG: Server error response: ${response.body}",
        );
        throw Exception('فشل التحليل');
      }
    } on TimeoutException catch (e) {
      print("🔍 DEBUG: Timeout error: $e");
      if (mounted) {
        setState(() {
          _error =
              'انتهت مهلة الاتصال. تحقق من اتصال الشبكة.';
          _isLoading = false;
        });
      }
    } on SocketException catch (e) {
      print("🔍 DEBUG: Network error: $e");
      if (mounted) {
        setState(() {
          _error =
              'فشل الاتصال بالخادم. تأكد من تشغيل الخادم.';
          _isLoading = false;
        });
      }
    } on FormatException catch (e) {
      print("🔍 DEBUG: JSON parsing error: $e");
      if (mounted) {
        setState(() {
          _error = 'خطأ في تنسيق البيانات.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print("🔍 DEBUG: General error: $e");
      if (mounted) {
        setState(() {
          _error =
              e.toString().contains('يجب تسجيل')
              ? e.toString()
              : 'حدث خطأ في التحليل: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<DailyLogModel>> _loadRecentLogs(
    String userId,
  ) async {
    final twoWeeksAgo = DateTime.now().subtract(
      const Duration(days: 14),
    );

    final snapshot = await FirebaseFirestore
        .instance
        .collection('dailyLogs')
        .where('userId', isEqualTo: userId)
        .where(
          'date',
          isGreaterThan: Timestamp.fromDate(
            twoWeeksAgo,
          ),
        )
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            return DailyLogModel.fromFirestore(
              doc,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<DailyLogModel>()
        .toList();
  }

  List<String> _normalizeHabitNames(
    List<HabitModel> habits,
  ) {
    Map<String, String> habitIdToKey = {
      "water": "water",
      "reading": "reading",
      "exercise": "exercise",
      "sleep": "sleep",
      "thinking": "thinking",
    };

    return habits
        .map((h) {
          return habitIdToKey[h.category.name
                  .toLowerCase()
                  .trim()] ??
              "";
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _getCompletedHabitsForToday(
    DailyLogModel? todayLog,
    List<HabitModel> habits,
  ) {
    if (todayLog == null) return [];

    final habitIdToKey = <String, String>{
      "water": "water",
      "reading": "reading",
      "exercise": "exercise",
      "sleep": "sleep",
      "thinking": "thinking",
    };

    final idToCategory = {
      for (final h in habits)
        h.id: h.category.name
            .toLowerCase()
            .trim(),
    };

    return todayLog.completedHabitIds
        .map((id) => idToCategory[id])
        .whereType<String>()
        .map((cat) => habitIdToKey[cat])
        .whereType<String>()
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحليل الذكي'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              onPressed: _generateInsights,
              tooltip: 'تحديث',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'جاري التحليل...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateInsights,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'إعادة المحاولة',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_insights == null) {
      return const Center(
        child: Text('لا توجد بيانات'),
      );
    }

    return RefreshIndicator(
      onRefresh: _generateInsights,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAIBadge(),
          const SizedBox(height: 24),
          if (_insights!
              .recommendedHabits
              .isNotEmpty) ...[
            _buildRecommendedHabitsCardLarge(),
            const SizedBox(height: 24),
          ],
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildMotivationCard(),
          if (_insights!
              .strengths
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildStrengthsCard(),
          ],
          if (_insights!
              .improvements
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildImprovementsCard(),
          ],
          if (_insights!
              .suggestions
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSuggestionsCard(),
          ],
          const SizedBox(height: 24),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildAIBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple[700]!,
              Colors.blue[700]!,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(
                0.3,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'تحليل ذكي',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    // TRACE 3: UI BUILD
    print("=== UI BUILD ===");
    print("summary: ${_insights?.summary}");

    final displaySummary =
        (_insights?.summary != null &&
            _insights!.summary.trim().isNotEmpty)
        ? _insights!.summary
        : "جاري تحليل بياناتك...";

    return _buildCard(
      title: 'ملخص التحليل',
      icon: Icons.analytics_rounded,
      color: Colors.blue,
      child: Text(
        displaySummary,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMotivationCard() {
    // Generate motivation message based on user performance
    String getDynamicMotivation() {
      final rate = _completionRate;
      if (rate >= 0.8) {
        return "🌟 نجم! أنجزت ${(rate * 100).toInt()}% - استمر في التألق!";
      } else if (rate >= 0.6) {
        return "💪 أداء قوي ${(rate * 100).toInt()}% - أنت على الطريق الصحيح!";
      } else if (rate >= 0.4) {
        return "🌱 تقدم جيد ${(rate * 100).toInt()}% - زودها شوية!";
      } else if (rate >= 0.2) {
        return "⚡ بدأت ${(rate * 100).toInt()}% - أكمل عادة واحدة الآن!";
      } else if (rate > 0) {
        return "👍 خطوة أولى - حدد هدف بسيط لهذا اليوم!";
      } else {
        return "🚀 ابدأ رحلتك بأول عادة صحية اليوم!";
      }
    }

    final displayMotivation =
        (_insights?.motivation != null &&
            _insights!.motivation
                .trim()
                .isNotEmpty)
        ? _insights!.motivation
        : getDynamicMotivation();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.pink[50]!,
            Colors.purple[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.pink[100]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.favorite_rounded,
            color: Colors.pink[400],
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              displayMotivation,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.pink[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsCard() {
    return _buildCard(
      title: 'نقاط القوة',
      icon: Icons.emoji_events_rounded,
      color: Colors.green,
      child: Column(
        children: _insights!.strengths
            .map(
              (item) => _buildListItem(
                item,
                Icons.check_circle_rounded,
                Colors.green,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildImprovementsCard() {
    return _buildCard(
      title: 'فرص التحسين',
      icon: Icons.trending_up_rounded,
      color: Colors.orange,
      child: Column(
        children: _insights!.improvements
            .map(
              (item) => _buildListItem(
                item,
                Icons.lightbulb_rounded,
                Colors.orange,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    return _buildCard(
      title: 'نصائح عملية',
      icon: Icons.tips_and_updates_rounded,
      color: Colors.purple,
      child: Column(
        children: _insights!.suggestions
            .asMap()
            .entries
            .map(
              (e) => _buildNumberedItem(
                e.key + 1,
                e.value,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildRecommendedHabitsCardLarge() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal[400]!,
            Colors.blue[400]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(
                            10,
                          ),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(
                              12,
                            ),
                      ),
                      child: const Icon(
                        Icons
                            .auto_awesome_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'عادات مقترحة لك',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'بناءً على تحليل أدائك',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Colors.white70,
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

          // Habits List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: _insights!
                  .recommendedHabits
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _buildLargeHabitItem(
                          entry.value,
                          entry.key,
                        ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeHabitItem(
    RecommendedHabit habit,
    int index,
  ) {
    final colors = [
      [Colors.purple[400]!, Colors.purple[50]!],
      [Colors.orange[400]!, Colors.orange[50]!],
      [Colors.pink[400]!, Colors.pink[50]!],
      [Colors.blue[400]!, Colors.blue[50]!],
    ];

    final colorPair =
        colors[index % colors.length];

    return Container(
      margin: EdgeInsets.only(
        bottom:
            index <
                _insights!
                        .recommendedHabits
                        .length -
                    1
            ? 16
            : 0,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorPair[1],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorPair[0].withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorPair[0].withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorPair[0],
                  borderRadius:
                      BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorPair[0]
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons
                      .local_fire_department_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  habit.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorPair[0]
                        .withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                10,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_rounded,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    habit.reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    String text,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedItem(
    int number,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'التحليل مبني على بياناتك وليس بديلاً للاستشارة المهنية',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
