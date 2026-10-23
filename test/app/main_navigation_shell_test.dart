import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/app/main_navigation_shell.dart';
import 'package:myshopzy/shared/presentation/bottom_navigation_bar.dart';

void main() {
  testWidgets('main tabs switch without replacing the bottom navigation bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MainNavigationShell()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );

    await tester.tap(find.text('Orders'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Orders')).style?.color,
      const Color(0xFFFFC900),
    );

    await tester.tap(find.text('Categories'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Fresh items'), findsOneWidget);
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Cart'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('My Account'), findsOneWidget);
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
