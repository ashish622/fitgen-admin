import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/admin_api.dart';
import '../../../core/admin_session.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);
  String _campaignStatusFilter = 'all';
  bool _busy = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // CAMPAIGNS TAB ACTIONS
  // ===========================================================================

  Future<void> _openCreateCampaignDialog() async {
    final titleCtl = TextEditingController();
    final messageCtl = TextEditingController();
    final couponCtl = TextEditingController();
    String type = 'push_announcement';
    String audience = 'all';
    bool autoBanner = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Create New Campaign'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Campaign Title *',
                      hintText: 'e.g. November Consistency Challenge',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Campaign Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'push_announcement',
                          child: Text('FCM Push Broadcast')),
                      DropdownMenuItem(
                          value: 'promo_coupon',
                          child: Text('Promo Coins / Coupon Drop')),
                      DropdownMenuItem(
                          value: 'challenge',
                          child: Text('Gamified Fitness Challenge')),
                      DropdownMenuItem(
                          value: 'in_app_banner',
                          child: Text('In-App Home Banner')),
                    ],
                    onChanged: (v) => setS(() {
                      type = v ?? 'push_announcement';
                      if (type == 'in_app_banner') autoBanner = true;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    decoration:
                        const InputDecoration(labelText: 'Target Audience'),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Registered Users')),
                      DropdownMenuItem(
                          value: 'pro', child: Text('FitGen Pro Members Only')),
                      DropdownMenuItem(
                          value: 'inactive_14d',
                          child: Text('Inactive > 14 Days')),
                      DropdownMenuItem(
                          value: 'trial', child: Text('Free Tier Members')),
                    ],
                    onChanged: (v) => setS(() => audience = v ?? 'all'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtl,
                    decoration: const InputDecoration(
                      labelText: 'Headline & Copy *',
                      hintText: 'Enter announcement or reward copy...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  if (type == 'promo_coupon') ...[
                    TextField(
                      controller: couponCtl,
                      decoration: const InputDecoration(
                        labelText: 'Linked Coupon Code (Optional)',
                        hintText: 'e.g. NOV25',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    title: const Text('Auto-sync as Special Home Banner'),
                    subtitle: const Text(
                        'Automatically displays a banner on the app home screen while live'),
                    value: autoBanner,
                    onChanged: (v) => setS(() => autoBanner = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtl.text.trim().isEmpty ||
                    messageCtl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Create Draft'),
            ),
          ],
        ),
      ),
    );

    if (created != true) return;
    setState(() => _busy = true);
    try {
      await widget.api.upsertCampaign(
        title: titleCtl.text.trim(),
        type: type,
        audience: {'target': audience},
        content: {'message': messageCtl.text.trim()},
        reward: couponCtl.text.trim().isNotEmpty
            ? {'couponCode': couponCtl.text.trim().toUpperCase()}
            : null,
        autoCreateBanner: autoBanner,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign created in draft status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transitionCampaign(
      String campaignId, String targetStatus) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Transition Campaign',
      message: 'Change campaign status to ${targetStatus.toUpperCase()}?',
      confirmLabel: 'Confirm',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.transitionCampaign(
        campaignId: campaignId,
        targetStatus: targetStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign is now $targetStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ===========================================================================
  // COUPONS TAB ACTIONS
  // ===========================================================================

  Future<void> _openUpsertCouponDialog([Map<String, dynamic>? initial]) async {
    final codeCtl =
        TextEditingController(text: initial?['code']?.toString() ?? '');
    final titleCtl =
        TextEditingController(text: initial?['title']?.toString() ?? '');
    final descCtl =
        TextEditingController(text: initial?['description']?.toString() ?? '');
    final valueCtl = TextEditingController(
        text: (initial?['value'] ?? initial?['coins'] ?? 25).toString());
    final maxRedeemCtl = TextEditingController(
        text: initial?['maxRedemptions']?.toString() ?? '100');
    String type = initial?['type'] ?? 'coins';
    bool active = initial?['active'] ?? true;
    final isEdit = initial != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? 'Edit Coupon' : 'Create New Coupon'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeCtl,
                    readOnly: isEdit,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Coupon Code *',
                      hintText: 'e.g. FESTIVE50',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Title / Promotion Name',
                      hintText: 'e.g. Diwali 50 Coins Bonus',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'coins', child: Text('Coins Grant')),
                            DropdownMenuItem(
                                value: 'percent',
                                child: Text('Percentage Discount')),
                          ],
                          onChanged: (v) => setS(() => type = v ?? 'coins'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: valueCtl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                type == 'coins' ? 'Coin Amount *' : 'Discount % *',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxRedeemCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Redemptions (Total Cap)',
                      hintText: 'e.g. 500',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(
                      labelText: 'Description / Terms',
                      hintText: 'Valid for mentor sessions & living plans',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Active for Redemption'),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (codeCtl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Coupon'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    setState(() => _busy = true);
    try {
      final code = codeCtl.text.trim().toUpperCase();
      final val = num.tryParse(valueCtl.text.trim()) ?? 10;
      final maxR = int.tryParse(maxRedeemCtl.text.trim());

      await widget.api.upsertCoupon(
        couponId: initial?['id'] ?? code,
        code: code,
        title: titleCtl.text.trim(),
        description: descCtl.text.trim(),
        type: type,
        value: val,
        maxRedemptions: maxR,
        active: active,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coupon $code saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCoupon(String couponId, String code) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Delete Coupon',
      message: 'Permanently remove coupon "$code"? Existing claims will be kept in user ledger.',
      confirmLabel: 'Delete',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteCoupon(couponId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coupon $code deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ===========================================================================
  // HOME BANNERS (SPECIAL ANNOUNCEMENTS) TAB ACTIONS
  // ===========================================================================

  Future<void> _openUpsertBannerDialog(
      [Map<String, dynamic>? initial]) async {
    final titleCtl =
        TextEditingController(text: initial?['title']?.toString() ?? '');
    final msgCtl =
        TextEditingController(text: initial?['message']?.toString() ?? '');
    final badgeCtl = TextEditingController(
        text: initial?['badgeText']?.toString() ?? 'SPECIAL ANNOUNCEMENT');
    final ctaCtl =
        TextEditingController(text: initial?['ctaText']?.toString() ?? 'Explore Now');
    final linkCtl =
        TextEditingController(text: initial?['deepLink']?.toString() ?? '/challenges');
    final priorityCtl = TextEditingController(
        text: (initial?['priority'] ?? 10).toString());
    String style = initial?['style'] ?? 'purple_gradient';
    String audience = initial?['audience'] ?? 'all';
    bool active = initial?['active'] ?? true;
    bool dismissible = initial?['dismissible'] ?? true;
    bool sendPush = false;
    final isEdit = initial != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit
              ? 'Edit Special Announcement Banner'
              : 'New Special Announcement Banner'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This banner is displayed at the top of the mobile home screen ONLY when active. When deactivated or expired, nothing is shown.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtl,
                    onChanged: (_) => setS(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Banner Headline *',
                      hintText: 'e.g. 🎉 Diwali Fitness Challenge Live!',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msgCtl,
                    onChanged: (_) => setS(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Announcement Message *',
                      hintText:
                          'Join a 7-day squad streak and earn exclusive rewards.',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: badgeCtl,
                          onChanged: (_) => setS(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Badge Tag',
                            hintText: 'e.g. SPECIAL ANNOUNCEMENT',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: style,
                          decoration: const InputDecoration(labelText: 'Visual Style'),
                          items: const [
                            DropdownMenuItem(
                                value: 'purple_gradient',
                                child: Text('Purple Gradient')),
                            DropdownMenuItem(
                                value: 'amber_spotlight',
                                child: Text('Amber Spotlight')),
                            DropdownMenuItem(
                                value: 'emerald_promo',
                                child: Text('Emerald Promo')),
                            DropdownMenuItem(
                                value: 'minimal_card',
                                child: Text('Minimal Light')),
                          ],
                          onChanged: (v) =>
                              setS(() => style = v ?? 'purple_gradient'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctaCtl,
                          onChanged: (_) => setS(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Action Button Label',
                            hintText: 'e.g. Join Now',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: linkCtl.text.isEmpty
                              ? '/challenges'
                              : linkCtl.text,
                          decoration:
                              const InputDecoration(labelText: 'Destination Route'),
                          items: const [
                            DropdownMenuItem(
                                value: '/challenges', child: Text('Challenges')),
                            DropdownMenuItem(
                                value: '/subscription',
                                child: Text('FitGen Pro Upgrade')),
                            DropdownMenuItem(
                                value: '/credits-purchase',
                                child: Text('Buy Credits / Coins')),
                            DropdownMenuItem(
                                value: '/fit-squad', child: Text('FitSquad')),
                            DropdownMenuItem(
                                value: '/future-library',
                                child: Text('Future You')),
                          ],
                          onChanged: (v) => setS(() => linkCtl.text = v ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: audience,
                          decoration: const InputDecoration(labelText: 'Audience'),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All Members')),
                            DropdownMenuItem(
                                value: 'free',
                                child: Text('Free Tier Members Only')),
                            DropdownMenuItem(
                                value: 'pro',
                                child: Text('FitGen Pro Members Only')),
                          ],
                          onChanged: (v) => setS(() => audience = v ?? 'all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priorityCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Priority (Higher = Top)',
                            hintText: '10',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Live Mobile Preview:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildBannerPreviewBox(
                    title: titleCtl.text.isEmpty
                        ? 'Headline Preview'
                        : titleCtl.text,
                    message: msgCtl.text.isEmpty
                        ? 'Announcement text will appear here.'
                        : msgCtl.text,
                    badgeText: badgeCtl.text,
                    ctaText: ctaCtl.text,
                    style: style,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show on Home Screen (Active)'),
                    subtitle: const Text(
                        'Turn off to immediately hide from mobile home screen'),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Allow User Dismissal (X button)'),
                    value: dismissible,
                    onChanged: (v) => setS(() => dismissible = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!isEdit)
                    SwitchListTile(
                      title: const Text('Also broadcast FCM Push Notification'),
                      subtitle: const Text(
                          'Sends push alert to topic "announcements" upon creation'),
                      value: sendPush,
                      onChanged: (v) => setS(() => sendPush = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtl.text.trim().isEmpty ||
                    msgCtl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: Text(isEdit ? 'Save Banner' : 'Publish Banner'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    setState(() => _busy = true);
    try {
      final pri = int.tryParse(priorityCtl.text.trim()) ?? 0;
      await widget.api.upsertAnnouncement(
        announcementId: initial?['id'],
        title: titleCtl.text.trim(),
        message: msgCtl.text.trim(),
        badgeText: badgeCtl.text.trim(),
        style: style,
        ctaText: ctaCtl.text.trim(),
        deepLink: linkCtl.text.trim(),
        audience: audience,
        priority: pri,
        active: active,
        dismissible: dismissible,
        sendPush: sendPush,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home banner updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBanner(String id, String title) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Delete Home Banner',
      message: 'Remove banner "$title" permanently from announcements?',
      confirmLabel: 'Delete',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteAnnouncement(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildBannerPreviewBox({
    required String title,
    required String message,
    required String badgeText,
    required String ctaText,
    required String style,
  }) {
    Color bg1;
    Color bg2;
    Color textColor = Colors.white;
    Color badgeBg = Colors.white.withValues(alpha: 0.25);
    Color ctaBg = Colors.white;
    Color ctaTextColor = Colors.black87;

    switch (style) {
      case 'amber_spotlight':
        bg1 = const Color(0xFFD97706);
        bg2 = const Color(0xFFB45309);
        break;
      case 'emerald_promo':
        bg1 = const Color(0xFF059669);
        bg2 = const Color(0xFF047857);
        break;
      case 'minimal_card':
        bg1 = const Color(0xFFF3F4F6);
        bg2 = const Color(0xFFE5E7EB);
        textColor = const Color(0xFF1F2937);
        badgeBg = const Color(0xFFD1D5DB);
        ctaBg = const Color(0xFF4F46E5);
        ctaTextColor = Colors.white;
        break;
      case 'purple_gradient':
      default:
        bg1 = const Color(0xFF6B21A8);
        bg2 = const Color(0xFF4C1D95);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bg1, bg2]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: bg1.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Icon(Icons.close, size: 16, color: textColor.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
                color: textColor.withValues(alpha: 0.9), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ctaBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ctaText,
              style: TextStyle(
                  color: ctaTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.session.can(Cap.campaignsManage);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Campaigns & Marketing',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Coordinate promotional campaigns, discount coupon codes, and special announcement home banners.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (canManage) ...[
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_tabController.index == 0) {
                              _openCreateCampaignDialog();
                            } else if (_tabController.index == 1) {
                              _openUpsertCouponDialog();
                            } else {
                              _openUpsertBannerDialog();
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: Text(_tabController.index == 0
                        ? 'New Campaign'
                        : (_tabController.index == 1
                            ? 'New Coupon'
                            : 'New Home Banner')),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(icon: Icon(Icons.campaign_outlined), text: 'Campaigns'),
                Tab(
                    icon: Icon(Icons.confirmation_number_outlined),
                    text: 'Coupons & Promo Codes'),
                Tab(
                    icon: Icon(Icons.announcement_outlined),
                    text: 'Home Banners (Announcements)'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCampaignsTab(),
                  _buildCouponsTab(),
                  _buildHomeBannersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: CAMPAIGNS
  // ===========================================================================

  Widget _buildCampaignsTab() {
    final theme = Theme.of(context);
    final canManage = widget.session.can(Cap.campaignsManage);

    Stream<QuerySnapshot<Map<String, dynamic>>> queryStream;
    if (Firebase.apps.isEmpty) {
      queryStream = const Stream.empty();
    } else {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('campaigns');
      if (_campaignStatusFilter != 'all') {
        q = q.where('status', isEqualTo: _campaignStatusFilter);
      }
      queryStream = q.snapshots();
    }

    return Column(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _campaignStatusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('All Campaigns')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                        value: 'pending_approval',
                        child: Text('Pending Approval')),
                    DropdownMenuItem(
                        value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(
                        value: 'live', child: Text('Live / Active')),
                    DropdownMenuItem(value: 'ended', child: Text('Ended')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _campaignStatusFilter = v);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: queryStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return EmptyState(
                  title: 'No Campaigns Found',
                  message:
                      'Create a campaign to engage users with push alerts, bonuses, or challenges.',
                  icon: Icons.campaign_outlined,
                  actionLabel: canManage ? 'Create First Campaign' : null,
                  onAction: canManage ? _openCreateCampaignDialog : null,
                );
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color:
                          theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data();
                    final title = d['title'] ?? 'Campaign';
                    final status = d['status'] ?? 'draft';
                    final type = d['type'] ?? 'push_announcement';
                    final audience =
                        (d['audience'] as Map<String, dynamic>?)?['target'] ??
                            'all';
                    final content =
                        (d['content'] as Map<String, dynamic>?)?['message'] ??
                            '';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor: status == 'live'
                            ? Colors.green.shade100
                            : Colors.indigo.shade100,
                        foregroundColor: status == 'live'
                            ? Colors.green.shade900
                            : Colors.indigo.shade900,
                        child: Icon(status == 'live'
                            ? Icons.sensors
                            : Icons.campaign),
                      ),
                      title: Row(
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 10),
                          StatusBadge(status),
                          const SizedBox(width: 8),
                          Chip(
                              label: Text(type.replaceAll('_', ' ').toUpperCase()),
                              visualDensity: VisualDensity.compact),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Target: $audience  •  $content',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: theme.colorScheme.outline, fontSize: 13),
                        ),
                      ),
                      trailing: canManage
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'draft')
                                  FilledButton.tonal(
                                    onPressed: _busy
                                        ? null
                                        : () => _transitionCampaign(
                                            doc.id, 'pending_approval'),
                                    child: const Text('Submit Approval'),
                                  )
                                else if (status == 'pending_approval')
                                  FilledButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _transitionCampaign(
                                            doc.id, 'approved'),
                                    child: const Text('Approve'),
                                  )
                                else if (status == 'approved')
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green),
                                    onPressed: _busy
                                        ? null
                                        : () => _transitionCampaign(
                                            doc.id, 'live'),
                                    child: const Text('Launch Live'),
                                  )
                                else if (status == 'live')
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _transitionCampaign(
                                            doc.id, 'ended'),
                                    child: const Text('End Campaign'),
                                  ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: COUPONS & PROMO CODES
  // ===========================================================================

  Widget _buildCouponsTab() {
    final theme = Theme.of(context);
    final canManage = widget.session.can(Cap.campaignsManage);

    final stream = Firebase.apps.isEmpty
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance.collection('coupons').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return EmptyState(
            title: 'No Coupons Found',
            message:
                'Create discount codes or bonus coins coupons to reward users and drive retention.',
            icon: Icons.confirmation_number_outlined,
            actionLabel: canManage ? 'Create First Coupon' : null,
            onAction: canManage ? _openUpsertCouponDialog : null,
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              final code = d['code'] ?? doc.id;
              final title = d['title'] ?? code;
              final type = d['type'] ?? 'coins';
              final value = d['value'] ?? d['coins'] ?? 10;
              final active = d['active'] != false;
              final redemptions = (d['redemptionCount'] as num?)?.toInt() ??
                  (d['userId'] as List?)?.length ??
                  0;
              final maxR = (d['maxRedemptions'] as num?)?.toInt();
              final isDepleted = maxR != null && redemptions >= maxR;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: active
                      ? (isDepleted
                          ? Colors.orange.shade100
                          : Colors.purple.shade100)
                      : Colors.grey.shade200,
                  foregroundColor: active
                      ? (isDepleted
                          ? Colors.orange.shade900
                          : Colors.purple.shade900)
                      : Colors.grey.shade600,
                  child: const Icon(Icons.confirmation_number),
                ),
                title: Row(
                  children: [
                    Text(code,
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(width: 10),
                    StatusBadge(active
                        ? (isDepleted ? 'exhausted' : 'active')
                        : 'inactive'),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                          type == 'coins' ? '$value COINS' : '$value% OFF'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$title  •  Redeemed: $redemptions ${maxR != null ? "/ $maxR" : ""}',
                    style: TextStyle(
                        color: theme.colorScheme.outline, fontSize: 13),
                  ),
                ),
                trailing: canManage
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit Coupon',
                            onPressed: () => _openUpsertCouponDialog({
                              'id': doc.id,
                              ...d,
                            }),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            tooltip: 'Delete Coupon',
                            onPressed: () => _deleteCoupon(doc.id, code),
                          ),
                        ],
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: HOME BANNERS (SPECIAL ANNOUNCEMENTS)
  // ===========================================================================

  Widget _buildHomeBannersTab() {
    final theme = Theme.of(context);
    final canManage = widget.session.can(Cap.campaignsManage);

    final stream = Firebase.apps.isEmpty
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('priority', descending: true)
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return EmptyState(
            title: 'No Home Banners Configured',
            message:
                'Create special announcement banners to highlight festive offers, new challenges, or critical notices directly on the mobile home screen.',
            icon: Icons.announcement_outlined,
            actionLabel: canManage ? 'Create First Banner' : null,
            onAction: canManage ? _openUpsertBannerDialog : null,
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data();
            final title = d['title'] ?? 'Special Announcement';
            final message = d['message'] ?? '';
            final badgeText = d['badgeText'] ?? 'SPECIAL ANNOUNCEMENT';
            final ctaText = d['ctaText'] ?? 'Explore Now';
            final style = d['style'] ?? 'purple_gradient';
            final active = d['active'] != false;
            final audience = d['audience'] ?? 'all';
            final priority = d['priority'] ?? 0;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: active
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: active ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mini live preview box
                    SizedBox(
                      width: 320,
                      child: _buildBannerPreviewBox(
                        title: title,
                        message: message,
                        badgeText: badgeText,
                        ctaText: ctaText,
                        style: style,
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Controls and details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              const SizedBox(width: 10),
                              StatusBadge(active ? 'active' : 'inactive',
                                  customLabel: active ? 'LIVE ON HOME' : 'OFF'),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('Audience: $audience'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Chip(
                                avatar: const Icon(Icons.palette_outlined, size: 16),
                                label: Text('Style: $style'),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                avatar: const Icon(Icons.alt_route, size: 16),
                                label: Text('Route: ${d["deepLink"] ?? "None"}'),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                avatar: const Icon(Icons.low_priority, size: 16),
                                label: Text('Priority: $priority'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (canManage) ...[
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Edit Banner'),
                                  onPressed: () => _openUpsertBannerDialog({
                                    'id': doc.id,
                                    ...d,
                                  }),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.tonalIcon(
                                  icon: Icon(
                                      active ? Icons.visibility_off : Icons.visibility,
                                      size: 16),
                                  label: Text(active
                                      ? 'Turn Off Banner'
                                      : 'Make Live on Home'),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          setState(() => _busy = true);
                                          try {
                                            await widget.api.upsertAnnouncement(
                                              announcementId: doc.id,
                                              title: title,
                                              message: message,
                                              badgeText: badgeText,
                                              style: style,
                                              ctaText: ctaText,
                                              deepLink: d['deepLink'],
                                              audience: audience,
                                              priority: priority,
                                              active: !active,
                                              dismissible: d['dismissible'] != false,
                                            );
                                          } finally {
                                            if (mounted) {
                                              setState(() => _busy = false);
                                            }
                                          }
                                        },
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  tooltip: 'Delete Banner',
                                  onPressed: () => _deleteBanner(doc.id, title),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
