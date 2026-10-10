import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/help_support/presentation/help_support_page.dart';

void main() {
  testWidgets('contact support tiles paint on an interactive Material', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportPage()));
    await tester.scrollUntilVisible(
      find.text('Chat with Support'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);

    final supportAction = find.text('Chat with Support');
    final materials = tester
        .widgetList<Material>(
          find.ancestor(of: supportAction, matching: find.byType(Material)),
        )
        .toList();
    expect(materials.any((material) => material.color == Colors.white), isTrue);

    await tester.tap(supportAction);
    await tester.pumpAndSettle();
    expect(find.text('Support chat will be available soon'), findsOneWidget);
  });
}
