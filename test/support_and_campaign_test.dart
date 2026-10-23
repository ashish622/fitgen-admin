import 'package:fitgen_admin/core/admin_api.dart';
import 'package:fitgen_admin/core/admin_session.dart';
import 'package:fitgen_admin/features/campaigns/presentation/campaigns_screen.dart';
import 'package:fitgen_admin/features/feature_flags/presentation/feature_flags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CampaignsScreen basic layout renders', (tester) async {
    final api = AdminApi();
    final session = AdminSession();

    await tester.pumpWidget(
      MaterialApp(
        home: CampaignsScreen(session: session, api: api),
      ),
    );

    expect(find.text('Campaigns & Marketing'), findsOneWidget);
    expect(find.text('Status: '), findsOneWidget);
  });

  testWidgets('FeatureFlagsScreen basic layout renders', (tester) async {
    final api = AdminApi();
    final session = AdminSession();

    await tester.pumpWidget(
      MaterialApp(
        home: FeatureFlagsScreen(session: session, api: api),
      ),
    );

    expect(find.text('Feature Flags & AI Governance'), findsOneWidget);
  });
}
