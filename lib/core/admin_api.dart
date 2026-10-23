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

  /// Adjusts a user's coin balance (+/- amount) with mandatory reason.
  Future<int> adjustCoins({
    required String uid,
    required int amount,
    required String reason,
  }) async {
    final res = await _functions.httpsCallable('adminAdjustCoins').call({
      'uid': uid,
      'amount': amount,
      'reason': reason,
    });
    return (res.data['newBalance'] as num).toInt();
  }

  /// Generates a password reset link for the user.
  Future<String> resetPassword({required String uid}) async {
    final res = await _functions.httpsCallable('adminResetPassword').call({
      'uid': uid,
    });
    return res.data['link'] as String;
  }

  /// Sets per-user feature overrides in userFeatureAccess/{uid}.
  Future<void> setUserFeatures({
    required String uid,
    required Map<String, dynamic> overrides,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'uid': uid,
      'overrides': overrides,
    };
    if (reason != null) payload['reason'] = reason;
    await _functions.httpsCallable('adminSetUserFeatures').call(payload);
  }

  // ---------------------------------------------------------------------------
  // Support, Tickets & Feedback
  // ---------------------------------------------------------------------------

  Future<void> updateTicket({
    required String ticketId,
    String? status,
    String? priority,
    String? assignedTo,
  }) async {
    final payload = <String, dynamic>{'ticketId': ticketId};
    if (status != null) payload['status'] = status;
    if (priority != null) payload['priority'] = priority;
    if (assignedTo != null) payload['assignedTo'] = assignedTo;

    await _functions.httpsCallable('adminUpdateTicket').call(payload);
  }

  Future<void> replyTicket({
    required String ticketId,
    required String body,
  }) async {
    await _functions.httpsCallable('adminReplyTicket').call({
      'ticketId': ticketId,
      'body': body,
    });
  }

  Future<void> updateFeedback({
    required String feedbackId,
    required String status,
  }) async {
    await _functions.httpsCallable('adminUpdateFeedback').call({
      'feedbackId': feedbackId,
      'status': status,
    });
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

  // ---------------------------------------------------------------------------
  // Plans & Entitlements Management
  // ---------------------------------------------------------------------------

  /// Creates a recurring visit allowance plan for a partner studio.
  Future<Map<String, dynamic>> createPartnerPlan({
    required String partnerId,
    required String planId,
    required String name,
    required dynamic allowance, // int or "unlimited"
    bool allClassTypes = true,
    List<String>? eligibleClassTypeIds,
    bool rolloverEnabled = false,
    int maxCarry = 0,
  }) async {
    final payload = <String, dynamic>{
      'partnerId': partnerId,
      'planId': planId,
      'name': name,
      'allowance': allowance,
      'allClassTypes': allClassTypes,
      'rollover': {
        'enabled': rolloverEnabled,
      },
    };
    if (eligibleClassTypeIds != null) {
      payload['eligibleClassTypeIds'] = eligibleClassTypeIds;
    }
    if (rolloverEnabled) {
      (payload['rollover'] as Map<String, dynamic>)['maxCarry'] = maxCarry;
    }

    final res = await _functions.httpsCallable('createPartnerPlan').call(payload);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Issues an entitlement grant for a member enrollment's monthly period (e.g. "2026-11").
  Future<Map<String, dynamic>> issuePlanPeriod({
    required String enrollmentId,
    required String periodKey,
  }) async {
    final res = await _functions.httpsCallable('issuePlanPeriod').call({
      'enrollmentId': enrollmentId,
      'periodKey': periodKey,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Settles rollover from a closed period into the next period with ledger entries.
  Future<Map<String, dynamic>> settlePlanRollover({
    required String enrollmentId,
    required String periodKey,
  }) async {
    final res = await _functions.httpsCallable('settlePlanRollover').call({
      'enrollmentId': enrollmentId,
      'periodKey': periodKey,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ---------------------------------------------------------------------------
  // Feature Flags, Campaigns & System Administration
  // ---------------------------------------------------------------------------

  Future<void> setGlobalFeatureFlags(Map<String, dynamic> flags) async {
    await _functions.httpsCallable('adminSetGlobalFeatureFlags').call({
      'flags': flags,
    });
  }

  Future<String> upsertCampaign({
    String? campaignId,
    required String title,
    required String type,
    Map<String, dynamic>? audience,
    Map<String, dynamic>? content,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'type': type,
    };
    if (campaignId != null) payload['campaignId'] = campaignId;
    if (audience != null) payload['audience'] = audience;
    if (content != null) payload['content'] = content;

    final res = await _functions.httpsCallable('adminUpsertCampaign').call(payload);
    return res.data['campaignId'] as String;
  }

  Future<void> transitionCampaign({
    required String campaignId,
    required String targetStatus,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'campaignId': campaignId,
      'targetStatus': targetStatus,
    };
    if (reason != null) payload['reason'] = reason;
    await _functions.httpsCallable('adminTransitionCampaign').call(payload);
  }

  Future<void> manageAdmin({
    required String uid,
    required List<String> capabilities,
    String status = 'active',
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'uid': uid,
      'capabilities': capabilities,
      'status': status,
    };
    if (reason != null) payload['reason'] = reason;
    await _functions.httpsCallable('adminManageAdmin').call(payload);
  }
}
