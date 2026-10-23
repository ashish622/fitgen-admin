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
  // Feature Flags, Campaigns, Coupons, Announcements & Catalog
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
    Map<String, dynamic>? reward,
    Map<String, dynamic>? schedule,
    bool autoCreateBanner = false,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'type': type,
      'autoCreateBanner': autoCreateBanner,
    };
    if (campaignId != null) payload['campaignId'] = campaignId;
    if (audience != null) payload['audience'] = audience;
    if (content != null) payload['content'] = content;
    if (reward != null) payload['reward'] = reward;
    if (schedule != null) payload['schedule'] = schedule;

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

  Future<String> upsertCoupon({
    String? couponId,
    required String code,
    String? title,
    String? description,
    String type = 'coins',
    required num value,
    int? maxRedemptions,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool active = true,
    List<String>? applicableTo,
    String? campaignId,
  }) async {
    final payload = <String, dynamic>{
      'code': code,
      'type': type,
      'value': value,
      'active': active,
    };
    if (couponId != null) payload['couponId'] = couponId;
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (maxRedemptions != null) payload['maxRedemptions'] = maxRedemptions;
    if (startsAt != null) payload['startsAtMs'] = startsAt.millisecondsSinceEpoch;
    if (expiresAt != null) payload['expiresAtMs'] = expiresAt.millisecondsSinceEpoch;
    if (applicableTo != null) payload['applicableTo'] = applicableTo;
    if (campaignId != null) payload['campaignId'] = campaignId;

    final res = await _functions.httpsCallable('adminUpsertCoupon').call(payload);
    return (res.data['couponId'] ?? code) as String;
  }

  Future<void> deleteCoupon(String couponId, {String? reason}) async {
    final payload = <String, dynamic>{'couponId': couponId};
    if (reason != null) payload['reason'] = reason;
    await _functions.httpsCallable('adminDeleteCoupon').call(payload);
  }

  Future<String> upsertAnnouncement({
    String? announcementId,
    required String title,
    required String message,
    String badgeText = 'SPECIAL ANNOUNCEMENT',
    String style = 'purple_gradient',
    String? imageUrl,
    String? ctaText,
    String? deepLink,
    String audience = 'all',
    bool active = true,
    bool dismissible = true,
    bool sendPush = false,
    int priority = 0,
    DateTime? startsAt,
    DateTime? expiresAt,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'message': message,
      'badgeText': badgeText,
      'style': style,
      'audience': audience,
      'active': active,
      'dismissible': dismissible,
      'sendPush': sendPush,
      'priority': priority,
    };
    if (announcementId != null) payload['announcementId'] = announcementId;
    if (imageUrl != null) payload['imageUrl'] = imageUrl;
    if (ctaText != null) payload['ctaText'] = ctaText;
    if (deepLink != null) payload['deepLink'] = deepLink;
    if (startsAt != null) payload['startsAtMs'] = startsAt.millisecondsSinceEpoch;
    if (expiresAt != null) payload['expiresAtMs'] = expiresAt.millisecondsSinceEpoch;

    final res = await _functions.httpsCallable('adminUpsertAnnouncement').call(payload);
    return res.data['announcementId'] as String;
  }

  Future<void> deleteAnnouncement(String announcementId, {String? reason}) async {
    final payload = <String, dynamic>{'announcementId': announcementId};
    if (reason != null) payload['reason'] = reason;
    await _functions.httpsCallable('adminDeleteAnnouncement').call(payload);
  }

  Future<void> upsertSubscriptionPlan({
    required String planId,
    required String title,
    String subtitle = '',
    String description = '',
    String billingPeriod = 'monthly',
    required String iosProductId,
    required String androidProductId,
    String fallbackPriceDisplay = '',
    List<String> features = const [],
    String? badgeText,
    bool isHighlighted = false,
    int sortOrder = 0,
    bool active = true,
  }) async {
    await _functions.httpsCallable('adminUpsertSubscriptionPlan').call({
      'planId': planId,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'billingPeriod': billingPeriod,
      'iosProductId': iosProductId,
      'androidProductId': androidProductId,
      'fallbackPriceDisplay': fallbackPriceDisplay,
      'features': features,
      'badgeText': badgeText,
      'isHighlighted': isHighlighted,
      'sortOrder': sortOrder,
      'active': active,
    });
  }

  Future<void> deleteSubscriptionPlan(String planId) async {
    await _functions.httpsCallable('adminDeleteSubscriptionPlan').call({
      'planId': planId,
    });
  }

  Future<void> upsertCoinPlan({
    required String planId,
    required String title,
    String description = '',
    required int coins,
    int bonusCoins = 0,
    required String iosProductId,
    required String androidProductId,
    String fallbackPriceDisplay = '',
    String? badgeText,
    bool isPopular = false,
    int sortOrder = 0,
    bool active = true,
  }) async {
    await _functions.httpsCallable('adminUpsertCoinPlan').call({
      'planId': planId,
      'title': title,
      'description': description,
      'coins': coins,
      'bonusCoins': bonusCoins,
      'iosProductId': iosProductId,
      'androidProductId': androidProductId,
      'fallbackPriceDisplay': fallbackPriceDisplay,
      'badgeText': badgeText,
      'isPopular': isPopular,
      'sortOrder': sortOrder,
      'active': active,
    });
  }

  Future<void> deleteCoinPlan(String planId) async {
    await _functions.httpsCallable('adminDeleteCoinPlan').call({
      'planId': planId,
    });
  }

  Future<Map<String, dynamic>> seedDefaultCatalog() async {
    final res = await _functions.httpsCallable('adminSeedDefaultCatalog').call();
    return Map<String, dynamic>.from(res.data as Map);
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
