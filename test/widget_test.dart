// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshopzy/app/myshopzy_app.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';

void main() {
  testWidgets('shows customer home delivery and search content on Home route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyShopzyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('30 mins'), findsOneWidget);
    expect(find.text('Choose your location'), findsOneWidget);
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-category-restaurants')),
      findsOneWidget,
    );
  });
}
