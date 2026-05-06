import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  Future<bool> isUsernameTaken(
    String name,
  ) async {
    final result = await _firestore
        .collection('users')
        .where('name', isEqualTo: name)
        .get();

    return result.docs.isNotEmpty;
  }

  // Sign Up with Email & Password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Check if username is already taken
      bool isTaken = await isUsernameTaken(name);

      if (isTaken) {
        throw "الاسم مستخدم بالفعل ❌ اختر اسم آخر";
      }
      // Create user
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

      User? user = userCredential.user;
      if (user == null) return null;

      // Create user document in Firestore
      UserModel userModel = UserModel(
        uid: user.uid,
        email: email,
        name: name,
        createdAt: DateTime.now(),
        role: email == "admin@gmail.com"
            ? 'admin'
            : 'user',
        isBanned: false,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
            ...userModel.toMap(),

            // Initialize with no nutritionist assigned
            'nutritionistId': null,
          });
      // Update display name
      await user.updateDisplayName(name);

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'حدث خطأ غير متوقع: $e';
    }
  }

  // Sign In with Email & Password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Check Firestore for user ban status before login
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userModel = UserModel.fromFirestore(
          query.docs.first,
        );

        // 🚫 لو محظور → نمنع الدخول
        if (userModel.isBanned) {
          throw "هذا الحساب محظور 🚫";
        }
      }

      // Step 2: Proceed with Firebase Auth login if not banned
      UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          );

      User? user = userCredential.user;
      if (user == null) return null;

      // Step 3: Load user data from Firestore
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      // 🔥 Auto-Repair: If name is missing or empty, set it from email
      Map<String, dynamic> data =
          doc.data() as Map<String, dynamic>;
      if (data['name'] == null ||
          data['name']
              .toString()
              .trim()
              .isEmpty) {
        String defaultName = email.split('@')[0];
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'name': defaultName});
        // Update the local data map so the returned model has the name
        data['name'] = defaultName;
      }

      return UserModel.fromMap(data, user.uid);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'فشل تسجيل الخروج: $e';
    }
  }

  // Get User Data
  Future<UserModel?> getUserData(
    String uid,
  ) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw 'فشل جلب بيانات المستخدم: $e';
    }
  }

  // Update User Profile
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (name != null) {
        updates['name'] = name;
        await _auth.currentUser
            ?.updateDisplayName(name);
      }

      if (preferences != null) {
        updates['preferences'] = preferences;
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(uid)
            .update(updates);
      }
    } catch (e) {
      throw 'فشل تحديث البيانات: $e';
    }
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'فشل إرسال رابط إعادة تعيين كلمة المرور: $e';
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw 'لا يوجد مستخدم مسجل';
      }

      // Delete user data from Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .delete();

      // Delete habits
      await _firestore
          .collection('habits')
          .where('userId', isEqualTo: user.uid)
          .get()
          .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

      // Delete dailyLogs
      await _firestore
          .collection('dailyLogs')
          .where('userId', isEqualTo: user.uid)
          .get()
          .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

      // Delete auth account
      await user.delete();
    } catch (e) {
      throw 'فشل حذف الحساب: $e';
    }
  }

  // Handle Auth Exceptions
  String _handleAuthException(
    FirebaseAuthException e,
  ) {
    switch (e.code) {
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-not-found':
        return 'المستخدم غير موجود';
      case 'wrong-password':
        return 'كلمة المرور خاطئة';
      case 'user-disabled':
        return 'هذا الحساب معطل';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'operation-not-allowed':
        return 'هذه العملية غير مسموحة';
      default:
        return 'حدث خطأ: ${e.message}';
    }
  }
}
