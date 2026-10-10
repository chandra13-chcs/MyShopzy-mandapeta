import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/bakery/presentation/bakery_page.dart';
import 'package:myshopzy/features/categories/presentation/categories_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurants_page.dart';
import 'package:myshopzy/features/search/presentation/search_page.dart';

void main() {
  const approvedCategories = [
    'Dairy, Bread & Eggs',
    'Fruits & Fresh Vegetables',
    'Cold Drinks & Juices',
    'Snacks & Munchies',
    'Breakfast & Instant Food',
    'Sweet Tooth & Chocolates',
    'Bakery & Biscuits',
    'Tea, Coffee & Milk Drinks',
    'Atta, Rice & Dal',
    'Masala, Cooking Oil & Ghee',
    'Sauces & Spreads',
    'Chicken, Meat & Fresh Fish',
    'Organic & Healthy Living',
    'Baby Care Essentials',
    'Pharma & Wellness',
    'Cleaning Essentials',
    'Home & Office Needs',
    'Personal Care & Hygiene',
  ];

  testWidgets('shows only the 18 approved client shopping categories', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    for (final category in approvedCategories) {
      await tester.scrollUntilVisible(
        find.text(category),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(category), findsOneWidget);
    }

    expect(find.text('Paan Corner & Refreshers'), findsNothing);
    expect(find.text('Pet Care Supplies'), findsNothing);

    await tester.ensureVisible(find.text('Pharma & Wellness'));
    await tester.tap(find.text('Pharma & Wellness'));
    await tester.pump();
    expect(
      find.text('This category catalogue is not available in the demo.'),
      findsOneWidget,
    );
  });

  testWidgets('existing service navigation remains available', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();
    expect(find.byType(RestaurantsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bakery').first);
    await tester.pumpAndSettle();
    expect(find.byType(BakeryPage), findsOneWidget);
  });

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

  testWidgets('category grid fits compact screens with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: const MaterialApp(home: CategoriesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Masala, Cooking Oil & Ghee'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
