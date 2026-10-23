import 'package:fitgen_admin/core/admin_api.dart';
import 'package:fitgen_admin/features/partners/presentation/create_partner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CreatePartnerDialog renders fields and controls', (tester) async {
    final api = AdminApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreatePartnerDialog(api: api),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Onboard Partner Studio'), findsOneWidget);
    expect(find.text('Studio / Partner Name *'), findsOneWidget);
    expect(find.text('Timezone *'), findsOneWidget);
    expect(find.text('Country Code *'), findsOneWidget);
    expect(find.text('Create Studio'), findsOneWidget);
  });
}
