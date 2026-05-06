import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:healty_app/models/habit_model.dart';
import 'package:healty_app/widgets/habit_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healty_app/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.conversationId,
    required this.myId,
    required this.otherName,
    required this.otherId,
  });

  final String? conversationId;
  final String myId;
  final String otherId;
  final String otherName;

  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chatService = ChatService();
  final TextEditingController controller =
      TextEditingController();
  bool isBlocked = false;
  List<Map<String, dynamic>> localMessages = [];

  Timer? _onlineTimer;
  final ScrollController _scrollController =
      ScrollController();
  Timer? _typingTimer;

  @override
  void dispose() {
    _setOnline(false);
    _onlineTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // تصحيح حالة الحظر عند البداية
    _checkInitialBlockStatus();

    _setOnline(true);

    if (widget.conversationId != null) {
      FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .set({
            'unread': {widget.myId: 0},
          }, SetOptions(merge: true));
    }

    _onlineTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.myId)
            .update({
              'lastSeen':
                  FieldValue.serverTimestamp(),
            });
      },
    );
  }

  String getLastSeenText(
    Timestamp? lastSeen,
    bool isOnline,
  ) {
    if (lastSeen == null) return "غير متصل";

    final now = DateTime.now();
    final last = lastSeen.toDate();
    final diff = now.difference(last);

    if (isOnline) {
      if (diff.inSeconds < 60) return "متصل الآن";
      if (diff.inMinutes < 60) {
        return "متصل منذ ${diff.inMinutes} دقيقة";
      }
      if (diff.inHours < 24) {
        return "متصل منذ ${diff.inHours} ساعة";
      }
    }

    if (diff.inMinutes < 1) {
      return "آخر ظهور الآن";
    }
    if (diff.inMinutes < 60) {
      return "آخر ظهور منذ ${diff.inMinutes} دقيقة";
    }
    if (diff.inHours < 24) {
      return "آخر ظهور منذ ${diff.inHours} ساعة";
    }

    return "آخر ظهور منذ ${diff.inDays} يوم";
  }

  String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final messageDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference = today
        .difference(messageDate)
        .inDays;

    if (difference == 0) return "اليوم";
    if (difference == 1) return "أمس";

    return "${date.day}/${date.month}/${date.year}";
  }

  Widget buildStatusIcon(String? status) {
    switch (status) {
      case 'sending':
        return const Icon(
          Icons.access_time,
          size: 14,
          color: Colors.grey,
        );

      case 'sent':
        return const Icon(
          Icons.north_east,
          size: 14,
          color: Colors.grey,
        );

      case 'delivered':
        return const Icon(
          Icons.place_outlined,
          size: 14,
          color: Colors.grey,
        );

      case 'seen':
        return const Icon(
          Icons.remove_red_eye,
          size: 14,
          color: Color.fromARGB(
            255,
            142,
            33,
            243,
          ),
        );

      case 'failed':
        return const Icon(
          Icons.error,
          size: 14,
          color: Colors.red,
        );

      default:
        return const SizedBox();
    }
  }

  void _setOnline(bool value) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.myId)
        .update({
          'isOnline': value,
          'lastSeen':
              FieldValue.serverTimestamp(),
        });
  }

  void _checkInitialBlockStatus() async {
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.myId)
        .get();
    final otherDoc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(widget.otherId)
        .get();

    if (myDoc.exists && otherDoc.exists) {
      final myData =
          myDoc.data() as Map<String, dynamic>;
      final otherData =
          otherDoc.data() as Map<String, dynamic>;

      final myBlocked = List<String>.from(
        myData['blockedUsers'] ?? [],
      );
      final otherBlocked = List<String>.from(
        otherData['blockedUsers'] ?? [],
      );

      setState(() {
        isBlocked =
            myBlocked.contains(widget.otherId) ||
            otherBlocked.contains(widget.myId);
      });
    }
  }

  void _markMessagesStatus(
    List<QueryDocumentSnapshot> docs,
  ) {
    for (var doc in docs) {
      final data =
          doc.data() as Map<String, dynamic>;

      if (data['senderId'] != widget.myId) {
        // 🟡 Delivered
        if (data['status'] == 'sent') {
          doc.reference.update({
            'status': 'delivered',
          });
        }

        // 🔵 Seen (لو الشاشة مفتوحة)
        if (data['status'] == 'delivered') {
          doc.reference.update({
            'status': 'seen',
          });
        }
      }
    }
  }

  void _showDeleteOptions(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) {
    final data =
        doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == widget.myId;

    showModalBottomSheet(
      backgroundColor: Color.fromARGB(
        255,
        249,
        192,
        192,
      ),
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMe)
                ListTile(
                  leading: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  title: const Text(
                    "حذف عند الجميع",
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await doc.reference.update({
                      'text': 'تم حذف الرسالة',
                      'isDeleted': true,
                    });
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                ),
                title: const Text("حذف عندي"),
                onTap: () async {
                  Navigator.pop(context);
                  await doc.reference.update({
                    'text': 'تم حذف الرسالة',
                    'isDeleted': true,
                  });

                  await FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(widget.conversationId)
                      .update({
                        'lastMessage':
                            'تم حذف الرسالة',
                      });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    final file = File(pickedFile.path);

    await chatService.sendImage(
      conversationId: widget.conversationId!,
      senderId: widget.myId,
      imageFile: file,
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController
            .position
            .maxScrollExtent,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
      );
    }
  }

  void showUserHabitsDialog(
    BuildContext context,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              20,
            ),
          ),
          child: Container(
            height: 450,
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Column(
              children: [
                const Text(
                  "عادات المستخدم",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder(
                    stream: FirebaseFirestore
                        .instance
                        .collection('habits')
                        .where(
                          'userId',
                          isEqualTo: userId,
                        )
                        .where(
                          'isActive',
                          isEqualTo: true,
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child:
                              CircularProgressIndicator(),
                        );
                      }

                      final docs =
                          snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "لا توجد عادات",
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index]
                              .data();

                          final habit =
                              HabitModel.fromMap(
                                data,
                                docs[index].id,
                              );

                          /// 👇 دي أهم نقطة
                          final isCompleted =
                              habit
                                  .currentStreak >
                              0;

                          return HabitCard(
                            habit: habit,
                            isCompleted:
                                isCompleted,

                            /// ❌ مهم جداً
                            onToggle:
                                () {}, // مفيش تعديل من المتخصص
                            /// ❌ متمنعش swipe
                            onDelete: null,
                            onEdit: null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.myId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox();
              }

              final data =
                  snapshot.data!.data()
                      as Map<String, dynamic>?;

              final blocked = List<String>.from(
                data?['blockedUsers'] ?? [],
              );
              final newBlocked = blocked.contains(
                widget.otherId,
              );

              if (newBlocked != isBlocked) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) {
                      setState(() {
                        isBlocked = newBlocked;
                      });
                    });
              }

              // 🔥 هنا الصح
              final myRole = data?['role'] ?? '';

              return FutureBuilder<
                DocumentSnapshot
              >(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.otherId)
                    .get(),
                builder: (context, otherSnapshot) {
                  if (!otherSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final otherData =
                      otherSnapshot.data!.data()
                          as Map<
                            String,
                            dynamic
                          >?;

                  final otherRole =
                      otherData?['role'] ?? '';
                  final nutritionistId =
                      otherData?['nutritionistId'];
                  return Row(
                    children: [
                      if (myRole ==
                              'specialist' &&
                          otherRole == 'user' &&
                          nutritionistId ==
                              widget.myId)
                        IconButton(
                          icon: const Icon(
                            Icons.bar_chart,
                          ),
                          onPressed: () {
                            showUserHabitsDialog(
                              context,
                              widget.otherId,
                            );
                          },
                        ),

                      // ✅ الشرط الصح
                      if (myRole ==
                              'specialist' &&
                          otherRole == 'user' &&
                          nutritionistId !=
                              widget.myId)
                        IconButton(
                          icon: const Icon(
                            Icons.person_add,
                          ),
                          onPressed: () async {
                            final firestore =
                                FirebaseFirestore
                                    .instance;

                            final existing = await firestore
                                .collection(
                                  'follow_requests',
                                )
                                .where(
                                  'from',
                                  isEqualTo:
                                      widget.myId,
                                )
                                .where(
                                  'to',
                                  isEqualTo: widget
                                      .otherId,
                                )
                                .orderBy(
                                  'createdAt',
                                  descending:
                                      true,
                                )
                                .limit(1)
                                .get();

                            if (existing
                                .docs
                                .isNotEmpty) {
                              // 🔁 إعادة إرسال (حتى لو كان rejected أو accepted قبل كده)
                              await existing
                                  .docs
                                  .first
                                  .reference
                                  .update({
                                    'status':
                                        'pending',
                                    'createdAt':
                                        FieldValue.serverTimestamp(),
                                  });
                            } else {
                              // 🆕 أول مرة
                              await firestore
                                  .collection(
                                    'follow_requests',
                                  )
                                  .add({
                                    'from': widget
                                        .myId,
                                    'to': widget
                                        .otherId,
                                    'status':
                                        'pending',
                                    'createdAt':
                                        FieldValue.serverTimestamp(),
                                  });
                            }
                          },
                        ),
                      PopupMenuButton(
                        onSelected: (value) async {
                          if (value == 'block') {
                            await chatService
                                .blockUser(
                                  myId:
                                      widget.myId,
                                  otherId: widget
                                      .otherId,
                                );
                          }

                          if (value ==
                              'unblock') {
                            await chatService
                                .unblockUser(
                                  myId:
                                      widget.myId,
                                  otherId: widget
                                      .otherId,
                                );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: isBlocked
                                ? 'unblock'
                                : 'block',
                            child: Text(
                              isBlocked
                                  ? "فك الحظر"
                                  : "حظر المستخدم",
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
        iconTheme: const IconThemeData(
          size: 32,
          color: Colors.white,
        ),
        backgroundColor: const Color.fromARGB(
          255,
          64,
          63,
          87,
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .snapshots(),
          builder: (context, convoSnapshot) {
            return StreamBuilder<
              DocumentSnapshot
            >(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.otherId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                return StreamBuilder<
                  DocumentSnapshot
                >(
                  stream: FirebaseFirestore
                      .instance
                      .collection('users')
                      .doc(widget.myId)
                      .snapshots(),
                  builder: (context, mySnapshot) {
                    if (!convoSnapshot.hasData ||
                        !userSnapshot.hasData ||
                        !mySnapshot.hasData) {
                      return Text(
                        widget.otherName,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      );
                    }

                    final convoData =
                        convoSnapshot.data!.data()
                            as Map<
                              String,
                              dynamic
                            >?;

                    final userData =
                        userSnapshot.data!.data()
                            as Map<
                              String,
                              dynamic
                            >?;

                    final myData =
                        mySnapshot.data!.data()
                            as Map<
                              String,
                              dynamic
                            >?;

                    // 🔥 typing
                    final typing =
                        convoData?['typing'] ??
                        {};
                    final isTyping =
                        typing[widget.otherId] ==
                        true;

                    // 🔥 online
                    final isOnline =
                        userData?['isOnline'] ??
                        false;
                    final lastSeen =
                        userData?['lastSeen']
                            as Timestamp?;

                    // 🔥 block
                    final myBlocked =
                        List<String>.from(
                          myData?['blockedUsers'] ??
                              [],
                        );

                    final otherBlocked =
                        List<String>.from(
                          userData?['blockedUsers'] ??
                              [],
                        );

                    final isBlocked =
                        myBlocked.contains(
                          widget.otherId,
                        ) ||
                        otherBlocked.contains(
                          widget.myId,
                        );

                    // 🔥 تحديد نوع الحظر
                    String blockText = "";

                    if (myBlocked.contains(
                      widget.otherId,
                    )) {
                      blockText =
                          "تم حظر المستخدم";
                    } else if (otherBlocked
                        .contains(widget.myId)) {
                      blockText = "تم حظرك";
                    }

                    return Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Text(
                          widget.otherName,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          isBlocked
                              ? blockText
                              : isTyping
                              ? "يكتب الآن..."
                              : getLastSeenText(
                                  lastSeen,
                                  isOnline,
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            color: isBlocked
                                ? Colors.red
                                : isTyping
                                ? Colors.green
                                : (isOnline
                                      ? Colors
                                            .green
                                      : Colors
                                            .white70),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background2.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      widget.conversationId ==
                          null
                      ? null
                      : chatService.getMessages(
                          widget.conversationId!,
                        ),
                  builder: (context, snapshot) {
                    if (widget.conversationId ==
                        null) {
                      return const Center(
                        child: Text(
                          "ابدأ الدردشه الان👋",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final firebaseDocs =
                        snapshot.data!.docs;
                    if (firebaseDocs.isEmpty &&
                        localMessages.isEmpty) {
                      return const Center(
                        child: Text(
                          "ابدأ الدردشه الان👋",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    // ✔️ تحديث status من Firebase فقط
                    if (snapshot.hasData &&
                        snapshot
                            .data!
                            .docs
                            .isNotEmpty) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((
                            _,
                          ) {
                            _markMessagesStatus(
                              snapshot.data!.docs,
                            );
                          });
                    }
                    // ✔️ تحويل Firebase → Map
                    final firebaseMessages =
                        firebaseDocs
                            .map(
                              (e) =>
                                  e.data()
                                      as Map<
                                        String,
                                        dynamic
                                      >,
                            )
                            .toList();

                    // ✔️ دمج مع localMessages
                    final firebaseIds =
                        firebaseMessages
                            .map((m) => m['id'])
                            .where(
                              (id) => id != null,
                            )
                            .toSet();

                    // 🧠 فلترة localMessages
                    final filteredLocal =
                        localMessages.where((
                          local,
                        ) {
                          return !firebaseIds
                                  .contains(
                                    local['id'],
                                  ) &&
                              local['status'] !=
                                  'sent';
                        }).toList();

                    final docs = [
                      ...firebaseMessages,
                      ...filteredLocal,
                    ];

                    WidgetsBinding.instance
                        .addPostFrameCallback((
                          _,
                        ) {
                          _scrollToBottom();
                        });

                    return ListView.builder(
                      controller:
                          _scrollController,
                      padding:
                          const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final msg = docs[index];
                        final isMe =
                            msg['senderId'] ==
                            widget.myId;

                        final timestamp =
                            msg['timestamp']
                                as Timestamp?;
                        final date = timestamp
                            ?.toDate();

                        final time = date != null
                            ? TimeOfDay.fromDateTime(
                                date,
                              ).format(context)
                            : '';

                        final status =
                            msg['status'] ??
                            'sent';

                        // ✔️ prevDate آمن
                        final prevTimestamp =
                            index > 0
                            ? docs[index -
                                      1]['timestamp']
                                  as Timestamp?
                            : null;

                        final prevDate =
                            prevTimestamp
                                ?.toDate();

                        final showDate =
                            date != null &&
                            (prevDate == null ||
                                date.day !=
                                    prevDate
                                        .day ||
                                date.month !=
                                    prevDate
                                        .month ||
                                date.year !=
                                    prevDate
                                        .year);

                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                      vertical:
                                          10,
                                    ),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                        horizontal:
                                            12,
                                        vertical:
                                            6,
                                      ),
                                  decoration: BoxDecoration(
                                    color: Colors
                                        .black45,
                                    borderRadius:
                                        BorderRadius.circular(
                                          20,
                                        ),
                                  ),
                                  child: Text(
                                    formatDateLabel(
                                      date,
                                    ),
                                    style: const TextStyle(
                                      color: Colors
                                          .white,
                                      fontSize:
                                          12,
                                    ),
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onLongPress: () {
                                if (index <
                                    firebaseDocs
                                        .length) {
                                  final firebaseDoc =
                                      firebaseDocs[index];
                                  _showDeleteOptions(
                                    context,
                                    firebaseDoc,
                                  );
                                }
                              },
                              child: Align(
                                alignment: isMe
                                    ? Alignment
                                          .centerRight
                                    : Alignment
                                          .centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(
                                          context,
                                        ).size.width *
                                        0.7,
                                  ),
                                  margin:
                                      const EdgeInsets.symmetric(
                                        vertical:
                                            5,
                                        horizontal:
                                            10,
                                      ),
                                  padding:
                                      const EdgeInsets.symmetric(
                                        horizontal:
                                            16,
                                        vertical:
                                            12,
                                      ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color.fromARGB(
                                            255,
                                            41,
                                            40,
                                            67,
                                          )
                                        : const Color.fromARGB(
                                            255,
                                            57,
                                            57,
                                            62,
                                          ),
                                    borderRadius: BorderRadius.only(
                                      topLeft:
                                          const Radius.circular(
                                            16,
                                          ),
                                      topRight:
                                          const Radius.circular(
                                            16,
                                          ),
                                      bottomLeft:
                                          isMe
                                          ? const Radius.circular(
                                              16,
                                            )
                                          : const Radius.circular(
                                              0,
                                            ),
                                      bottomRight:
                                          isMe
                                          ? const Radius.circular(
                                              0,
                                            )
                                          : const Radius.circular(
                                              16,
                                            ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .end,
                                    children: [
                                      Text(
                                        msg['isDeleted'] ==
                                                true
                                            ? 'تم حذف هذه الرسالة'
                                            : (msg['text'] ??
                                                  ''),
                                        style: TextStyle(
                                          fontSize:
                                              18,
                                          color: Colors.white.withOpacity(
                                            msg['isDeleted'] ==
                                                    true
                                                ? 0.6
                                                : 1,
                                          ),
                                          fontStyle:
                                              msg['isDeleted'] ==
                                                  true
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 6,
                                      ),
                                      Row(
                                        mainAxisSize:
                                            MainAxisSize
                                                .min,
                                        children: [
                                          Text(
                                            time,
                                            style: TextStyle(
                                              fontSize:
                                                  11,
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width:
                                                5,
                                          ),
                                          if (isMe)
                                            buildStatusIcon(
                                              status,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    218,
                    218,
                    218,
                  ),
                  borderRadius:
                      BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: isBlocked
                          ? Container(
                              alignment: Alignment
                                  .center,
                              child: const Text(
                                "تم حظر هذا المستخدم",
                                style: TextStyle(
                                  color:
                                      Colors.red,
                                ),
                              ),
                            )
                          : TextField(
                              controller:
                                  controller,
                              onChanged: (value) {
                                FirebaseFirestore
                                    .instance
                                    .collection(
                                      'conversations',
                                    )
                                    .doc(
                                      widget
                                          .conversationId,
                                    )
                                    .set(
                                      {
                                        'typing': {
                                          widget
                                              .myId: value
                                              .isNotEmpty,
                                        },
                                      },
                                      SetOptions(
                                        merge:
                                            true,
                                      ),
                                    );

                                _typingTimer
                                    ?.cancel();
                                _typingTimer = Timer(
                                  const Duration(
                                    seconds: 2,
                                  ),
                                  () {
                                    FirebaseFirestore
                                        .instance
                                        .collection(
                                          'conversations',
                                        )
                                        .doc(
                                          widget
                                              .conversationId,
                                        )
                                        .set(
                                          {
                                            'typing': {
                                              widget.myId:
                                                  false,
                                            },
                                          },
                                          SetOptions(
                                            merge:
                                                true,
                                          ),
                                        );
                                  },
                                );
                              },
                              decoration:
                                  const InputDecoration(
                                    hintText:
                                        "اكتب رسالة...",
                                    border:
                                        InputBorder
                                            .none,
                                  ),
                            ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.send,
                      ),
                      onPressed: isBlocked
                          ? null
                          : () async {
                              final text =
                                  controller.text
                                      .trim();
                              if (text.isEmpty) {
                                return;
                              }

                              controller.clear();

                              // Reset typing status immediately
                              FirebaseFirestore
                                  .instance
                                  .collection(
                                    'conversations',
                                  )
                                  .doc(
                                    widget
                                        .conversationId,
                                  )
                                  .set(
                                    {
                                      'typing': {
                                        widget.myId:
                                            false,
                                      },
                                    },
                                    SetOptions(
                                      merge: true,
                                    ),
                                  );

                              final tempId =
                                  DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString();

                              // ✅ 1. عرض الرسالة فورًا
                              setState(() {
                                localMessages.add({
                                  'id': tempId,
                                  'text': text,
                                  'senderId':
                                      widget.myId,
                                  'status':
                                      'sending',
                                  'timestamp':
                                      Timestamp.now(),
                                });
                              });

                              // ✅ 2. إرسال الرسالة (برا setState)
                              String?
                              convoId = widget
                                  .conversationId;

                              // 🧠 لو مفيش محادثة → ننشئ واحدة
                              convoId ??=
                                  await chatService
                                      .getOrCreateConversation(
                                        widget
                                            .myId,
                                        widget
                                            .otherId,
                                      );

                              // 🔥 إرسال الرسالة
                              if (convoId !=
                                  null) {
                                await chatService
                                    .sendMessage(
                                      id: tempId,
                                      conversationId:
                                          convoId,
                                      senderId:
                                          widget
                                              .myId,
                                      text: text,
                                    );
                              } else {
                                print(
                                  "❌ Failed to get or create conversation",
                                );
                                // يمكنك هنا إضافة تنبيه للمستخدم إذا فشل إنشاء المحادثة
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
