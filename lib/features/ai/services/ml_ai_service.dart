import 'dart:convert';
import '../models/habit_features.dart';
import 'package:http/http.dart' as http;

class MLAIService {
  final String baseUrl = "http://10.0.2.2:5000";
  Future<Map<String, dynamic>> getInsights(
    HabitFeatures features,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/analyze"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(features.toJson()),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(
          data['error'] ?? 'AI Server Error',
        );
      }
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ?? 'AI Server Error',
      );
    }
  }
}
