import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? nutritionistId;
  final String uid;
  final String email;
  final String name;
  final DateTime createdAt;
  final String role;
  final bool isBanned; // 🔥 الجديد
  final Map<String, dynamic>? preferences;

  UserModel({
    this.nutritionistId,
    required this.uid,
    required this.email,
    required this.name,
    required this.createdAt,
    required this.role,
    required this.isBanned, // 🔥 الجديد
    this.preferences,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'role': role,
      'isBanned': isBanned, // 🔥 مهم
      'preferences': preferences ?? {},
      'nutritionistId': nutritionistId,
    };
  }

  // Create from Firestore Document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      role: data['role'] ?? 'user',
      isBanned: data['isBanned'] ?? false, // 🔥 أهم سطر
      preferences: data['preferences'],
      nutritionistId: data['nutritionistId'],
    );
  }

  // Create from Map
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      role: map['role'] ?? 'user',
      isBanned: map['isBanned'] ?? false, // 🔥
      preferences: map['preferences'],
      nutritionistId: map['nutritionistId'],
    );
  }

  // CopyWith method
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    DateTime? createdAt,
    String? role,
    bool? isBanned, // 🔥
    Map<String, dynamic>? preferences,
    String? nutritionistId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned, // 🔥
      preferences: preferences ?? this.preferences,
      nutritionistId: nutritionistId ?? this.nutritionistId,
    );
  }
}
