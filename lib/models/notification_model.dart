import 'package:cloud_firestore/cloud_firestore.dart';

// Types of notifications shown in the in-app inbox
enum AppNotificationType { chat, follow, reminder, general }

// Data model for an in-app inbox notification stored in Firestore
class NotificationModel {
  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  static AppNotificationType _typeFromString(String? value) {
    return AppNotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppNotificationType.general,
    );
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: _typeFromString(data['type']),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: data['data'] != null
          ? Map<String, dynamic>.from(data['data'] as Map)
          : <String, dynamic>{},
      read: data['read'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
