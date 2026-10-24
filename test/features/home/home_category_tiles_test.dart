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
import 'package:myshopzy/features/restaurants/presentation/restaurant_menu_page.dart';
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
    await pumpHomeTransitions(tester);

    const destinations = {
      'restaurants': RestaurantsPage,
      'bakery': BakeryPage,
      'meat_only_chicken': MeatPage,
      'fruits_vegetables': VegetablesFruitsPage,
      'parcel': ParcelPage,
      'local_stores': LocalStoresPage,
    };

    expect(find.byType(GridView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('free-delivery-progress-strip')),
      findsNothing,
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
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel == 'Meat Only Chicken' &&
            widget.image is ResizeImage,
      ),
      findsOneWidget,
    );

    const categoryAssets = {
      'Restaurants': 'assets/category_tiles/restarant tile.jpeg',
      'Bakery': 'assets/category_tiles/bakery tile.jpeg',
      'Meat Only Chicken': 'assets/category_tiles/meat tiles.jpeg',
      'Fruits & Vegetables':
          'assets/category_tiles/fruits nd vegetables tile.jpeg',
      'Parcel': 'assets/category_tiles/parcel tiles.jpeg',
      'Local Stores': 'assets/category_tiles/local stores tiles.jpeg',
    };
    for (final entry in categoryAssets.entries) {
      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == entry.key,
      );
      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, BoxFit.contain);
      expect(
        image.image,
        isA<ResizeImage>().having(
          (resizeImage) => resizeImage.imageProvider,
          'imageProvider',
          isA<AssetImage>().having(
            (assetImage) => assetImage.assetName,
            'assetName',
            entry.value,
          ),
        ),
      );
      final tile = find.ancestor(
        of: imageFinder,
        matching: find.byType(InkWell),
      );
      final imageBounds = tester.getRect(imageFinder);
      final tileBounds = tester.getRect(tile);
      expect(imageBounds, tileBounds);
      expect(tileBounds.width / tileBounds.height, closeTo(1.15, 0.02));
    }
    for (final categoryName in categoryAssets.keys) {
      expect(find.text(categoryName), findsNothing);
    }
    for (final subtitle in [
      'Hot & tasty',
      'Order your favorite',
      'Freshly baked',
      'Delicious daily',
      'Premium quality',
      'Clean & fresh',
      'Farm fresh',
      '100% natural',
      'Fast delivery',
      'Safe & secure',
      'Kirana & essentials',
      'From nearby shops',
    ]) {
      expect(find.text(subtitle), findsNothing);
    }

    final categoryGrid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (categoryGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );
    final orderedCategoryRects = categoryAssets.keys
        .map(
          (name) => tester.getRect(
            find.byWidgetPredicate(
              (widget) => widget is Image && widget.semanticLabel == name,
            ),
          ),
        )
        .toList();
    expect(orderedCategoryRects[0].top, orderedCategoryRects[1].top);
    expect(orderedCategoryRects[1].top, orderedCategoryRects[2].top);
    expect(
      orderedCategoryRects[0].left,
      lessThan(orderedCategoryRects[1].left),
    );
    expect(
      orderedCategoryRects[1].left,
      lessThan(orderedCategoryRects[2].left),
    );
    expect(
      orderedCategoryRects[3].top,
      greaterThan(orderedCategoryRects[0].top),
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
    await pumpHomeTransitions(tester);
    expect(tester.widget<AnimatedScale>(pressScale).scale, 1);

    for (final entry in destinations.entries) {
      final tile = find.byKey(ValueKey('home-category-${entry.key}'));
      await tester.scrollUntilVisible(
        tile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(tile);
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await pumpHomeTransitions(tester);
      expect(find.byType(entry.value), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Opening ${entry.value} should not produce layout errors.',
      );
      await tester.pageBack();
      await pumpHomeTransitions(tester);
    }
  });

  testWidgets('home black header contains location and search only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await pumpHomeTransitions(tester);

    final headerFinder = find.byKey(const ValueKey('home-black-header'));
    final header = tester.widget<Container>(headerFinder);
    final headerDecorationColor =
        (header.decoration as BoxDecoration?)?.color ?? header.color;
    expect(headerDecorationColor, Colors.black);
    expect(tester.getRect(headerFinder).left, 0);
    expect(tester.getRect(headerFinder).right, 390);

    final searchFinder = find.byKey(const ValueKey('home-search-bar'));
    final search = tester.widget<Container>(searchFinder);
    expect((search.decoration! as BoxDecoration).color, Colors.black);
    expect(
      tester.getRect(searchFinder).bottom,
      lessThan(tester.getRect(headerFinder).bottom),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.search_rounded)).color,
      Colors.white,
    );

    for (final label in ['30 mins', 'delivery', 'Choose your location']) {
      expect(
        tester.widget<Text>(find.text(label)).style?.color,
        label == 'delivery' ? const Color(0xFFCCCCCC) : Colors.white,
      );
    }
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      AppTheme.lightBackground,
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
      tester.getRect(find.byType(GridView)).top,
      greaterThanOrEqualTo(tester.getRect(headerFinder).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home biryani product opens its restaurant menu category', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final biryaniTile = find.byKey(
      const ValueKey('home-restaurant-product-demo-chicken-biryani'),
    );
    await tester.scrollUntilVisible(
      biryaniTile,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(biryaniTile);
    await tester.pumpAndSettle();

    expect(find.byType(RestaurantMenuPage), findsOneWidget);
    expect(find.text('Demo Biryani Kitchen'), findsOneWidget);
    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(
      tester
          .widget<RestaurantMenuPage>(find.byType(RestaurantMenuPage))
          .initialCategoryId,
      'biryani',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home grocery product opens its mapped store category', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final groceryTile = find.byKey(
      const ValueKey('home-grocery-product-home-dairy-milk'),
    );
    await tester.scrollUntilVisible(
      groceryTile,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(groceryTile);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -180),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(groceryTile);
    await pumpHomeTransitions(tester);

    expect(find.byType(LocalStoreCatalogPage), findsOneWidget);
    expect(find.text('Sri Lakshmi General Store'), findsOneWidget);
    expect(find.text('Toned Milk'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await pumpHomeTransitions(tester);
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
    final orderedPartnerTypes = [
      'restaurant',
      'bakery',
      'meat_shop',
      'vegetables_fruits',
      'grocery',
    ];
    final orderedPartnerRects = orderedPartnerTypes
        .map(
          (partnerType) => tester.getRect(
            find.byKey(ValueKey('home-category-partner-$partnerType')),
          ),
        )
        .toList();
    expect(orderedPartnerRects[0].top, orderedPartnerRects[1].top);
    expect(orderedPartnerRects[1].top, orderedPartnerRects[2].top);
    expect(orderedPartnerRects[0].left, lessThan(orderedPartnerRects[1].left));
    expect(orderedPartnerRects[1].left, lessThan(orderedPartnerRects[2].left));
    expect(orderedPartnerRects[3].top, greaterThan(orderedPartnerRects[0].top));
    expect(orderedPartnerRects[4].top, orderedPartnerRects[3].top);
    expect(find.byKey(const ValueKey('home-category-parcel')), findsNothing);
    expect(find.text('Sweet Shop'), findsNothing);
    expect(
      requests.any(
        (request) => request.url.path == '/api/v1/partner-categories',
      ),
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('home-category-partner-bakery')),
    );
    await pumpHomeTransitions(tester);
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
    await pumpHomeTransitions(tester);
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

  testWidgets('Home category grid keeps three columns on compact screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await pumpHomeTransitions(tester);

    final categoryGrid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (categoryGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );
    expect(tester.takeException(), isNull);
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

Future<void> pumpHomeTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
