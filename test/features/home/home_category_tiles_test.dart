import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/bakery/presentation/bakery_page.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/local_stores/presentation/local_stores_page.dart';
import 'package:myshopzy/features/meat/presentation/meat_page.dart';
import 'package:myshopzy/features/parcel/presentation/parcel_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurants_page.dart';
import 'package:myshopzy/features/vegetables_fruits/presentation/vegetables_fruits_page.dart';

void main() {
  testWidgets('Home category tiles use three columns on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.crossAxisSpacing, 8);
    expect(delegate.mainAxisSpacing, 8);
    for (final key in [
      'meat_only_chicken',
      'bakery',
      'parcel',
      'local_stores',
      'fruits_vegetables',
      'restaurants',
    ]) {
      expect(find.byKey(ValueKey('home-category-$key')), findsOneWidget);
    }

    final firstTileSize = tester.getSize(
      find.byKey(const ValueKey('home-category-meat_only_chicken')),
    );
    expect(firstTileSize.width, closeTo(firstTileSize.height, 1));
  });

  testWidgets('Home category tiles show their images and open existing pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1366));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    const destinations = {
      'meat_only_chicken': MeatPage,
      'bakery': BakeryPage,
      'parcel': ParcelPage,
      'local_stores': LocalStoresPage,
      'fruits_vegetables': VegetablesFruitsPage,
      'restaurants': RestaurantsPage,
    };
    const categoryNames = {
      'Meat Only Chicken',
      'Bakery',
      'Parcel',
      'Local Stores',
      'Fruits & Vegetables',
      'Restaurants',
    };

    expect(find.byType(GridView), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            categoryNames.contains(widget.semanticLabel),
      ),
      findsNWidgets(6),
    );
    for (final entry in destinations.entries) {
      final tile = find.byKey(ValueKey('home-category-${entry.key}'));
      await tester.ensureVisible(tile);
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
