import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/app/theme/app_theme.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/local_stores/presentation/main_grocery_catalog_page.dart';
import 'package:myshopzy/features/local_stores/presentation/local_stores_page.dart';
import 'package:myshopzy/features/local_stores/presentation/local_store_catalog_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurant_menu_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';
import 'package:myshopzy/shared/delivery/category_delivery_serviceability.dart';
import 'package:myshopzy/features/profile/data/selected_delivery_address_store.dart';
import 'package:myshopzy/features/profile/models/saved_address.dart';

void main() {
  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
    SelectedDeliveryAddressStore.instance.select(null);
  });

  testWidgets('Home category tiles show their images and open existing pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );
    await pumpHomeTransitions(tester);

    const tileLabels = [
      'Restaurants',
      'Bakery',
      'Meat',
      'Fruits',
      'Parcel',
      'Groceries',
    ];

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
            widget.semanticLabel == 'Meat' &&
            widget.image is ResizeImage,
      ),
      findsOneWidget,
    );

    const categoryAssets = {
      'Restaurants': 'assets/category_tiles/restarant tile.jpeg',
      'Bakery': 'assets/category_tiles/bakery tile.jpeg',
      'Meat': 'assets/category_tiles/meat tiles.jpeg',
      'Fruits': 'assets/category_tiles/fruits nd vegetables tile.jpeg',
      'Parcel': 'assets/category_tiles/parcel tiles.jpeg',
      'Groceries': 'assets/category_tiles/local stores tiles.jpeg',
    };
    const categoryKeys = {
      'Restaurants': 'restaurants',
      'Bakery': 'bakery',
      'Meat': 'meat_only_chicken',
      'Fruits': 'fruits_vegetables',
      'Parcel': 'parcel',
      'Groceries': 'local_stores',
    };
    for (final entry in categoryAssets.entries) {
      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == entry.key,
      );
      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, BoxFit.contain);
      expect(image.filterQuality, FilterQuality.high);
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
      final tile = find.byKey(
        ValueKey('home-category-tile-${categoryKeys[entry.key]}'),
      );
      final imageBounds = tester.getRect(imageFinder);
      final tileBounds = tester.getRect(tile);
      expect(tileBounds.top <= imageBounds.top, isTrue);
      expect(tileBounds.left <= imageBounds.left, isTrue);
      expect(tileBounds.right >= imageBounds.right, isTrue);
      expect(tileBounds.bottom >= imageBounds.bottom, isTrue);
      expect(tileBounds.width / tileBounds.height, closeTo(0.85, 0.02));
      final imageContainer = tester.widget<Image>(
        find.byKey(ValueKey('home-category-image-${categoryKeys[entry.key]}')),
      );
      expect(imageContainer.fit, BoxFit.contain);
      final tileContainer = tester.widget<Container>(
        find.byKey(ValueKey('home-category-tile-${categoryKeys[entry.key]}')),
      );
      final tileDecoration = tileContainer.decoration! as BoxDecoration;
      expect(tileDecoration.color, Colors.white);
      expect(tileDecoration.borderRadius, BorderRadius.circular(20));
      expect(tileDecoration.border, isNull);
      expect(tileDecoration.boxShadow, hasLength(1));
      expect(tileDecoration.boxShadow!.single.blurRadius, 10);
      expect(tileDecoration.boxShadow!.single.offset, const Offset(0, 4));
      expect(
        tileDecoration.boxShadow!.single.color,
        Colors.black.withValues(alpha: 0.04),
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(entry.key),
        ),
        findsNothing,
      );
    }
    for (final label in tileLabels) {
      expect(find.text(label), findsNothing);
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
    final gridDelegate =
        categoryGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(gridDelegate.childAspectRatio, 0.85);
    expect(gridDelegate.crossAxisSpacing, 12);
    expect(gridDelegate.mainAxisSpacing, 12);
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
    final pressScale = find.descendant(
      of: meatTile,
      matching: find.byType(AnimatedScale),
    );
    final gesture = await tester.startGesture(tester.getCenter(meatTile));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<AnimatedScale>(pressScale).scale, lessThan(1));
    await gesture.cancel();
    await pumpHomeTransitions(tester);
    expect(tester.widget<AnimatedScale>(pressScale).scale, 1);

    for (final tileKey in [
      'restaurants',
      'bakery',
      'meat_only_chicken',
      'fruits_vegetables',
      'parcel',
      'local_stores',
    ]) {
      final tile = find.byKey(ValueKey('home-category-$tileKey'));
      await tester.scrollUntilVisible(
        tile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(tile);
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await pumpHomeTransitions(tester);
      expect(find.byType(CategoryDeliveryGate), findsOneWidget);
      expect(find.byType(LocalStoresPage), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Opening $tileKey should not produce layout errors.',
      );
      Navigator.of(tester.element(find.byType(CategoryDeliveryGate))).pop();
      await pumpHomeTransitions(tester);
    }
  });

  testWidgets('Home category tiles use white fills and press feedback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );
    await pumpHomeTransitions(tester);

    final tileContainer = tester.widget<Container>(
      find.byKey(const ValueKey('home-category-tile-restaurants')),
    );
    expect(
      (tileContainer.decoration! as BoxDecoration).color,
      Colors.white,
    );

    final gestureFinder = find.byKey(
      const ValueKey('home-category-restaurants'),
    );
    final scaleFinder = find.descendant(
      of: gestureFinder,
      matching: find.byType(AnimatedScale),
    );
    final gesture = await tester.startGesture(tester.getCenter(gestureFinder));
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.widget<AnimatedScale>(scaleFinder).scale, 0.94);
    final opacityFinder = find.byKey(
      const ValueKey('home-category-opacity-restaurants'),
    );
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0.85);

    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.widget<AnimatedScale>(scaleFinder).scale, 1);
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1);
  });

  testWidgets('home black header contains location and search only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );
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
    expect((search.decoration! as BoxDecoration).color, Colors.white);
    expect(
      tester.getRect(searchFinder).bottom,
      lessThan(tester.getRect(headerFinder).bottom),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.search_rounded)).color,
      const Color(0xFF1B211D),
    );
    expect(
      tester
          .widget<Text>(find.text('Search restaurants, groceries, products...'))
          .style
          ?.color,
      const Color(0xFF1B211D),
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
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );

    final biryaniTile = find.byKey(
      const ValueKey('home-restaurant-product-demo-chicken-biryani'),
    );
    await tester.scrollUntilVisible(
      biryaniTile,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(biryaniTile);
    await tester.pump();
    await tester.tap(biryaniTile);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDeliveryGate), findsOneWidget);
    expect(find.byType(RestaurantMenuPage), findsNothing);
    expect(find.text('Choose a delivery address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home Groceries routes directly to the single catalogue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );
    await pumpHomeTransitions(tester);
    final groceryTile = find.byKey(
      const ValueKey('home-category-local_stores'),
    );
    await tester.ensureVisible(groceryTile);
    await tester.tap(groceryTile);
    await pumpHomeTransitions(tester);

    final gate = tester.widget<CategoryDeliveryGate>(
      find.byType(CategoryDeliveryGate),
    );
    expect(gate.child, isA<MainGroceryCatalogPage>());
    expect(find.byType(LocalStoresPage), findsNothing);
    expect(find.text('Choose a delivery address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main Grocery catalogue opens products without store selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainGroceryCatalogPage(initialCategoryId: 'noodles'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LocalStoreCatalogPage), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('2-Minute Noodles'), findsOneWidget);
    expect(find.byType(LocalStoresPage), findsNothing);
  });

  testWidgets('Home category grid reflects active backend partners', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SelectedDeliveryAddressStore.instance.select(
      SavedAddress(
        id: 'backend-grid-address',
        label: 'Home',
        address: 'Mandapeta',
        icon: Icons.home_outlined,
        latitude: 16.91,
        longitude: 81.91,
        pincode: '533308',
      ),
    );
    final requests = <http.Request>[];
    SelectedDeliveryAddressStore.instance.select(
      SavedAddress(
        id: 'active-partners-address',
        label: 'Home',
        address: 'Mandapeta',
        icon: Icons.home_outlined,
        latitude: 16.91,
        longitude: 81.91,
        pincode: '533308',
      ),
    );
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
        if (request.url.path ==
            '/api/v1/delivery/category-serviceability') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'category': body['category'],
                'isDeliverable': true,
                'distanceMeters': 5000,
                'maximumDistanceMeters': 10000,
                'message': 'Delivery is available within 10 km.',
              },
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

    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );
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
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );
    await pumpHomeTransitions(tester);

    final categoryGrid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (categoryGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );
    final gridDelegate =
        categoryGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(gridDelegate.childAspectRatio, 0.85);
    expect(gridDelegate.crossAxisSpacing, 12);
    expect(gridDelegate.mainAxisSpacing, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home discovery remains reachable through the root scroll view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(clock: _middayClock)),
    );

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

DateTime _middayClock() => DateTime(2026, 10, 24, 12);

Future<void> pumpHomeTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
