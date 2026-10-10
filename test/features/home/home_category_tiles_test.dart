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
  testWidgets('Home category tiles show their images and open existing pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
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

    expect(find.byType(GridView), findsOneWidget);
    for (final entry in destinations.entries) {
      final tile = find.byKey(ValueKey('home-category-${entry.key}'));
      await tester.ensureVisible(tile);
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Opening ${entry.value} should not produce layout errors.',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel == 'Meat Only Chicken' &&
            widget.image is AssetImage,
      ),
      findsOneWidget,
    );
  });
}
