import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healty_app/providers/auth_provider.dart';

class RequestsScreen extends StatelessWidget {
  final String myUserId;

  const RequestsScreen({super.key, required this.myUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلبات المتابعة")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('follow_requests')
            .where('to', isEqualTo: myUserId)
.where('status', whereIn: ['pending', 'seen'])            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("👌 لا توجد طلبات متابعة حالياً"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final doctorId = data['from'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(doctorId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(title: Text("جارٍ التحميل..."));
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;

                  final doctorName = userData?['name'] ?? 'أخصائي';

                  return ListTile(
                    title: Text(doctorName),
                    subtitle: const Text("يريد متابعتك"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            final authProvider = context.read<AuthProvider>();

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(myUserId)
                                .update({'nutritionistId': doctorId});

                            await doc.reference.update({'status': 'accepted'});

                            await authProvider.updateProfile();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await doc.reference.update({'status': 'rejected'});
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
