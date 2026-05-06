import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🔥 Reinforcement Learning Service
/// Handles RL-based suggestions and feedback loop
class RLService {
  static final RLService _instance =
      RLService._internal();
  factory RLService() => _instance;
  RLService._internal();

  /// Base URL for AI backend
  String get baseUrl {
    const String replitUrl =
        'https://healthy-ai-backend--mohamedsaadytr.replit.app';
    if (Platform.isAndroid) {
      return replitUrl;
    }
    return replitUrl;
  }

  /// ═══════════════════════════════════════════════════════════════
  /// 1. GET RL-BASED SUGGESTION
  /// ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getRLSuggestion({
    required double completionRate,
    required double consistency,
    required double dropRate,
    required double activeStreaks,
    required double bestStreak,
    required double totalHabits,
    required List<String> habitNames,
    double previousCompletion = 0.0,
    double trend7d = 0.0,
    double trend30d = 0.0,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/smart_suggest_rl',
      );

      final requestBody = {
        'completion_rate': completionRate,
        'consistency': consistency,
        'drop_rate': dropRate,
        'activeStreaks': activeStreaks,
        'bestStreak': bestStreak,
        'totalHabits': totalHabits,
        'habit_names': habitNames,
        'previous_completion': previousCompletion,
        'trend_7d': trend7d,
        'trend_30d': trend30d,
      };

      print(
        '🤖 RL Suggestion Request: $requestBody',
      );

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
          '✅ RL Suggestion: ${data['suggestion_text']}',
        );
        print(
          '   Q-Values: ${data['top_q_values']}',
        );
        print('   Epsilon: ${data['epsilon']}');
        return data;
      } else {
        print(
          '❌ RL Suggestion Error: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to get RL suggestion: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ RL Suggestion Exception: $e');
      // Fallback to rule-based suggestion
      return _fallbackSuggestion();
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// 2. SEND FEEDBACK (Crucial for RL Training!)
  /// ═══════════════════════════════════════════════════════════════
  Future<bool> sendFeedback({
    required String suggestionId,
    required String
    interaction, // 'completed', 'opened', 'ignored', 'deleted', 'snoozed'
    required Map<String, dynamic> stateBefore,
    required Map<String, dynamic> stateAfter,
  }) async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;
      if (user == null) {
        print(
          '⚠️ No user logged in - cannot send feedback',
        );
        return false;
      }

      final url = Uri.parse('$baseUrl/feedback');

      final requestBody = {
        'userId': user.uid,
        'suggestionId': suggestionId,
        'interaction': interaction,
        'stateBefore': stateBefore,
        'stateAfter': stateAfter,
        'timestamp': DateTime.now()
            .toIso8601String(),
      };

      print(
        '📤 Sending RL Feedback: $interaction for $suggestionId',
      );
      print(
        '   Reward: ${_getRewardValue(interaction)}',
      );

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Feedback Sent Successfully');
        print(
          '   Training Triggered: ${data['training_triggered']}',
        );
        print(
          '   Buffer Size: ${data['buffer_size']}',
        );
        print('   Epsilon: ${data['epsilon']}');

        // Store in Firestore for persistence
        await _storeFeedbackInFirestore(
          requestBody,
          data,
        );

        return true;
      } else {
        print(
          '❌ Feedback Error: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('❌ Feedback Exception: $e');
      return false;
    }
  }

  /// Store feedback in Firestore for record keeping
  Future<void> _storeFeedbackInFirestore(
    Map<String, dynamic> feedback,
    Map<String, dynamic> response,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('rl_feedback')
          .add({
            'userId': feedback['userId'],
            'suggestionId':
                feedback['suggestionId'],
            'interaction':
                feedback['interaction'],
            'reward': response['reward'],
            'trainingTriggered':
                response['training_triggered'],
            'bufferSize': response['buffer_size'],
            'epsilon': response['epsilon'],
            'timestamp':
                FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print(
        '⚠️ Failed to store feedback in Firestore: $e',
      );
    }
  }

  /// Get reward value for logging
  double _getRewardValue(String interaction) {
    final rewards = {
      'completed': 1.0,
      'opened': 0.3,
      'app_opened': 0.1,
      'ignored': -0.2,
      'deleted': -0.5,
      'snoozed': -0.1,
    };
    return rewards[interaction] ?? 0.0;
  }

  /// ═══════════════════════════════════════════════════════════════
  /// 3. GET RL ENGINE STATISTICS
  /// ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>>
  getRLStats() async {
    try {
      final url = Uri.parse('$baseUrl/rl_stats');

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to get RL stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ RL Stats Exception: $e');
      return {};
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// 4. MANUAL TRAINING TRIGGER
  /// ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> triggerTraining({
    int steps = 50,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/rl_train');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'steps': steps}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Manual Training Completed');
        print(
          '   Steps: ${data['steps_trained']}',
        );
        print('   Loss: ${data['average_loss']}');
        print(
          '   Epsilon: ${data['final_epsilon']}',
        );
        return data;
      } else {
        throw Exception(
          'Training failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Training Exception: $e');
      return {};
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// 5. GET Q-VALUES FOR DEBUGGING
  /// ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getQValues({
    required Map<String, dynamic> features,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/rl_qvalues',
      );

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(features),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to get Q-values: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Q-Values Exception: $e');
      return {};
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// FALLBACK SUGGESTION (if RL fails)
  /// ═══════════════════════════════════════════════════════════════
  Map<String, dynamic> _fallbackSuggestion() {
    final suggestions = [
      {
        'id': 'drink_water',
        'text': '[ماء] اشرب كوب ماء الآن',
      },
      {
        'id': 'exercise',
        'text':
            '[رياضة] مارس رياضة خفيفة 10 دقائق',
      },
      {
        'id': 'meditate',
        'text': '[تأمل] جرب 5 دقائق تنفس عميق',
      },
    ];

    final randomSuggestion =
        suggestions[DateTime.now().millisecond %
            3];

    return {
      'suggestion_id': randomSuggestion['id'],
      'suggestion_text': randomSuggestion['text'],
      'confidence': 0.5,
      'exploration': false,
      'method': 'fallback_random',
      'top_q_values': [],
      'epsilon': 1.0,
      'engine_stats': {},
    };
  }

  /// ═══════════════════════════════════════════════════════════════
  /// HELPER: Build State Map from Features
  /// ═══════════════════════════════════════════════════════════════
  Map<String, dynamic> buildState({
    required double completionRate,
    required double consistency,
    required double dropRate,
    required double activeStreaks,
    required double bestStreak,
    required double totalHabits,
    double previousCompletion = 0.0,
    double trend7d = 0.0,
    double trend30d = 0.0,
  }) {
    return {
      'completion_rate': completionRate,
      'consistency': consistency,
      'drop_rate': dropRate,
      'active_streaks': activeStreaks,
      'best_streak': bestStreak,
      'total_habits': totalHabits,
      'previous_completion': previousCompletion,
      'trend_7d': trend7d,
      'trend_30d': trend30d,
    };
  }
}

/// Extension for easy feedback tracking
extension RLFeedbackExtension on RLService {
  /// Quick feedback for when user completes a suggestion
  Future<bool> trackCompletion({
    required String suggestionId,
    required Map<String, dynamic> stateBefore,
    required Map<String, dynamic> stateAfter,
  }) async {
    return sendFeedback(
      suggestionId: suggestionId,
      interaction: 'completed',
      stateBefore: stateBefore,
      stateAfter: stateAfter,
    );
  }

  /// Quick feedback for when user ignores a suggestion
  Future<bool> trackIgnore({
    required String suggestionId,
    required Map<String, dynamic> stateBefore,
    required Map<String, dynamic> stateAfter,
  }) async {
    return sendFeedback(
      suggestionId: suggestionId,
      interaction: 'ignored',
      stateBefore: stateBefore,
      stateAfter: stateAfter,
    );
  }
}
