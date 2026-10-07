import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/categories/presentation/categories_page.dart';
import 'package:myshopzy/features/search/presentation/search_page.dart';

void main() {
  testWidgets('Categories search icon opens the existing SearchPage', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    await tester.tap(find.byTooltip('Search categories'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsOneWidget);
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );
  });
}
