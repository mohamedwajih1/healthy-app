import 'dart:async';
import '../models/habit_model.dart';
import '../models/daily_log_model.dart';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';

class HabitProvider with ChangeNotifier {
  String? currentUserId;
  final FirestoreService _firestoreService =
      FirestoreService();

  List<HabitModel> _habits = [];
  DailyLogModel? _todayLog;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _habitsSubscription;

  List<HabitModel> get habits => _habits;
  DailyLogModel? get todayLog => _todayLog;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalHabits => _habits.length;

  int get completedToday {
    if (_todayLog == null || _habits.isEmpty) {
      return 0;
    }

    // احسب فقط العادات الموجودة فعلياً (مش المحذوفة)
    final activeHabitIds = _habits
        .map((h) => h.id)
        .toSet();
    final completedActiveHabits = _todayLog!
        .completedHabitIds
        .where(
          (id) => activeHabitIds.contains(id),
        )
        .length;

    return completedActiveHabits;
  }

  double get todayCompletionRate {
    if (_habits.isEmpty) return 0.0;
    return (completedToday / totalHabits) * 100;
  }

  // Listen to habits stream
  bool isListening = false;
  void listenToHabits(String userId) async {
    // Reset data if switching to a different user
    if (currentUserId != userId) {
      _habits = [];
      currentUserId = userId;
      _todayLog = null;
      notifyListeners();
    }

    print('Listening for: $userId');

    // Cancel any existing subscription before starting new one
    _habitsSubscription?.cancel();
    _habitsSubscription = null;

    _isLoading = true;
    _error = null;

    try {
      final habits = await _firestoreService
          .getUserHabitsOnce(userId);

      _habits = habits;
      await _loadTodayLog(userId);

      _isLoading = false;
      notifyListeners();

      _habitsSubscription = _firestoreService
          .getUserHabitsStream(userId)
          .listen((habits) async {
            print(
              'Stream update: ${habits.length}',
            );
            _habits = habits;
            await _loadTodayLog(userId);
            notifyListeners();
          });
    } catch (e) {
      print('❌ Error: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Load today's log
  Future<void> _loadTodayLog(
    String userId,
  ) async {
    try {
      _todayLog = await _firestoreService
          .getTodayLog(userId, _habits);

      // STEP 4: VERIFY FETCH
      final logs = [
        _todayLog,
      ].where((log) => log != null).toList();
      print("FETCHED LOG: $logs");

      notifyListeners();
    } catch (e) {
      print('Error loading today log: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  // Add new habit
  Future<bool> addHabit(HabitModel habit) async {
    try {
      _isLoading = true;
      _error = null;

      print('📝 Adding habit: ${habit.name}');
      print('👤 User ID: ${habit.userId}');

      final habitId = await _firestoreService
          .addHabit(habit);

      print('✅ Habit added with ID: $habitId');

      // مش محتاجين reload - الـ stream هيتحدث تلقائياً

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error in addHabit: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update habit
  Future<bool> updateHabit(
    String habitId,
    Map<String, dynamic> updates,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestoreService.updateHabit(
        habitId,
        updates,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete habit - محسّن
  Future<bool> deleteHabit(String habitId) async {
    try {
      print('🗑️ Deleting habit: $habitId');

      // حذف من الـ local list فوراً للـ UI
      _habits.removeWhere((h) => h.id == habitId);

      // تحديث الـ UI فوراً
      notifyListeners();

      // حذف نهائياً من Firestore
      await _firestoreService.hardDeleteHabit(
        habitId,
      );

      print('✅ Habit deleted successfully');

      return true;
    } catch (e) {
      print('❌ Error deleting habit: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clean all deleted habits - جديدة
  Future<void> cleanupDeletedHabits(
    String userId,
  ) async {
    try {
      print('🧹 Cleaning up deleted habits...');
      await _firestoreService
          .cleanupDeletedHabits(userId);
      print('✅ Cleanup completed');
    } catch (e) {
      print('❌ Error during cleanup: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  // Debug: Get all habits info
  Future<void> debugPrintAllHabits(
    String userId,
  ) async {
    try {
      final allHabits = await _firestoreService
          .getAllHabitsForDebugging(userId);
      print(
        '📊 Total habits in Firestore: ${allHabits.length}',
      );
      for (var habit in allHabits) {
        print(
          '  - ${habit['name']} (Active: ${habit['isActive']}) - ID: ${habit['docId']}',
        );
      }
    } catch (e) {
      print('❌ Error debugging: $e');
    }
  }

  // Toggle habit completion
  Future<void> toggleHabitCompletion(
    String userId,
    HabitModel habit,
  ) async {
    try {
      // STEP 2: VERIFY USER ACTION - IMMEDIATE PRINT
      print("USER CLICKED HABIT");

      bool isCurrentlyCompleted =
          _todayLog?.isHabitCompleted(habit.id) ??
          false;
      bool newCompletionState =
          !isCurrentlyCompleted;

      // Update daily log first
      await _firestoreService
          .toggleHabitCompletion(
            userId,
            habit.id,
            newCompletionState,
            _habits.length,
          );

      // If completing the habit, update streak
      if (newCompletionState) {
        await _firestoreService.completeHabit(
          habit.id,
          habit,
        );
      }

      // Reload today's log
      await _loadTodayLog(userId);

      // STEP 2: AFTER UPDATE - PRINT UPDATED LIST
      final updatedList =
          _todayLog?.completedHabitIds ?? [];
      print(
        "UPDATED completedHabitIds: $updatedList",
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Check if habit is completed today
  bool isHabitCompletedToday(String habitId) {
    return _todayLog?.isHabitCompleted(habitId) ??
        false;
  }

  // Get habits by category
  List<HabitModel> getHabitsByCategory(
    HabitCategory category,
  ) {
    return _habits
        .where((h) => h.category == category)
        .toList();
  }

  // Get active streaks count
  int getActiveStreaksCount() {
    return _habits
        .where((h) => h.currentStreak > 0)
        .length;
  }

  // Get best performing habit
  HabitModel? getBestPerformingHabit() {
    if (_habits.isEmpty) return null;

    var sorted = List<HabitModel>.from(_habits)
      ..sort(
        (a, b) =>
            b.bestStreak.compareTo(a.bestStreak),
      );

    return sorted.first;
  }

  // إعادة تحميل كل البيانات - جديدة
  Future<void> refreshAllData(
    String userId,
  ) async {
    try {
      print('🔄 Refreshing all data...');
      _isLoading = true;
      notifyListeners();

      isListening = false; // ✅ أهم سطر
      listenToHabits(userId);

      _isLoading = false;
      notifyListeners();
      print('✅ Data refreshed successfully');
    } catch (e) {
      print('❌ Error refreshing data: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearHabits() {
    _habits = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    _habitsSubscription?.cancel();
    super.dispose();
  }
}
