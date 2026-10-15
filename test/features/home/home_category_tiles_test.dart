import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/app/theme/app_theme.dart';
import 'package:myshopzy/features/bakery/presentation/bakery_page.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/local_stores/presentation/local_stores_page.dart';
import 'package:myshopzy/features/local_stores/presentation/local_store_catalog_page.dart';
import 'package:myshopzy/features/meat/presentation/meat_page.dart';
import 'package:myshopzy/features/parcel/presentation/parcel_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurants_page.dart';
import 'package:myshopzy/features/vegetables_fruits/presentation/vegetables_fruits_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel == 'Meat Only Chicken' &&
            widget.image is ResizeImage,
      ),
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
  });

  testWidgets('Home category grid reflects active backend partners', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/partner-categories') {
          return http.Response(
            jsonEncode({
              'data': [
                for (final category in [
                  ('restaurant', 'Restaurants', 2),
                  ('grocery', 'Groceries', 3),
                  ('meat_shop', 'Meat', 1),
                  ('other', 'Local Stores', 2),
                  ('bakery', 'Bakery', 2),
                  ('sweet_shop', 'Sweet Shop', 1),
                  ('vegetables_fruits', 'Fruits & Vegetables', 1),
                  ('pharmacy', 'Pharmacy', 1),
                ])
                  {
                    'partner_type': category.$1,
                    'display_name': category.$2,
                    'partner_count': category.$3,
                  },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/shops') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'bakery-shop',
                  'name': 'Sweet Oven',
                  'partner_type': 'bakery',
                  'address': 'Main Road',
                  'partner_name': 'Sweet Oven',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/categories') ||
            request.url.path.endsWith('/products')) {
          return http.Response(jsonEncode({'data': []}), 200);
        }
        return http.Response(jsonEncode({'data': []}), 200);
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'The dynamic grid should fit.',
    );

    expect(find.byType(GridView), findsOneWidget);
    for (final partnerType in [
      'restaurant',
      'grocery',
      'meat_shop',
      'other',
      'bakery',
      'sweet_shop',
      'vegetables_fruits',
      'pharmacy',
    ]) {
      expect(
        find.byKey(ValueKey('home-category-partner-$partnerType')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('home-category-parcel')), findsNothing);
    expect(find.text('Sweet Shop'), findsOneWidget);
    expect(
      requests.any(
        (request) => request.url.path == '/api/v1/partner-categories',
      ),
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('home-category-partner-bakery')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Opening a dynamic partner category should fit.',
    );
    expect(find.byType(LocalStoresPage), findsOneWidget);
    expect(find.text('Bakery near you'), findsOneWidget);
    final bakeryShop = find.text('Sweet Oven');
    await tester.ensureVisible(bakeryShop);
    await tester.tap(bakeryShop);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Opening a dynamically loaded shop should fit.',
    );
    expect(find.byType(LocalStoreCatalogPage), findsOneWidget);
    expect(
      requests.any(
        (request) =>
            request.url.path == '/api/v1/shops' &&
            request.url.queryParameters['partnerType'] == 'bakery',
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) => request.url.path == '/api/v1/shops/bakery-shop/categories',
      ),
      isTrue,
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
