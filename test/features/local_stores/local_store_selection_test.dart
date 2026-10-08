import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_access_button.dart';
import 'package:myshopzy/features/categories/presentation/categories_page.dart';
import 'package:myshopzy/features/local_stores/data/local_store_session.dart';
import 'package:myshopzy/features/local_stores/presentation/local_store_catalog_page.dart';
import 'package:myshopzy/features/local_stores/presentation/local_stores_page.dart';

void main() {
  final cart = CartStore.instance;
  final session = LocalStoreSession.instance;

  setUp(() {
    cart.clear();
    session.clearSelection();
  });

  tearDown(() {
    cart.clear();
    session.clearSelection();
  });

  test('sorts stores by distance and excludes stores beyond 18 km', () {
    final stores = [
      _store(id: 'far', name: 'Far Store', distance: '18.1 km'),
      _store(id: 'second', name: 'Second Store', distance: '2.4 km'),
      _store(id: 'nearest', name: 'Nearest Store', distance: '1.2 km'),
    ];

    expect(sortLocalStoresByDistance(stores).map((store) => store.id), [
      'nearest',
      'second',
      'far',
    ]);
    expect(eligibleLocalStores(stores).map((store) => store.id), [
      'nearest',
      'second',
    ]);
  });

  testWidgets('marks only the nearest eligible store Recommended', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocalStoresPage(stores: sampleLocalStores.reversed.toList()),
      ),
    );

    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Sri Lakshmi General Store'), findsOneWidget);
  });

  testWidgets('selecting a store saves context and opens its catalogue', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LocalStoresPage()));

    await tester.tap(find.text('Sri Lakshmi General Store'));
    await tester.pumpAndSettle();

    expect(session.selectedStoreId, 'sri-lakshmi-general-store');
    expect(session.selectedStoreName, 'Sri Lakshmi General Store');
    expect(session.selectedStore?.locality, 'Mandapeta');
    expect(find.byType(LocalStoreCatalogPage), findsOneWidget);
  });

  testWidgets('a category entry asks for a store then opens that category', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    await tester.tap(find.text('Dairy, Bread & Eggs'));
    await tester.pumpAndSettle();
    expect(find.byType(LocalStoresPage), findsOneWidget);
    expect(find.byType(LocalStoreCatalogPage), findsNothing);

    await tester.tap(find.text('Sri Lakshmi General Store'));
    await tester.pumpAndSettle();

    expect(find.byType(LocalStoreCatalogPage), findsOneWidget);
    expect(find.text('No Dairy available at this store yet.'), findsOneWidget);
    expect(session.selectedStoreId, 'sri-lakshmi-general-store');
  });

  testWidgets('catalogue only shows products belonging to its selected store', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocalStoreCatalogPage(
          store: sampleLocalStores[1],
          categories: const [
            CommonCategory(
              id: 'noodles',
              name: 'Noodles',
              icon: Icons.ramen_dining_rounded,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Smoodles Masala'), findsOneWidget);
    expect(find.text('Magic Masala Noodles'), findsNothing);
    expect(session.selectedStoreId, 'venkateswara-stores');
  });

  test('allows same-store Local Store products in the cart', () {
    expect(_addLocalStoreProduct('store-a', 'product-a'), isTrue);
    expect(_addLocalStoreProduct('store-a', 'product-b'), isTrue);

    expect(cart.items, hasLength(2));
    expect(cart.items.every((item) => item.merchantId == 'store-a'), isTrue);
  });

  test(
    'blocks products from a different Local Store without changing cart',
    () {
      expect(_addLocalStoreProduct('store-a', 'product-a'), isTrue);

      expect(_addLocalStoreProduct('store-b', 'product-b'), isFalse);
      expect(cart.items, hasLength(1));
      expect(cart.items.single.merchantId, 'store-a');
    },
  );

  testWidgets(
    'shows a clear message when a different Local Store product is added',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                _cartControl('store-a', 'product-a'),
                _cartControl('store-b', 'product-b'),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('ADD').first);
      await tester.pump();
      await tester.tap(find.text('ADD'));
      await tester.pump();

      expect(
        find.text(
          'You can only order from one store at a time.',
        ),
        findsOneWidget,
      );
      expect(cart.items, hasLength(1));
    },
  );

  test('allows same-context non-Local-Store products and rejects other services', () {
    expect(
      _addProduct('restaurant', 'restaurant-product-a', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(
      _addProduct('restaurant', 'restaurant-product-b', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(_addProduct('bakery', 'bakery-a', merchantId: 'bakery-a'), isFalse);
    expect(cart.items, hasLength(2));
  });
}

LocalStore _store({
  required String id,
  required String name,
  required String distance,
}) {
  return LocalStore(
    id: id,
    name: name,
    rating: 4.5,
    deliveryTime: '15–20 min',
    distance: distance,
    locality: 'Mandapeta',
    isOpen: true,
  );
}

bool _addLocalStoreProduct(String storeId, String productId) {
  return _addProduct('local_store', productId, merchantId: storeId);
}

bool _addProduct(String serviceType, String productId, {String? merchantId}) {
  return CartStore.instance.addItem(
    productId: productId,
    serviceType: serviceType,
    merchantId: merchantId,
    name: productId,
    description: 'Demo product',
    priceInPaise: 1000,
    icon: Icons.shopping_bag_outlined,
  );
}

Widget _cartControl(String storeId, String productId) {
  return CartProductControl(
    productId: productId,
    serviceType: 'local_store',
    merchantId: storeId,
    name: productId,
    description: 'Demo product',
    priceInPaise: 1000,
    icon: Icons.shopping_bag_outlined,
    available: true,
  );
}
