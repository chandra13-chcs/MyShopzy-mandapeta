import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/app/myshopzy_app.dart';

void main() {
  testWidgets('shows offline dialog over the home screen and closes with X', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyShopzyApp(clock: () => DateTime(2026, 10, 23, 6, 59)),
    );
    await tester.pump();

    expect(find.text('We are currently offline'), findsOneWidget);
    expect(
      find.text(
        'Our store hours are 7:00 AM – 11:00 PM. You can still browse '
        'products, add items to cart, and order during operating hours!',
      ),
      findsOneWidget,
    );
    expect(find.text('Explore Products'), findsOneWidget);
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('offline-dialog-close')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('We are currently offline'), findsNothing);
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explore Products dismisses the offline dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyShopzyApp(clock: () => DateTime(2026, 10, 23, 23)),
    );
    await tester.pump();

    expect(find.text('We are currently offline'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('offline-dialog-explore')),
    );
    await tester.tap(find.byKey(const ValueKey('offline-dialog-explore')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('We are currently offline'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final time in [
    DateTime(2026, 10, 23, 7),
    DateTime(2026, 10, 23, 22, 59),
  ]) {
    testWidgets('keeps offline dialog hidden at ${time.hour}:${time.minute}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MyShopzyApp(clock: () => time));
      await tester.pump();

      expect(find.text('We are currently offline'), findsNothing);
      expect(
        find.text('Search restaurants, groceries, products...'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
