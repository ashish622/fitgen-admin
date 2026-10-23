import 'package:fitgen_admin/core/admin_api.dart';
import 'package:fitgen_admin/features/plans/presentation/create_plan_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CreatePlanDialog renders plan fields and choices', (tester) async {
    final api = AdminApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreatePlanDialog(api: api),
              ),
              child: const Text('Open Plan Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Plan Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Create Studio Allowance Plan'), findsOneWidget);
    expect(find.text('Partner Studio *'), findsOneWidget);
    expect(find.text('Plan Name *'), findsOneWidget);
    expect(find.text('Plan ID (slug) *'), findsOneWidget);
    expect(find.text('Monthly Visit Allowance'), findsOneWidget);
    expect(find.text('4 Visits'), findsOneWidget);
    expect(find.text('8 Visits'), findsOneWidget);
    expect(find.text('Unlimited'), findsOneWidget);
    expect(find.text('Create Plan'), findsOneWidget);
  });
}
