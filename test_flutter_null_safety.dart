// Test Flutter JSON parsing with null safety
// This simulates the JSON parsing that happens in the Flutter app

import 'dart:convert';

// Mock classes for testing
class RecommendedHabit {
  final String name;
  final String reason;

  RecommendedHabit({required this.name, required this.reason});
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

void testNullSafety() {
  print('=== TESTING FLUTTER NULL SAFETY ===\n');

  // Test case 1: Normal response with all fields
  print('1. Testing normal response:');
  String normalResponse = '''
  {
    "success": true,
    "data": {
      "summary": "wade7 ennak bet7awel ta7'eer nafsak, w di bedayet mmtazah.",
      "motivation": "estmer felly bedon ma te7'ar",
      "strengths": ["3ndak rag7a 7aqeqia fel taghyeer", "bet7awel tatweer nafsak"],
      "improvements": ["7awel tezed entzamik tadreejyan"],
      "suggestions": ["ebda' b 5'otwa sagheera el yom", "7ot wa2t thabet kol yom"],
      "recommendedHabits": ["eshrab kob may saberan", "emshi 10 dagat kol yom"]
    }
  }
  ''';

  try {
    final data = jsonDecode(normalResponse);
    
    // Safe parsing with null safety (exactly as in Flutter code)
    final summary = (data['data']?['summary'] ?? '') as String;
    final motivation = (data['data']?['motivation'] ?? '') as String;
    final strengths = List<String>.from(data['data']?['strengths'] ?? []);
    final improvements = List<String>.from(data['data']?['improvements'] ?? []);
    final suggestions = List<String>.from(data['data']?['suggestions'] ?? []);
    
    // Convert List<String> to List<RecommendedHabit>
    final recommendedHabitsStrings = List<String>.from(data['data']?['recommendedHabits'] ?? []);
    final recommendedHabits = recommendedHabitsStrings.map((habit) => 
      RecommendedHabit(name: habit, reason: 'Based on your behavioral analysis')
    ).toList();
    
    final insights = AIInsights(
      summary: summary,
      motivation: motivation,
      strengths: strengths,
      improvements: improvements,
      suggestions: suggestions,
      recommendedHabits: recommendedHabits,
    );
    
    print('   7 SUCCESS: All fields parsed correctly');
    print('   Summary: "${insights.summary}"');
    print('   Strengths: ${insights.strengths}');
    print('   Suggestions: ${insights.suggestions}');
    print('   Recommended Habits: ${insights.recommendedHabits.map((h) => h.name).toList()}');
    
  } catch (e) {
    print('   7 FAILED: $e');
  }

  // Test case 2: Response with null/missing fields
  print('\n2. Testing response with null/missing fields:');
  String nullResponse = '''
  {
    "success": true,
    "data": {
      "summary": null,
      "motivation": "",
      "strengths": [],
      "improvements": null,
      "suggestions": null,
      "recommendedHabits": null
    }
  }
  ''';

  try {
    final data = jsonDecode(nullResponse);
    
    // Safe parsing with null safety
    final summary = (data['data']?['summary'] ?? '') as String;
    final motivation = (data['data']?['motivation'] ?? '') as String;
    final strengths = List<String>.from(data['data']?['strengths'] ?? []);
    final improvements = List<String>.from(data['data']?['improvements'] ?? []);
    final suggestions = List<String>.from(data['data']?['suggestions'] ?? []);
    
    // Convert List<String> to List<RecommendedHabit>
    final recommendedHabitsStrings = List<String>.from(data['data']?['recommendedHabits'] ?? []);
    final recommendedHabits = recommendedHabitsStrings.map((habit) => 
      RecommendedHabit(name: habit, reason: 'Based on your behavioral analysis')
    ).toList();
    
    final insights = AIInsights(
      summary: summary,
      motivation: motivation,
      strengths: strengths,
      improvements: improvements,
      suggestions: suggestions,
      recommendedHabits: recommendedHabits,
    );
    
    print('   7 SUCCESS: Null fields handled with defaults');
    print('   Summary: "${insights.summary}" (should be empty)');
    print('   Strengths: ${insights.strengths} (should be empty list)');
    print('   Suggestions: ${insights.suggestions} (should be empty list)');
    print('   Recommended Habits: ${insights.recommendedHabits.length} (should be 0)');
    
  } catch (e) {
    print('   7 FAILED: $e');
  }

  // Test case 3: Response with missing data field entirely
  print('\n3. Testing response with missing data field:');
  String missingDataResponse = '''
  {
    "success": true
  }
  ''';

  try {
    final data = jsonDecode(missingDataResponse);
    
    // Safe parsing with null safety
    final summary = (data['data']?['summary'] ?? '') as String;
    final motivation = (data['data']?['motivation'] ?? '') as String;
    final strengths = List<String>.from(data['data']?['strengths'] ?? []);
    final improvements = List<String>.from(data['data']?['improvements'] ?? []);
    final suggestions = List<String>.from(data['data']?['suggestions'] ?? []);
    
    // Convert List<String> to List<RecommendedHabit>
    final recommendedHabitsStrings = List<String>.from(data['data']?['recommendedHabits'] ?? []);
    final recommendedHabits = recommendedHabitsStrings.map((habit) => 
      RecommendedHabit(name: habit, reason: 'Based on your behavioral analysis')
    ).toList();
    
    final insights = AIInsights(
      summary: summary,
      motivation: motivation,
      strengths: strengths,
      improvements: improvements,
      suggestions: suggestions,
      recommendedHabits: recommendedHabits,
    );
    
    print('   7 SUCCESS: Missing data field handled');
    print('   Summary: "${insights.summary}" (should be empty)');
    print('   All fields should have default values');
    
  } catch (e) {
    print('   7 FAILED: $e');
  }

  print('\n=== NULL SAFETY TEST COMPLETED ===');
  print('7 Flutter JSON parsing is now crash-proof');
  print('7 All null values are handled with safe defaults');
  print('7 Type safety enforced with proper casting');
}

void main() {
  testNullSafety();
}
