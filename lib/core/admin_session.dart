import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Capability names; must match functions/platformAdmin.js CAPABILITIES.
class Cap {
  static const usersRead = 'users_read';
  static const usersManage = 'users_manage';
  static const studioActivation = 'studio_activation';
  static const plansManage = 'plans_manage';
  static const featuresManage = 'features_manage';
  static const support = 'support';
  static const campaignsManage = 'campaigns_manage';
  static const analyticsRead = 'analytics_read';
  static const adminsManage = 'admins_manage';
  static const aiConfiguration = 'ai_configuration';
  static const aiSpendApproval = 'ai_spend_approval';
  static const platformConfiguration = 'platform_configuration';
  static const dataMigration = 'data_migration';
}

enum SessionStatus { loading, signedOut, notAdmin, admin }

/// Holds the signed-in admin and their capabilities.
class AdminSession extends ChangeNotifier {
  AdminSession({FirebaseAuth? auth, FirebaseFunctions? functions})
      : _auth = auth,
        // ignore: prefer_initializing_formals
        _functions = functions {
    if (auth != null || Firebase.apps.isNotEmpty) {
      _sub = (_auth ?? FirebaseAuth.instance).authStateChanges().listen(_onAuth);
    } else {
      status = SessionStatus.signedOut;
    }
  }

  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  StreamSubscription<User?>? _sub;

  SessionStatus status = SessionStatus.loading;
  Set<String> capabilities = {};
  String? error;

  User? get user =>
      (_auth ?? (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null))?.currentUser;
  bool can(String capability) => capabilities.contains(capability);
  bool canAny(Iterable<String> caps) => caps.any(capabilities.contains);

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
      final f = _functions ?? FirebaseFunctions.instance;
      final res = await f.httpsCallable('adminGetMe').call();
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
    final a = _auth ?? FirebaseAuth.instance;
    await a.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    final a = _auth ?? FirebaseAuth.instance;
    return a.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
