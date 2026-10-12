import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Capability names; must match functions/platformAdmin.js CAPABILITIES.
class Cap {
  static const usersRead = 'users_read';
  static const usersManage = 'users_manage';
  static const featuresManage = 'features_manage';
  static const support = 'support';
  static const campaignsManage = 'campaigns_manage';
  static const analyticsRead = 'analytics_read';
  static const adminsManage = 'admins_manage';
}

enum SessionStatus { loading, signedOut, notAdmin, admin }

/// Holds the signed-in admin and their capabilities.
class AdminSession extends ChangeNotifier {
  AdminSession({FirebaseAuth? auth, FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance {
    _sub = _auth.authStateChanges().listen(_onAuth);
  }

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  late final StreamSubscription<User?> _sub;

  SessionStatus status = SessionStatus.loading;
  Set<String> capabilities = {};
  String? error;

  User? get user => _auth.currentUser;
  bool can(String capability) => capabilities.contains(capability);

  Future<void> _onAuth(User? user) async {
    if (user == null) {
      capabilities = {};
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    status = SessionStatus.loading;
    notifyListeners();
    try {
      final res = await _functions.httpsCallable('adminGetMe').call();
      final caps = (res.data['capabilities'] as List).cast<String>();
      capabilities = caps.toSet();
      status = SessionStatus.admin;
    } on FirebaseFunctionsException catch (e) {
      capabilities = {};
      status = e.code == 'permission-denied'
          ? SessionStatus.notAdmin
          : SessionStatus.signedOut;
      error = e.message;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    error = null;
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
