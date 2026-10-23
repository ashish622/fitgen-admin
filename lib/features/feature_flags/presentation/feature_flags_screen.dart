import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/admin_api.dart';
import '../../../core/admin_session.dart';
import '../../../core/widgets/confirm_dialog.dart';

class FeatureFlagsScreen extends StatefulWidget {
  const FeatureFlagsScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  State<FeatureFlagsScreen> createState() => _FeatureFlagsScreenState();
}

class _FeatureFlagsScreenState extends State<FeatureFlagsScreen> {
  bool _busy = false;

  static const _features = [
    ('fg_coach', 'FG Coach Living Plans', 'Personalized adaptive workout and nutrition generation with AI voice/chat guidance.'),
    ('future_you_studio', 'Future-You Studio 3D Projections', '3D visual progression models projected from user workout volume and body measurements.'),
    ('ai_partner_search', 'AI-Powered Workout Partner Matching', 'Vector embedding search matching users by routine, gym location, and fitness goals.'),
    ('fit_squad', 'FitSquad Group Training', 'Social fitness squads with leaderboards and collective milestone tracking.'),
    ('challenges', 'Community Fitness Challenges', 'Time-bound fitness quests with automated reward distribution and badges.'),
    ('mentor_booking', '1-on-1 Mentor & Trainer Sessions', 'Direct video consultations with verified personal trainers and certified mentors.'),
    ('fit_classes', 'Partner Studio Classes', 'Discovery and attendance booking across verified Phoenix partner gym networks.'),
  ];

  Future<void> _updateFeature(
    Map<String, dynamic> currentFlags,
    String featureKey,
    Map<String, dynamic> updatedProperties,
  ) async {
    final next = Map<String, dynamic>.from(currentFlags);
    final feat = Map<String, dynamic>.from((next[featureKey] as Map<String, dynamic>?) ?? {});
    feat.addAll(updatedProperties);
    next[featureKey] = feat;

    setState(() => _busy = true);
    try {
      await widget.api.setGlobalFeatureFlags(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated $featureKey')),
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

  Future<void> _triggerAiEmergencyKillswitch(bool turnOff) async {
    final res = await ConfirmDialog.show(
      context,
      title: turnOff ? 'EMERGENCY: Kill All AI Model Calls' : 'Restore AI Operations',
      message: turnOff
          ? 'This will immediately disconnect all external AI calls (Gemini/OpenAI) across the entire platform. Member plan generation and chat will stop.'
          : 'Re-enable AI model call services across all member endpoints?',
      confirmLabel: turnOff ? 'ACTIVATE KILLSWITCH' : 'Restore AI',
      isDestructive: turnOff,
      requireReason: true,
      reasonHint: 'e.g. Excessive token consumption or upstream API degradation',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('appConfig').doc('featureFlags').get();
      final current = (doc.data()?['features'] as Map<String, dynamic>?) ?? {};
      await _updateFeature(current, 'fg_coach', {'killswitch': turnOff});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.session.canAny([Cap.featuresManage, Cap.aiConfiguration]);

    final stream = Firebase.apps.isEmpty
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance.collection('appConfig').doc('featureFlags').snapshots();

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final data = snap.data?.data();
          final featuresMap = (data?['features'] as Map<String, dynamic>?) ?? {};
          final isAiKilled = featuresMap['fg_coach']?['killswitch'] == true;

          return ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Feature Flags & AI Governance', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Control global feature releases, rollout percentages, plan tier defaults, and AI killswitches.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (canManage)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: isAiKilled ? Colors.green : Colors.red.shade700),
                      icon: Icon(isAiKilled ? Icons.play_arrow : Icons.emergency),
                      label: Text(isAiKilled ? 'Restore AI Services' : 'Emergency AI Killswitch'),
                      onPressed: _busy ? null : () => _triggerAiEmergencyKillswitch(!isAiKilled),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // AI Status Card
              Card(
                elevation: 0,
                color: isAiKilled ? Colors.red.shade50 : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isAiKilled ? Colors.red : theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(isAiKilled ? Icons.gpp_bad : Icons.verified_user, color: isAiKilled ? Colors.red : Colors.green, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAiKilled ? 'AI Services Disconnected (Emergency Killswitch Active)' : 'AI Model Pipeline Operational',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isAiKilled ? Colors.red.shade900 : null),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAiKilled
                                  ? 'All FG Coach generative calls are failing closed. Members receive safe maintenance messages.'
                                  : 'Gemini 2.5 Flash active for living workout rebalances and multimodal exercise forms.',
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text('Global Feature Matrix', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _features.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final (key, title, desc) = _features[index];
                    final feat = (featuresMap[key] as Map<String, dynamic>?) ?? {};
                    final isEnabled = feat['enabled'] != false;
                    final rolloutPct = (feat['rolloutPct'] as num?)?.toInt() ?? 100;
                    final freeAllowed = (feat['plans'] as List?)?.contains('free') ?? true;
                    final proAllowed = (feat['plans'] as List?)?.contains('pro') ?? true;

                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isEnabled ? Colors.green.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isEnabled ? 'ACTIVE ($rolloutPct%)' : 'DISABLED',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isEnabled ? Colors.green.shade800 : Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(desc, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isEnabled,
                                onChanged: canManage
                                    ? (val) => _updateFeature(featuresMap, key, {'enabled': val})
                                    : null,
                              ),
                            ],
                          ),
                          if (isEnabled) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                SizedBox(
                                  width: 220,
                                  child: Text('Rollout Percentage: $rolloutPct%', style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: rolloutPct.toDouble(),
                                    min: 0,
                                    max: 100,
                                    divisions: 20,
                                    label: '$rolloutPct%',
                                    onChanged: canManage
                                        ? (v) => _updateFeature(featuresMap, key, {'rolloutPct': v.toInt()})
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const Text('Enabled on Membership Tiers:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                FilterChip(
                                  label: const Text('Free Tier'),
                                  selected: freeAllowed,
                                  onSelected: canManage
                                      ? (sel) {
                                          final currentPlans = List<String>.from((feat['plans'] as List?) ?? ['free', 'pro']);
                                          if (sel) {
                                            currentPlans.add('free');
                                          } else {
                                            currentPlans.remove('free');
                                          }
                                          _updateFeature(featuresMap, key, {'plans': currentPlans.toSet().toList()});
                                        }
                                      : null,
                                ),
                                FilterChip(
                                  label: const Text('FitGen Pro'),
                                  selected: proAllowed,
                                  onSelected: canManage
                                      ? (sel) {
                                          final currentPlans = List<String>.from((feat['plans'] as List?) ?? ['free', 'pro']);
                                          if (sel) {
                                            currentPlans.add('pro');
                                          } else {
                                            currentPlans.remove('pro');
                                          }
                                          _updateFeature(featuresMap, key, {'plans': currentPlans.toSet().toList()});
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
