import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

// Manages the in-app notification inbox stored in the `notifications` collection.
// This is separate from NotificationService (local/scheduled) and FCMService (push).
class NotificationsInboxService {
  static final NotificationsInboxService _instance =
      NotificationsInboxService._internal();
  factory NotificationsInboxService() => _instance;
  NotificationsInboxService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('notifications');

  // Stream of all inbox notifications for a user, newest first
  Stream<List<NotificationModel>> streamForUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Stream of the unread notification count for a user (for the bell badge)
  Stream<int> unreadCount(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Add a new inbox notification (used by the app for local reminders)
  Future<void> add({
    required String userId,
    required AppNotificationType type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    await _collection.add({
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _collection.doc(notificationId).update({'read': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _collection
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String notificationId) async {
    await _collection.doc(notificationId).delete();
  }

  Future<void> clearAll(String userId) async {
    final all = await _collection
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in all.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
