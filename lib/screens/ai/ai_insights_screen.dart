import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:healty_app/models/habit_model.dart';
import 'package:healty_app/models/daily_log_model.dart';

class AIInsightsService {
  // ⭐ Gemini API Key
  // احصل عليه من: https://aistudio.google.com/app/apikey
  static const String _apiKey =
      'AIzaSyDxJBUiwGSnJdZ4TScjOPAS58Vq-Q7q8Ww';

  /// Generate personalized insights using Gemini API
  Future<AIInsights> generateInsights({
    required List<HabitModel> habits,
    required List<DailyLogModel> recentLogs,
    required double overallCompletionRate,
  }) async {
    print(
      '🤖 Starting AI Insights generation...',
    );

    // تحقق من وجود API Key صحيح
    if (_apiKey == 'YOUR_GEMINI_API_KEY' ||
        _apiKey.isEmpty) {
      print('❌ Invalid API Key');
      return _getFallbackInsights(
        habits,
        overallCompletionRate,
      );
    }

    // إذا مفيش عادات أصلاً، ارجع insights افتراضية بسيطة
    if (habits.isEmpty) {
      print(
        'ℹ️ No habits found, returning default insights',
      );
      return _getEmptyStateInsights();
    }

    // أفضل الموديلات المتاحة بالترتيب (من الأدق للأسرع)
    final modelsToTry = [
      {
        'version': 'v1beta',
        'model': 'gemini-2.5-pro',
      },
      {
        'version': 'v1beta',
        'model': 'gemini-2.5-flash',
      },
      {
        'version': 'v1beta',
        'model': 'gemini-pro-latest',
      },
      {
        'version': 'v1beta',
        'model': 'gemini-flash-latest',
      },
      {
        'version': 'v1beta',
        'model': 'gemini-2.0-flash',
      },
    ];

    Exception? lastError;

    for (final modelConfig in modelsToTry) {
      final version =
          modelConfig['version'] as String;
      final model =
          modelConfig['model'] as String;

      try {
        print('🌐 Trying $version/$model');
        final prompt = _buildPrompt(
          habits,
          recentLogs,
          overallCompletionRate,
        );

        final apiUrl =
            'https://generativelanguage.googleapis.com/$version/models/$model:generateContent?key=$_apiKey';

        print('📍 API URL: $apiUrl');

        final response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type':
                    'application/json',
              },
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                    ],
                  },
                ],
                'generationConfig': {
                  'temperature': 0.8,
                  'topK': 40,
                  'topP': 0.95,
                  'maxOutputTokens': 2048,
                },
              }),
            )
            .timeout(
              const Duration(seconds: 60),
            ); // زود الـ timeout من 30 لـ 60

        print(
          '📡 Response status: ${response.statusCode}',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['candidates'] != null &&
              data['candidates'].isNotEmpty &&
              data['candidates'][0]['content'] !=
                  null &&
              data['candidates'][0]['content']['parts'] !=
                  null &&
              data['candidates'][0]['content']['parts']
                  .isNotEmpty) {
            final content =
                data['candidates'][0]['content']['parts'][0]['text']
                    as String;

            print(
              '✅ Gemini API Success with $version/$model',
            );
            return _parseInsights(content);
          } else {
            print(
              '⚠️ Invalid response structure from $version/$model',
            );
            lastError = Exception(
              'بنية استجابة غير صالحة',
            );
            continue;
          }
        } else if (response.statusCode == 429) {
          // Quota exceeded - جرب الموديل التالي
          print(
            '⚠️ Quota exceeded for $version/$model, trying next model...',
          );
          lastError = Exception(
            'تم تجاوز حد الاستخدام',
          );
          continue;
        } else {
          print(
            '⚠️ $version/$model failed: ${response.statusCode}',
          );
          lastError = Exception(
            'فشل الاتصال بـ API: ${response.statusCode}',
          );
          continue;
        }
      } catch (e) {
        print(
          '⚠️ Error with $version/$model: $e',
        );

        // تفاصيل الخطأ للـ debugging
        if (e is http.ClientException) {
          print('❌ Network error: ${e.message}');
        } else if (e is TimeoutException) {
          print('❌ Request timeout');
        } else if (e is FormatException) {
          print('❌ Invalid response format');
        }

        lastError = Exception(
          'خطأ في $model: ${e.toString()}',
        );
        continue;
      }
    }

    // لو كل الموديلات فشلت - ارجع response افتراضي بدل exception
    print('❌ All models failed');
    print('📋 Last error: $lastError');

    // تحقق من نوع الخطأ وسجله
    final errorMessage =
        lastError?.toString() ?? '';
    if (errorMessage.contains(
          'SocketException',
        ) ||
        errorMessage.contains(
          'ClientException',
        )) {
      print(
        '🌐 Network error detected - no internet connection',
      );
    } else if (errorMessage.contains(
      'TimeoutException',
    )) {
      print(
        '⏱️ Timeout error - request took too long',
      );
    } else if (errorMessage.contains('429')) {
      print('🚫 API quota exceeded');
    } else if (errorMessage.contains('403') ||
        errorMessage.contains('401')) {
      print(
        '🔑 API key error - invalid or unauthorized',
      );
    }

    // ارجع fallback insights مفيدة
    print('✅ Returning fallback insights');
    return _getFallbackInsights(
      habits,
      overallCompletionRate,
    );
  }

  // Fallback insights بناءً على البيانات الفعلية
  AIInsights _getFallbackInsights(
    List<HabitModel> habits,
    double completionRate,
  ) {
    final activeStreaks = habits
        .where((h) => h.currentStreak > 0)
        .length;
    final bestStreak = habits.isEmpty
        ? 0
        : habits
              .map((h) => h.bestStreak)
              .reduce((a, b) => a > b ? a : b);

    // حلل الأداء
    String summary;
    List<String> strengths = [];
    List<String> improvements = [];

    if (completionRate >= 80) {
      summary =
          'أداء ممتاز! استمر على هذا المستوى الرائع 🌟';
      strengths.add('معدل إنجاز مرتفع جداً');
    } else if (completionRate >= 60) {
      summary =
          'تقدم جيد! مع بعض التحسينات ستصل للقمة 💪';
      strengths.add('أداء جيد ومستمر');
    } else if (completionRate >= 40) {
      summary =
          'بداية جيدة! ركز على الاستمرارية ⭐';
      improvements.add(
        'حاول رفع معدل الإنجاز تدريجياً',
      );
    } else {
      summary =
          'لا بأس! كل خطوة صغيرة تقربك من هدفك 🌱';
      improvements.add(
        'ابدأ بعادة واحدة فقط وأتقنها',
      );
    }

    if (activeStreaks > 0) {
      strengths.add(
        'لديك $activeStreaks عادة نشطة مستمرة',
      );
    }

    if (bestStreak >= 7) {
      strengths.add(
        'حققت سلسلة $bestStreak يوم - إنجاز رائع!',
      );
    }

    if (habits.length > 5) {
      improvements.add(
        'عدد العادات كثير - ركز على 3-5 عادات فقط',
      );
    }

    return AIInsights(
      summary: summary,
      strengths: strengths.isEmpty
          ? ['بدأت رحلتك نحو التغيير']
          : strengths,
      improvements: improvements.isEmpty
          ? ['استمر على نفس المستوى']
          : improvements,
      suggestions: [
        'اجعل العادات جزءاً من روتينك اليومي',
        'حدد وقتاً ثابتاً لكل عادة',
        'كافئ نفسك عند تحقيق الأهداف',
      ],
      motivation: _getMotivationalQuote(
        completionRate,
      ),
      recommendedHabits: _getSmartRecommendations(
        habits,
        completionRate,
      ),
    );
  }

  // Empty state insights
  AIInsights _getEmptyStateInsights() {
    return AIInsights(
      summary:
          'مرحباً بك! ابدأ بإضافة عادتك الأولى 🌱',
      strengths: [],
      improvements: [],
      suggestions: [
        'ابدأ بعادة واحدة سهلة وبسيطة',
        'اختر شيئاً تحب أن تفعله يومياً',
        'اجعل الهدف صغيراً في البداية',
      ],
      motivation:
          'كل رحلة عظيمة تبدأ بخطوة واحدة! 🚀',
      recommendedHabits: [
        RecommendedHabit(
          name: 'المشي 10 دقائق',
          reason: 'عادة بسيطة ومفيدة للصحة',
        ),
        RecommendedHabit(
          name: 'شرب 8 أكواب ماء',
          reason: 'ضروري للصحة وسهل التتبع',
        ),
        RecommendedHabit(
          name: 'قراءة 10 صفحات',
          reason: 'تطور معرفتك بشكل يومي',
        ),
      ],
    );
  }

  // اقتراحات ذكية بناءً على العادات الحالية
  List<RecommendedHabit> _getSmartRecommendations(
    List<HabitModel> habits,
    double completionRate,
  ) {
    final recommendations = <RecommendedHabit>[];

    // تحقق من الفئات الموجودة
    final hasHealth = habits.any(
      (h) => h.category == HabitCategory.health,
    );
    final hasProductivity = habits.any(
      (h) =>
          h.category ==
          HabitCategory.productivity,
    );
    final hasMindfulness = habits.any(
      (h) =>
          h.category == HabitCategory.mindfulness,
    );

    if (!hasHealth) {
      recommendations.add(
        RecommendedHabit(
          name: 'المشي 15 دقيقة',
          reason: 'لتحسين صحتك البدنية',
        ),
      );
    }

    if (!hasProductivity) {
      recommendations.add(
        RecommendedHabit(
          name: 'قراءة 10 صفحات',
          reason: 'لزيادة إنتاجيتك ومعرفتك',
        ),
      );
    }

    if (!hasMindfulness) {
      recommendations.add(
        RecommendedHabit(
          name: 'تأمل 5 دقائق',
          reason: 'لتحسين تركيزك وهدوءك',
        ),
      );
    }

    if (completionRate < 50) {
      recommendations.add(
        RecommendedHabit(
          name: 'تنظيم المهام',
          reason: 'لمساعدتك على الالتزام بعاداتك',
        ),
      );
    }

    return recommendations.take(3).toList();
  }

  // رسالة تحفيزية حسب الأداء
  String _getMotivationalQuote(
    double completionRate,
  ) {
    if (completionRate >= 80) {
      return 'أنت نجم! استمر في التألق 🌟';
    } else if (completionRate >= 60) {
      return 'تقدم رائع! أنت على الطريق الصحيح 💪';
    } else if (completionRate >= 40) {
      return 'كل يوم هو فرصة جديدة للتحسن 🌱';
    } else {
      return 'الرحلة تبدأ بخطوة واحدة - أنت تستطيع! 🚀';
    }
  }

  String _buildPrompt(
    List<HabitModel> habits,
    List<DailyLogModel> logs,
    double completionRate,
  ) {
    final totalHabits = habits.length;
    final activeStreaks = habits
        .where((h) => h.currentStreak > 0)
        .length;
    final bestStreak = habits.isEmpty
        ? 0
        : habits
              .map((h) => h.bestStreak)
              .reduce((a, b) => a > b ? a : b);

    // تحليل المشاكل في العادات الحالية
    final weakHabits = habits
        .where((h) => h.currentStreak == 0)
        .toList();
    final strugglingHabits = habits
        .where(
          (h) =>
              h.currentStreak < h.bestStreak / 2,
        )
        .toList();

    final habitsList = habits
        .map(
          (h) =>
              '- ${h.name}: السلسلة الحالية ${h.currentStreak} يوم، أفضل سلسلة ${h.bestStreak} يوم',
        )
        .join('\n');

    final problemsList = [
      if (weakHabits.isNotEmpty)
        'عادات متوقفة: ${weakHabits.map((h) => h.name).join(", ")}',
      if (strugglingHabits.isNotEmpty)
        'عادات تحتاج دعم: ${strugglingHabits.map((h) => h.name).join(", ")}',
      if (completionRate < 50)
        'معدل الإنجاز منخفض جداً',
      if (activeStreaks == 0)
        'لا توجد عادات نشطة حالياً',
    ].join('\n');

    final recentPerformance = logs
        .take(7)
        .map((l) {
          return 'يوم ${l.date}: ${(l.completedHabitIds.length / (l.totalHabits == 0 ? 1 : l.totalHabits) * 100).toStringAsFixed(0)}% إنجاز';
        })
        .join('\n');

    return '''
أنت مدرب عادات محترف ومتخصص في حل المشاكل وتطوير العادات. حلل المستخدم وقدم حلول عملية.

**بيانات المستخدم:**
- عدد العادات: $totalHabits
- معدل الإنجاز الإجمالي: ${completionRate.toStringAsFixed(0)}%
- العادات النشطة (سلاسل مستمرة): $activeStreaks من $totalHabits
- أفضل سلسلة: $bestStreak يوم

**العادات الحالية:**
$habitsList

**المشاكل المكتشفة:**
$problemsList

**الأداء الأخير (آخر 7 أيام):**
$recentPerformance

**المطلوب:**
1. حلل المشاكل في العادات الحالية بعمق
2. اقترح عادات جديدة تساعد في حل هذه المشاكل (3-5 عادات)
3. اجعل العادات المقترحة عملية ومناسبة للمستخدم

أرجع JSON صالح باللغة العربية:

{
  "summary": "ملخص الوضع الحالي في 60 حرف",
  "strengths": ["نقطة قوة 1", "نقطة قوة 2"],
  "improvements": ["مشكلة تحتاج حل 1", "مشكلة 2"],
  "suggestions": ["نصيحة عملية 1", "نصيحة 2", "نصيحة 3"],
  "motivation": "رسالة تحفيزية في 50 حرف",
  "recommendedHabits": [
    {
      "name": "اسم العادة المقترحة",
      "reason": "كيف ستحل مشكلة معينة من العادات الحالية (60 حرف)"
    }
  ]
}

**مهم جداً:**
- اقترح 3-5 عادات جديدة فقط
- كل عادة يجب أن تحل مشكلة محددة من العادات القديمة
- اجعل السبب واضح ومباشر (كيف ستساعد؟)
- أرجع JSON كامل ومغلق تماماً
- لا تضع أي نص قبل { أو بعد }
''';
  }

  AIInsights _parseInsights(String content) {
    try {
      // Clean the response from markdown if present
      String cleanContent = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // Try to extract JSON if there's text before/after
      final jsonStart = cleanContent.indexOf('{');
      final jsonEnd = cleanContent.lastIndexOf(
        '}',
      );

      if (jsonStart == -1 ||
          jsonEnd == -1 ||
          jsonEnd <= jsonStart) {
        throw Exception(
          'No valid JSON found in response',
        );
      }

      cleanContent = cleanContent.substring(
        jsonStart,
        jsonEnd + 1,
      );

      // Fix common JSON issues
      cleanContent = cleanContent
          .replaceAll('\n', ' ')
          .replaceAll('  ', ' ')
          .trim();

      final Map<String, dynamic> data =
          jsonDecode(cleanContent);

      // Validate required fields
      if (data['summary'] == null &&
          data['motivation'] == null) {
        throw Exception(
          'Invalid response structure',
        );
      }

      return AIInsights(
        summary:
            data['summary'] ??
            'جاري بناء عاداتك...',
        strengths: data['strengths'] != null
            ? List<String>.from(data['strengths'])
            : [],
        improvements: data['improvements'] != null
            ? List<String>.from(
                data['improvements'],
              )
            : [],
        suggestions: data['suggestions'] != null
            ? List<String>.from(
                data['suggestions'],
              )
            : ['استمر في المحاولة وكن صبوراً'],
        motivation:
            data['motivation'] ??
            'كل خطوة تقربك من هدفك! 🌟',
        recommendedHabits:
            data['suggestions'] != null
            ? (data['suggestions'] as List)
                  .map(
                    (h) => RecommendedHabit(
                      name: h is String
                          ? h
                          : h['name'] ?? '',
                      reason: h['reason'] ?? '',
                    ),
                  )
                  .toList()
            : [],
      );
    } catch (e) {
      print('Error parsing insights: $e');
      print('Content was: $content');
      throw Exception(
        'فشل تحليل البيانات من API: ${e.toString()}',
      );
    }
  }
}

class AIInsights {
  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> suggestions;
  final String motivation;
  final List<RecommendedHabit> recommendedHabits;

  AIInsights({
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.suggestions,
    required this.motivation,
    required this.recommendedHabits,
  });
}

class RecommendedHabit {
  final String name;
  final String reason;

  RecommendedHabit({
    required this.name,
    required this.reason,
  });
}

// Track AI interaction for learning
class AIInteractionTracker {
  static Future<void> trackInteraction({
    required String userId,
    required String suggestion,
    required Map<String, dynamic> features,
    bool executed = false,
    int feedback = 0,
  }) async {
    try {
      // 1. Save to Firestore
      await FirebaseFirestore.instance
          .collection('ai_interactions')
          .add({
            'userId': userId,
            'suggestion': suggestion,
            'features': Map<String, dynamic>.from(
              features,
            ),
            'executed': executed,
            'feedback': feedback,
            'timestamp':
                FieldValue.serverTimestamp(),
          });

      // 2. Track to Backend (Use DateTime.now() instead of FieldValue)
      await _trackToBackend(
        userId: userId,
        suggestion: suggestion,
        features: features,
        executed: executed,
        feedback: feedback,
      );
    } catch (e) {
      print('Error tracking interaction: $e');
    }
  }

  static Future<void> _trackToBackend({
    required String userId,
    required String suggestion,
    required Map<String, dynamic> features,
    bool executed = false,
    int feedback = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          'http://your-backend-url/track_interaction',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'suggestion': suggestion,
          'features': features,
          'executed': executed,
          'feedback': feedback,
          'context': {
            'time': DateTime.now()
                .toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['should_retrain'] == true) {
          print('🔄 AI ready for retraining!');
        }
      }
    } catch (e) {
      print('Backend tracking error: $e');
    }
  }
}
