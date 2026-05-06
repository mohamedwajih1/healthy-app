import 'chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healty_app/services/chat_service.dart';


class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myId = user.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 229, 228, 243),
        appBar: AppBar(
          title: const Text("الشات"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "الدردشات"),
              Tab(text: "اكتشاف"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildConversations(context, myId),
_buildUsers(context, myId, authProvider.userModel!.role),          ],
        ),
      ),
    );
  }

  // ================== 🟦 الدردشات ==================
  Widget _buildConversations(BuildContext context, String myId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: myId)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد محادثات بعد"));
        }

        final chats = snapshot.data!.docs;
        final filteredChats = chats.where((chat) {
          final lastMessage = chat['lastMessage'] ?? '';
          return lastMessage.toString().trim().isNotEmpty;
        }).toList();

        return ListView.builder(
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final chat = filteredChats[index];
            final participants = List<String>.from(chat['participants'] ?? []);
            final otherId = participants.firstWhere((id) => id != myId);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherId)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircleAvatar(child: Icon(Icons.person)),
                    title: Text("..."),
                  );
                }

                String userName = "User";

                if (userSnapshot.hasData &&
                    userSnapshot.data!.exists &&
                    userSnapshot.data!.data() != null) {
                  final data =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  if (data['name'] != null &&
                      data['name'].toString().isNotEmpty) {
                    userName = data['name'];
                  } else {
                    userName = otherId.substring(0, 6);
                  }
                } else {
                  userName = otherId.substring(0, 6);
                }

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(userName),
                  subtitle: Text(chat['lastMessage'] ?? ""),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: chat.id,
                          myId: myId,
                          otherName: userName,
                          otherId: otherId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ================== 🟩 اكتشاف ==================
 Widget _buildUsers(BuildContext context, String myId, String myRole) {
  Query query;
final stream = FirebaseFirestore.instance.collection('users').snapshots();

  return StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(child: Text("لا يوجد مستخدمين متاحين"));
      }
final users = snapshot.data!.docs;

        // هات الأدمن
        DocumentSnapshot? admin;

        try {
          admin = users.firstWhere((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['role'] == 'admin';
          });
        } catch (e) {
          admin = null;
        }

        // اعمل ليست جديدة
        List allUsers = [...users];

        if (admin != null) {
          allUsers.removeWhere((u) => u.id == admin!.id);
          allUsers.insert(0, admin); // يخليه أول واحد
        }

      return ListView.builder(
        itemCount: allUsers.length,
          itemBuilder: (context, index) {
            final user = allUsers[index];

          if (user.id == myId) return const SizedBox();

          final data = user.data() as Map<String, dynamic>;

            final name = data.containsKey('name') ? data['name'] : 'بدون اسم';
            final role = data.containsKey('role') ? data['role'] : '';

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(name),
              subtitle: Text(role),
              trailing: const Icon(Icons.chat),
              onTap: () async {
                final convoId = await ChatService().getOrCreateConversation(
                  myId,
                  user.id,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: convoId,
                      myId: myId,
                      otherName: name,
                      otherId: user.id,
                    ),
                  ),
                );
              },
            );
        },
      );
    },
  );
}
  
}
