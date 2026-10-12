import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/app/theme/app_theme.dart';
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
    expect(
      find.byKey(const ValueKey('free-delivery-progress-strip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('home-category-arrow-meat_only_chicken')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.person_outline_rounded &&
            widget.color == AppTheme.brandYellow,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-category-arrow-bakery')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-category-arrow-parcel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-category-arrow-local_stores')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-category-arrow-fruits_vegetables')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-category-arrow-restaurants')),
      findsOneWidget,
    );

    final meatTile = find.byKey(
      const ValueKey('home-category-meat_only_chicken'),
    );
    final pressScale = find.ancestor(
      of: meatTile,
      matching: find.byType(AnimatedScale),
    );
    final gesture = await tester.startGesture(tester.getCenter(meatTile));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<AnimatedScale>(pressScale).scale, lessThan(1));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(pressScale).scale, 1);

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

  testWidgets('home discovery remains reachable through the root scroll view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final finalDiscoverySection = find.text('Cooking Oils');
    expect(finalDiscoverySection, findsNothing);
    await tester.scrollUntilVisible(
      finalDiscoverySection,
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(finalDiscoverySection, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
