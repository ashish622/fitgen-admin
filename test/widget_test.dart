import 'package:fitgen_admin/features/users/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatusChip shows the status label', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StatusChip('blocked'))));
    expect(find.text('blocked'), findsOneWidget);
  });
}
