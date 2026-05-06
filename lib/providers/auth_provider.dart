import 'dart:async';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider with ChangeNotifier {
  bool _isHandlingBan = false;
  StreamSubscription<DocumentSnapshot>?
  _userListener;

  UserModel? _userModel;

  UserModel? get userModel => _userModel;
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated;

  AuthProvider() {
    _initAuth();
  }

  Future<void> updateProfile() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      _userModel = UserModel.fromFirestore(doc);
      notifyListeners();
    }
  }

  void _setUserOnlineStatus(bool isOnline) {
    if (_user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .update({
          'isOnline': isOnline,
          'lastSeen':
              FieldValue.serverTimestamp(),
        });
  }

  // ================= INIT =================
  void _initAuth() {
    _authService.authStateChanges.listen((
      User? firebaseUser,
    ) async {
      try {
        if (firebaseUser != null) {
          _user = await _authService.getUserData(
            firebaseUser.uid,
          );
          _userModel = _user;
          await _startUserListener();

          _status = AuthStatus.authenticated;
        } else {
          await _userListener?.cancel();
          _userListener = null;

          _user = null;
          _status = AuthStatus.unauthenticated;
        }
      } catch (e) {
        // Reset user state on auth error
        _user = null;
        _status = AuthStatus.unauthenticated;
        _error = e.toString();
      }

      notifyListeners();
    });
  }

  Future<void> _startUserListener() async {
    if (_user == null) return;

    await _userListener?.cancel();

    _userListener = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .snapshots()
        .listen((doc) async {
          final data = doc.data();

          bool isBanned =
              data?['isBanned'] == true;

          if (isBanned && !_isHandlingBan) {
            _isHandlingBan = true;

            // User is banned - force logout
            await signOut();

            _error = "تم حظر هذا الحساب";
            notifyListeners();

            _isHandlingBan = false;
          }
        });
  }

  // ================= SIGN UP =================
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      _user = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );

      if (_user != null) {
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      _status = AuthStatus.unauthenticated;
      _error = 'فشل إنشاء الحساب';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.unauthenticated;

      switch (e.code) {
        case 'email-already-in-use':
          _error =
              'البريد الإلكتروني مستخدم بالفعل';
          break;
        case 'weak-password':
          _error = 'كلمة المرور ضعيفة';
          break;
        case 'invalid-email':
          _error = 'البريد الإلكتروني غير صالح';
          break;
        default:
          _error = 'حدث خطأ أثناء إنشاء الحساب';
      }

      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;

      // Store error message for display
      _error = e.toString();

      notifyListeners();
      return false;
    }
  }

  // ================= SIGN IN =================
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      _user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (_user != null) {
        // Copy user data to model
        _userModel = _user;

        await _startUserListener();

        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      _status = AuthStatus.unauthenticated;
      _error = 'فشل تسجيل الدخول';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.unauthenticated;

      final msg = (e.message ?? '').toLowerCase();

      if (msg.contains('user') &&
          msg.contains('not')) {
        _error =
            'لا يوجد حساب بهذا البريد الإلكتروني';
      } else if (msg.contains('password') ||
          msg.contains('credential')) {
        _error =
            'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      } else if (msg.contains('email')) {
        _error = 'البريد الإلكتروني غير صالح';
      } else if (msg.contains('network')) {
        _error = 'تأكد من اتصالك بالإنترنت';
      } else {
        _error =
            'فشل تسجيل الدخول، تحقق من البيانات';
      }

      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;

      final msg = e.toString().toLowerCase();

      if (msg.contains('credential')) {
        _error =
            'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      } else {
        _error = 'حدث خطأ غير متوقع';
      }

      notifyListeners();
      return false;
    }
  }

  // ================= SIGN OUT =================
  Future<void> signOut() async {
    try {
      await _userListener?.cancel();
      _userListener = null;
      // Mark user as offline when signing out
      _setUserOnlineStatus(false);

      await _authService.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'فشل تسجيل الخروج';
      notifyListeners();
    }
  }

  // ================= RESET PASSWORD =================
  Future<bool> resetPassword(String email) async {
    try {
      _error = null;
      await _authService.resetPassword(email);
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _error = 'المستخدم غير موجود';
          break;
        default:
          _error = 'حدث خطأ';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ غير متوقع';
      notifyListeners();
      return false;
    }
  }

  // ================= DELETE =================
  Future<bool> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل حذف الحساب';
      notifyListeners();
      return false;
    }
  }

  // ================= CLEAR ERROR =================
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
