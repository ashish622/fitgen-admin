import 'package:cloud_functions/cloud_functions.dart';

/// All admin mutations go through Cloud Functions (see fitgen
/// functions/adminService.js, studioLifecycle.js, etc.). Reads use Firestore directly.
class AdminApi {
  AdminApi({FirebaseFunctions? functions}) : _f = functions;
  final FirebaseFunctions? _f;
  FirebaseFunctions get _functions => _f ?? FirebaseFunctions.instance;

  // ---------------------------------------------------------------------------
  // User Management
  // ---------------------------------------------------------------------------

  Future<void> setUserStatus({
    required String uid,
    required String status,
    String? reason,
    DateTime? blockedUntil,
  }) async {
    final payload = <String, dynamic>{
      'uid': uid,
      'status': status,
    };
    if (reason != null) payload['reason'] = reason;
    if (blockedUntil != null) {
      payload['blockedUntilMs'] = blockedUntil.millisecondsSinceEpoch;
    }
    await _functions.httpsCallable('adminSetUserStatus').call(payload);
  }

  /// Returns the one-time invite (password reset) link.
  Future<String> createUser({
    required String email,
    required String name,
    int initialCoins = 0,
  }) async {
    final res = await _functions.httpsCallable('adminCreateUser').call({
      'email': email,
      'name': name,
      'initialCoins': initialCoins,
    });
    return res.data['inviteLink'] as String;
  }

  // ---------------------------------------------------------------------------
  // Partner & Studio Management
  // ---------------------------------------------------------------------------

  /// Transitions studio lifecycle: 'pending_verification', 'active', 'paused',
  /// 'suspended', 'archived'.
  Future<void> setStudioLifecycleStatus({
    required String partnerId,
    required String targetStatus,
    String? reason,
    Map<String, dynamic>? attestations,
  }) async {
    final payload = <String, dynamic>{
      'partnerId': partnerId,
      'targetStatus': targetStatus,
    };
    if (reason != null) payload['reason'] = reason;
    if (attestations != null) payload['attestations'] = attestations;

    await _functions.httpsCallable('setStudioLifecycleStatus').call(payload);
  }

  /// Records operator identity verification and compliance sign-off.
  Future<void> recordStudioIdentityVerification({
    required String partnerId,
    required bool verified,
    String? operatorName,
    String? operatorEmail,
    String? operatorPhone,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'partnerId': partnerId,
      'verified': verified,
    };
    if (operatorName != null) payload['operatorName'] = operatorName;
    if (operatorEmail != null) payload['operatorEmail'] = operatorEmail;
    if (operatorPhone != null) payload['operatorPhone'] = operatorPhone;
    if (notes != null) payload['notes'] = notes;

    await _functions.httpsCallable('recordStudioIdentityVerification').call(payload);
  }

  /// Fetches the server readiness evaluation checklist for a studio.
  Future<Map<String, dynamic>> getStudioReadiness({
    required String partnerId,
  }) async {
    final res = await _functions.httpsCallable('getStudioReadiness').call({
      'partnerId': partnerId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Onboards a new partner studio in 'pending_verification' status.
  Future<Map<String, dynamic>> onboardPartner({
    required String name,
    required String timezone,
    required String country,
    String? phone,
    String? email,
    String? address,
    String? city,
  }) async {
    final clientRequestId =
        'adm_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs().toRadixString(36)}';

    final location = <String, dynamic>{'name': 'Primary'};
    if (address != null) location['address'] = address;
    if (city != null) location['city'] = city;

    final payload = <String, dynamic>{
      'clientRequestId': clientRequestId,
      'name': name,
      'timezone': timezone,
      'country': country,
      'locations': [location],
    };
    if (phone != null) payload['phone'] = phone;
    if (email != null) payload['email'] = email;

    final res = await _functions.httpsCallable('onboardPartner').call(payload);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
