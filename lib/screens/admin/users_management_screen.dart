import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersManagementScreen
    extends StatelessWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("👥 المستخدمين"),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final allUsers = snapshot.data!.docs;

          // 🔥 فلترة المستخدمين: استبعاد الأدمن والمستخدمين بدون اسم
          final users = allUsers.where((doc) {
            final data =
                doc.data()
                    as Map<String, dynamic>;
            final name =
                data['name']?.toString() ?? '';
            return data['role'] != 'admin' &&
                name.isNotEmpty &&
                name != 'بدون اسم';
          }).toList();

          if (users.isEmpty) {
            return const Center(
              child: Text(
                "لا يوجد مستخدمين حالياً",
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final data =
                  user.data()
                      as Map<String, dynamic>;

              final name = data['name'];
              final email = data['email'] ?? '';
              final isBanned =
                  data['isBanned'] == true;

              return Container(
                margin: const EdgeInsets.only(
                  bottom: 12,
                ),
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 👤 Avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors
                          .deepPurple
                          .withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        color: Colors.deepPurple,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 📄 Data
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            name,
                            style:
                                const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 15,
                                ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey[600],
                            ),
                            overflow: TextOverflow
                                .ellipsis,
                          ),
                          const SizedBox(
                            height: 8,
                          ),

                          // 🟢 / 🔴 Status Badge
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                            decoration: BoxDecoration(
                              color: isBanned
                                  ? Colors.red
                                        .withOpacity(
                                          0.1,
                                        )
                                  : Colors.green
                                        .withOpacity(
                                          0.1,
                                        ),
                              borderRadius:
                                  BorderRadius.circular(
                                    20,
                                  ),
                            ),
                            child: Text(
                              isBanned
                                  ? "محظور"
                                  : "نشط",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight
                                        .w600,
                                color: isBanned
                                    ? Colors.red
                                    : Colors
                                          .green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🔴 Ban Button
                    GestureDetector(
                      onTap: () async {
                        await FirebaseFirestore
                            .instance
                            .collection('users')
                            .doc(user.id)
                            .update({
                              'isBanned':
                                  !isBanned,
                            });
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.all(
                              8,
                            ),
                        decoration: BoxDecoration(
                          color: isBanned
                              ? Colors.green
                                    .withOpacity(
                                      0.1,
                                    )
                              : Colors.red
                                    .withOpacity(
                                      0.1,
                                    ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isBanned
                              ? Icons.lock_open
                              : Icons.block,
                          size: 20,
                          color: isBanned
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
