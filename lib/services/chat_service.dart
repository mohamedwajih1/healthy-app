import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ================= إنشاء أو جلب محادثة =================
  Future<String?> getOrCreateConversation(
    String user1Id,
    String user2Id,
  ) async {
    if (user2Id.isEmpty || user2Id.contains("PUT_") || user2Id.length < 10) {
      print("❌ Invalid userId: $user2Id");
      return null;
    }

    final query = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: user1Id)
        .get();

    for (var doc in query.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(user2Id)) {
        return doc.id;
      }
    }

    final doc = await _firestore.collection('conversations').add({
      'participants': [user1Id, user2Id],
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // ================= 🔥 Block User =================
  Future<void> blockUser({
    required String myId,
    required String otherId,
  }) async {
    await _firestore.collection('users').doc(myId).set({
      'blockedUsers': FieldValue.arrayUnion([otherId]),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser({
    required String myId,
    required String otherId,
  }) async {
    await _firestore.collection('users').doc(myId).set({
      'blockedUsers': FieldValue.arrayRemove([otherId]),
    }, SetOptions(merge: true));
  }

  // ================= إرسال رسالة نص =================
 Future<void> sendMessage({
    required String id,
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final convoRef = _firestore.collection('conversations').doc(conversationId);

    final convo = await convoRef.get();
    final data = convo.data();

    final participants = List<String>.from(data?['participants'] ?? []);

    final otherId = participants.firstWhere((id) => id != senderId);

    final myDoc = await _firestore.collection('users').doc(senderId).get();

    final myBlocked = List<String>.from(myDoc.data()?['blockedUsers'] ?? []);

    final otherDoc = await _firestore.collection('users').doc(otherId).get();

    final otherBlocked = List<String>.from(
      otherDoc.data()?['blockedUsers'] ?? [],
    );

    if (myBlocked.contains(otherId) || otherBlocked.contains(senderId)) {
      print("🚫 Block active - message not sent");
      return;
    }

    final messageRef = _firestore.collection('messages').doc(id);

    await messageRef.set({
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sending',
    });

    try {
      await messageRef.update({'status': 'sent'});

      for (var userId in participants) {
        if (userId != senderId) {
          await convoRef.set({
            'unread': {userId: FieldValue.increment(1)},
          }, SetOptions(merge: true));
        }
      }

      await convoRef.update({
        'lastMessage': text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await messageRef.update({'status': 'failed'});
    }
  }
  // ================= إرسال صورة =================
  Future<void> sendImage({
    required String conversationId,
    required String senderId,
    required File imageFile,
  }) async {
    final fileName = const Uuid().v4();
    final ref = _storage.ref().child('chat_images/$fileName.jpg');

    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    await _firestore.collection('messages').add({
      'conversationId': conversationId,
      'senderId': senderId,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
    });

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': "📷 صورة",
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ================= جلب الرسائل =================
  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('timestamp', isGreaterThan: Timestamp(0, 0))
        .orderBy('timestamp')
        .snapshots();
  }
}
