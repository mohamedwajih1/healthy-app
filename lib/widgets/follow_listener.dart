import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowRequestListener extends StatefulWidget {
  final Widget child;

  const FollowRequestListener({super.key, required this.child});

  @override
  State<FollowRequestListener> createState() => _FollowRequestListenerState();
}

class _FollowRequestListenerState extends State<FollowRequestListener> {
  bool isDialogShowing = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // ⏳ استنى لحد ما اليوزر يتحمل
      while (auth.user == null) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final myUserId = auth.user!.uid;

      // ✅ Listener على الطلبات
      _subscription = FirebaseFirestore.instance
          .collection('follow_requests')
          .where('to', isEqualTo: myUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
            if (snapshot.docs.isNotEmpty && !isDialogShowing) {
              isDialogShowing = true;
              _showDialog(snapshot.docs.first, myUserId);
            }
          });
    });
  }

  Future<void> _checkAndShow(DocumentSnapshot doc, String myUserId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myUserId)
        .get();

    final currentNutritionist = userDoc.data()?['nutritionistId'];

    // 🛑 لو already متابع → متظهرش dialog
    if (currentNutritionist != null) return;

    if (!mounted) return;

    isDialogShowing = true;
    _showDialog(doc, myUserId);
  }

  void _showDialog(DocumentSnapshot doc, String myUserId) {
    if (!mounted) return;

    final data = doc.data() as Map<String, dynamic>;
    final doctorId = data['from'];

    late BuildContext dialogContext;

    bool isHandled = false; // 🔥 الحل هنا (برا builder)

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;

        // ⏳ auto close بعد 5 ثواني
        Future.delayed(const Duration(seconds: 5), () async {
          if (!mounted) return;

          if (!isHandled &&
              Navigator.of(dialogContext, rootNavigator: true).canPop()) {
            // 🔥 أهم سطر
            await doc.reference.update({'status': 'seen'});

            Navigator.of(dialogContext, rootNavigator: true).pop();
            isDialogShowing = false;
          }
        });

        return AlertDialog(
          title: const Text("طلب متابعة"),
          content: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(doctorId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text("جارٍ التحميل...");
              }

              if (!snapshot.hasData || snapshot.data!.data() == null) {
                return SizedBox();
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final doctorName = userData['name'] ?? 'أخصائي';

              return Text("الأخصائي $doctorName يريد متابعتك");
            },
          ),
          actions: [
            TextButton(
           onPressed: () async {
                isHandled = true;

                final authProvider = context
                    .read<AuthProvider>(); // 👈 هنا التعديل

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(myUserId)
                    .update({'nutritionistId': doctorId});

                await doc.reference.update({'status': 'accepted'});

                await authProvider.updateProfile(); // 👈 هنا التعديل
if (!mounted) return;
                if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }

                isDialogShowing = false;
              },
              child: const Text("قبول"),
            ),
            TextButton(
              onPressed: () async {
                isHandled = true; // 🔥 مهم جدًا

                await doc.reference.update({'status': 'rejected'});

                if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }

                isDialogShowing = false;
              },
              child: const Text("رفض"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
