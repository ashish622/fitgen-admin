import 'package:fitgen_admin/core/widgets/confirm_dialog.dart';
import 'package:fitgen_admin/core/widgets/empty_state.dart';
import 'package:fitgen_admin/core/widgets/metric_card.dart';
import 'package:fitgen_admin/core/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatusBadge', () {
    testWidgets('renders active status with uppercase text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StatusBadge('active'))),
      );
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('renders custom label when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge('pending_verification', customLabel: 'Awaiting Review')),
        ),
      );
      expect(find.text('Awaiting Review'), findsOneWidget);
    });
  });

  group('MetricCard', () {
    testWidgets('displays title and value widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Total Users',
              value: Text('1,250'),
              subtitle: 'Updated just now',
              icon: Icons.people,
            ),
          ),
        ),
      );
      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('1,250'), findsOneWidget);
      expect(find.text('Updated just now'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('renders title, message, and action button', (tester) async {
      var clicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No Items Found',
              message: 'Try clearing your filters',
              actionLabel: 'Reset',
              onAction: () => clicked = true,
            ),
          ),
        ),
      );
      expect(find.text('No Items Found'), findsOneWidget);
      expect(find.text('Try clearing your filters'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      expect(clicked, isTrue);
    });
  });

  group('ConfirmDialog', () {
    testWidgets('renders dialog and cancels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ConfirmDialog.show(
                  context,
                  title: 'Block User',
                  message: 'Are you sure?',
                  requireReason: true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Block User'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Reason (required)'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Block User'), findsNothing);
    });
  });
}
