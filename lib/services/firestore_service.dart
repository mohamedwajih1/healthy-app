import 'package:intl/intl.dart';
import '../models/habit_model.dart';
import '../models/daily_log_model.dart';
import '../models/weekly_stats_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============== HABITS ==============

  Future<List<HabitModel>> getUserHabitsOnce(
    String userId,
  ) async {
    final snapshot = await FirebaseFirestore
        .instance
        .collection('habits')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map(
          (doc) => HabitModel.fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  // Add new habit
  Future<String> addHabit(
    HabitModel habit,
  ) async {
    try {
      print(
        '📝 Adding habit: ${habit.name} for user: ${habit.userId}',
      );

      // Create a copy with the ID field empty (Firestore will generate it)
      final habitMap = habit.toMap();
      habitMap.remove(
        'id',
      ); // Remove the empty ID

      // أضف timestamp للإنشاء
      habitMap['createdAt'] =
          FieldValue.serverTimestamp();

      print('📤 Habit data: $habitMap');

      DocumentReference doc = await _firestore
          .collection('habits')
          .add(habitMap);

      print('✅ Habit added with ID: ${doc.id}');

      // Update the document with its own ID
      await doc.update({'id': doc.id});

      print('✅ Habit ID updated in document');

      return doc.id;
    } catch (e) {
      print('❌ Error adding habit: $e');
      throw 'فشل إضافة العادة: $e';
    }
  }

  // Get user habits stream - محسّن
  Stream<List<HabitModel>> getUserHabitsStream(
    String userId,
  ) {
    print(
      '🔍 Querying habits for userId: $userId',
    );

    return _firestore
        .collection('habits')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          print(
            '📦 Received ${snapshot.docs.length} habit documents',
          );

          // طباعة تفاصيل كل عادة للـ debugging
          for (var doc in snapshot.docs) {
            final data = doc.data();
            print(
              '📄 Habit: ${data['name']} - ID: ${doc.id} - Active: ${data['isActive']}',
            );
          }

          final habits = snapshot.docs
              .map((doc) {
                try {
                  return HabitModel.fromFirestore(
                    doc,
                  );
                } catch (e) {
                  print(
                    '❌ Error parsing habit ${doc.id}: $e',
                  );
                  return null;
                }
              })
              .whereType<HabitModel>()
              .toList();

          print(
            '✅ Successfully parsed ${habits.length} habits',
          );
          return habits;
        });
  }

  // Get single habit
  Future<HabitModel?> getHabit(
    String habitId,
  ) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('habits')
          .doc(habitId)
          .get();

      if (!doc.exists) return null;
      return HabitModel.fromFirestore(doc);
    } catch (e) {
      throw 'فشل جلب العادة: $e';
    }
  }

  // Update habit
  Future<void> updateHabit(
    String habitId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] =
          FieldValue.serverTimestamp();
      await _firestore
          .collection('habits')
          .doc(habitId)
          .update(updates);
    } catch (e) {
      throw 'فشل تحديث العادة: $e';
    }
  }

  // Delete habit (soft delete) - محسّن
  Future<void> deleteHabit(String habitId) async {
    try {
      print('🗑️ Deleting habit: $habitId');

      await _firestore
          .collection('habits')
          .doc(habitId)
          .update({
            'isActive': false,
            'deletedAt':
                FieldValue.serverTimestamp(),
          });

      print(
        '✅ Habit marked as deleted in Firestore',
      );
    } catch (e) {
      print('❌ Error deleting habit: $e');
      throw 'فشل حذف العادة: $e';
    }
  }

  // Clean up deleted habits - جديدة
  Future<void> cleanupDeletedHabits(
    String userId,
  ) async {
    try {
      print(
        '🧹 Cleaning up deleted habits for user: $userId',
      );

      // احصل على كل العادات المحذوفة
      QuerySnapshot snapshot = await _firestore
          .collection('habits')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: false)
          .get();

      print(
        '🗑️ Found ${snapshot.docs.length} deleted habits',
      );

      // احذفها نهائياً
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
        print(
          '✅ Permanently deleted habit: ${doc.id}',
        );
      }

      print('🎉 Cleanup completed!');
    } catch (e) {
      print('❌ Error cleaning up: $e');
      throw 'فشل التنظيف: $e';
    }
  }

  // Get all habits (including deleted) - للـ debugging
  Future<List<Map<String, dynamic>>>
  getAllHabitsForDebugging(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('habits')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) {
        final data =
            doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting all habits: $e');
      return [];
    }
  }

  // Hard delete habit - للحذف النهائي
  Future<void> hardDeleteHabit(
    String habitId,
  ) async {
    try {
      print('🗑️ Hard deleting habit: $habitId');
      await _firestore
          .collection('habits')
          .doc(habitId)
          .delete();
      print(
        '✅ Habit permanently deleted from Firestore',
      );
    } catch (e) {
      print('❌ Error hard deleting habit: $e');
      throw 'فشل حذف العادة نهائياً: $e';
    }
  }

  // Complete habit (update streak and lastCompleted)
  Future<void> completeHabit(
    String habitId,
    HabitModel habit,
  ) async {
    try {
      DateTime now = DateTime.now();
      DateTime today = DateTime(
        now.year,
        now.month,
        now.day,
      );
      DateTime? lastCompleted =
          habit.lastCompleted;

      int newStreak = habit.currentStreak;

      // Check if completed yesterday (consecutive)
      if (lastCompleted != null) {
        DateTime lastDate = DateTime(
          lastCompleted.year,
          lastCompleted.month,
          lastCompleted.day,
        );

        Duration diff = today.difference(
          lastDate,
        );

        if (diff.inDays == 1) {
          // Consecutive day
          newStreak = habit.currentStreak + 1;
        } else if (diff.inDays > 1) {
          // Streak broken
          newStreak = 1;
        } else {
          // Same day - don't change streak
          newStreak = habit.currentStreak;
        }
      } else {
        // First completion
        newStreak = 1;
      }

      int newBestStreak =
          newStreak > habit.bestStreak
          ? newStreak
          : habit.bestStreak;

      await _firestore
          .collection('habits')
          .doc(habitId)
          .update({
            'lastCompleted': Timestamp.fromDate(
              now,
            ),
            'currentStreak': newStreak,
            'bestStreak': newBestStreak,
            'updatedAt':
                FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw 'فشل تسجيل العادة: $e';
    }
  }

  // ============== DAILY LOGS ==============

  // Get or create today's log
  Future<DailyLogModel> getTodayLog(
    String userId,
    List<HabitModel> habits,
  ) async {
    try {
      DateTime now = DateTime.now();
      String dateKey = DateFormat(
        'yyyy-MM-dd',
      ).format(now);

      DocumentSnapshot doc = await _firestore
          .collection('dailyLogs')
          .doc('${userId}_$dateKey')
          .get();

      if (doc.exists) {
        return DailyLogModel.fromFirestore(doc);
      } else {
        // Create new log
        DailyLogModel newLog = DailyLogModel(
          id: '${userId}_$dateKey',
          userId: userId,
          date: now,
          completedHabitIds: [],
          totalHabits: habits.length,
        );

        await _firestore
            .collection('dailyLogs')
            .doc(newLog.id)
            .set(newLog.toMap());

        return newLog;
      }
    } catch (e) {
      throw 'فشل جلب سجل اليوم: $e';
    }
  }

  // Update today's log - جديدة
  Future<void> updateTodayLog(
    String userId,
    List<String> completedHabitIds,
    int totalHabits,
  ) async {
    try {
      DateTime now = DateTime.now();
      String dateKey = DateFormat(
        'yyyy-MM-dd',
      ).format(now);
      String docId = '${userId}_$dateKey';

      double completionRate = totalHabits > 0
          ? (completedHabitIds.length /
                    totalHabits) *
                100
          : 0.0;

      await _firestore
          .collection('dailyLogs')
          .doc(docId)
          .set({
            'id': docId,
            'userId': userId,
            'date': Timestamp.fromDate(now),
            'completedHabitIds':
                completedHabitIds,
            'totalHabits': totalHabits,
            'completionRate': completionRate,
          }, SetOptions(merge: true));

      print(
        '✅ Today log updated: $completedHabitIds',
      );
    } catch (e) {
      print('❌ Error updating today log: $e');
      throw 'فشل تحديث السجل: $e';
    }
  }

  // Toggle habit completion in daily log
  Future<void> toggleHabitCompletion(
    String userId,
    String habitId,
    bool isCompleted,
    int totalHabits,
  ) async {
    try {
      DateTime now = DateTime.now();
      String dateKey = DateFormat(
        'yyyy-MM-dd',
      ).format(now);
      String docId = '${userId}_$dateKey';

      DocumentSnapshot doc = await _firestore
          .collection('dailyLogs')
          .doc(docId)
          .get();

      List<String> completedIds = [];

      if (doc.exists) {
        Map<String, dynamic> data =
            doc.data() as Map<String, dynamic>;
        completedIds = List<String>.from(
          data['completedHabitIds'] ?? [],
        );
      }

      if (isCompleted) {
        if (!completedIds.contains(habitId)) {
          completedIds.add(habitId);
        }
      } else {
        completedIds.remove(habitId);
      }

      double completionRate = totalHabits > 0
          ? (completedIds.length / totalHabits) *
                100
          : 0.0;

      await _firestore
          .collection('dailyLogs')
          .doc(docId)
          .set({
            'id': docId,
            'userId': userId,
            'date': Timestamp.fromDate(now),
            'completedHabitIds': completedIds,
            'totalHabits': totalHabits,
            'completionRate': completionRate,
          }, SetOptions(merge: true));

      // STEP 3: VERIFY FIRESTORE WRITE
      print("SAVED TO FIRESTORE: $completedIds");
    } catch (e) {
      throw 'فشل تحديث السجل: $e';
    }
  }

  // Get logs for date range
  Future<List<DailyLogModel>> getLogsInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('dailyLogs')
          .where('userId', isEqualTo: userId)
          .where(
            'date',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(start),
          )
          .where(
            'date',
            isLessThanOrEqualTo:
                Timestamp.fromDate(end),
          )
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                DailyLogModel.fromFirestore(doc),
          )
          .toList();
    } catch (e) {
      throw 'فشل جلب السجلات: $e';
    }
  }

  // ============== WEEKLY STATS ==============

  // Save weekly stats
  Future<void> saveWeeklyStats(
    WeeklyStatsModel stats,
  ) async {
    try {
      await _firestore
          .collection('weeklyStats')
          .doc(stats.id)
          .set(stats.toMap());
    } catch (e) {
      throw 'فشل حفظ الإحصائيات: $e';
    }
  }

  // Get weekly stats
  Future<WeeklyStatsModel?> getWeeklyStats(
    String userId,
    int weekNumber,
    int year,
  ) async {
    try {
      String docId =
          '${userId}_${year}_$weekNumber';
      DocumentSnapshot doc = await _firestore
          .collection('weeklyStats')
          .doc(docId)
          .get();

      if (!doc.exists) return null;
      return WeeklyStatsModel.fromFirestore(doc);
    } catch (e) {
      throw 'فشل جلب الإحصائيات: $e';
    }
  }

  // Get all weekly stats for user
  Stream<List<WeeklyStatsModel>>
  getUserWeeklyStatsStream(String userId) {
    return _firestore
        .collection('weeklyStats')
        .where('userId', isEqualTo: userId)
        .orderBy('weekStart', descending: true)
        .limit(12) // آخر 12 أسبوع
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    WeeklyStatsModel.fromFirestore(
                      doc,
                    ),
              )
              .toList(),
        );
  }
}
