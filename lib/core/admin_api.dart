import 'package:cloud_functions/cloud_functions.dart';

/// All admin mutations go through Cloud Functions (see fitgen
/// functions/adminService.js). Reads use Firestore directly.
class AdminApi {
  AdminApi({FirebaseFunctions? functions})
      : _f = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _f;

  Future<void> setUserStatus({
    required String uid,
    required String status,
    String? reason,
    DateTime? blockedUntil,
  }) async {
    await _f.httpsCallable('adminSetUserStatus').call({
      'uid': uid,
      'status': status,
      'reason': reason,
      if (blockedUntil != null)
        'blockedUntilMs': blockedUntil.millisecondsSinceEpoch,
    });
  }

  /// Returns the one-time invite (password reset) link.
  Future<String> createUser({
    required String email,
    required String name,
    int initialCoins = 0,
  }) async {
    final res = await _f.httpsCallable('adminCreateUser').call({
      'email': email,
      'name': name,
      'initialCoins': initialCoins,
    });
    return res.data['inviteLink'] as String;
  }
}
