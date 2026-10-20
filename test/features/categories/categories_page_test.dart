import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/bakery/presentation/bakery_page.dart';
import 'package:myshopzy/features/categories/presentation/categories_page.dart';
import 'package:myshopzy/features/search/presentation/search_page.dart';

void main() {
  const approvedCategories = [
    'Fresh Vegetables',
    'Fresh Fruits',
    'Dairy, Bread and Eggs',
    'Meat and Seafood',
    'Atta, Rice and Dal',
    'Masalas',
    'Oils and Ghee',
    'Cereals and Breakfast',
    'Cold Drinks and Juices',
    'Ice Creams and Frozen Foods',
    'Chips and Namkeens',
    'Chocolates',
    'Biscuits and Cakes',
    'Tea, Coffee and Milk Drinks',
    'Sauces and Spreads',
    'Sweet Corner',
    'Noodles, Pasta, Vermicelli',
    'Frozen Food',
    'Dry Fruits and Seeds Mix',
  ];

  testWidgets('shows requested categories in the requested sections', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    expect(find.text('Fresh items'), findsOneWidget);

    for (final category in approvedCategories) {
      final categoryFinder = category == 'Home Needs'
          ? find.text(category).last
          : find.text(category);
      await tester.scrollUntilVisible(
        categoryFinder,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(categoryFinder, findsOneWidget);
    }

    expect(find.text('Paan Corner'), findsNothing);
    expect(find.text('Cold Drinks & Juices'), findsNothing);
    expect(find.text('Home & Office Needs'), findsNothing);
    expect(find.text('Home Needs'), findsNothing);
    expect(find.text('Shop by Store'), findsNothing);
  });

  testWidgets('category listing navigation remains available', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    await tester.scrollUntilVisible(
      find.text('Chocolates'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Chocolates'));
    final chocolateTile = find.ancestor(
      of: find.text('Chocolates'),
      matching: find.byType(GestureDetector),
    );
    await tester.tapAt(
      tester.getTopLeft(chocolateTile.first) + const Offset(30, 30),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BakeryPage), findsOneWidget);
  });

  testWidgets('Categories search bar opens the existing SearchPage', (
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

    final firstTileImage = tester.getRect(find.byType(Image).first);
    final firstTileLabel = tester.getRect(find.text('Fresh Vegetables'));
    expect(firstTileLabel.top, greaterThanOrEqualTo(firstTileImage.bottom));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Masalas'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      4,
    );
    expect(tester.takeException(), isNull);
  });
}
