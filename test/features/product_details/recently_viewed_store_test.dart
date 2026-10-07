import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/product_details/data/recently_viewed_store.dart';
import 'package:myshopzy/features/product_details/presentation/product_details_page.dart';

void main() {
  late RecentlyViewedStore store;

  setUp(() {
    store = RecentlyViewedStore();
  });

  test('adds the first viewed product', () {
    final product = _product('product-1');

    store.addViewedProduct(product);

    expect(store.products, [product]);
  });

  test('does not duplicate a product when opened again', () {
    final product = _product('product-1');
    store.addViewedProduct(product);
    store.addViewedProduct(product);

    expect(store.products, [product]);
  });

  test('moves an existing product to the top when viewed again', () {
    final first = _product('product-1');
    final second = _product('product-2');
    store.addViewedProduct(first);
    store.addViewedProduct(second);

    store.addViewedProduct(first);

    expect(store.products, [first, second]);
  });

  test('keeps no more than ten products', () {
    for (var index = 0; index < 11; index++) {
      store.addViewedProduct(_product('product-$index'));
    }

    expect(store.products, hasLength(10));
  });

  test('removes the oldest product when the limit is exceeded', () {
    for (var index = 0; index < 11; index++) {
      store.addViewedProduct(_product('product-$index'));
    }

    expect(store.products.first.id, 'product-10');
    expect(store.products.last.id, 'product-1');
  });

  test('allows product types and merchants to coexist', () {
    final restaurant = _product(
      'shared-id',
      serviceType: 'restaurant',
      merchantId: 'restaurant-1',
    );
    final bakery = _product(
      'shared-id',
      serviceType: 'bakery',
      merchantId: 'bakery-1',
    );
    final localStore = _product(
      'shared-id',
      serviceType: 'local_store',
      merchantId: 'store-1',
    );
    store.addViewedProduct(restaurant);
    store.addViewedProduct(bakery);
    store.addViewedProduct(localStore);

    expect(store.products, [localStore, bakery, restaurant]);
  });

  test('keeps same-named products from different merchants separate', () {
    final first = _product(
      'same-name-item',
      name: 'Fresh Apples',
      merchantId: 'store-1',
    );
    final second = _product(
      'same-name-item',
      name: 'Fresh Apples',
      merchantId: 'store-2',
    );

    store.addViewedProduct(first);
    store.addViewedProduct(second);

    expect(store.products, [second, first]);
  });

  test('clear removes the locally viewed products', () {
    store.addViewedProduct(_product('product-1'));
    store.addViewedProduct(_product('product-2'));

    store.clear();

    expect(store.products, isEmpty);
  });

  testWidgets('opening Product Details records the product view', (
    tester,
  ) async {
    final history = RecentlyViewedStore.instance;
    history.clear();
    final product = _product('opened-product');

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailsPage(product: product)),
    );

    expect(history.products, [product]);
    history.clear();
  });

  test('does not modify cart contents or quantity', () {
    const product = ProductDetailsProduct(
      id: 'recent-only-product',
      serviceType: 'meat',
      merchantId: 'partner-1',
      name: 'Demo product',
      icon: Icons.set_meal_rounded,
      available: true,
      priceInPaise: 100,
    );
    final cart = CartStore.instance;
    final cartQuantityBefore = cart.quantityFor(
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.merchantId,
    );
    final cartTotalBefore = cart.totalQuantity;

    store.addViewedProduct(product);

    expect(
      cart.quantityFor(
        productId: product.id,
        serviceType: product.serviceType,
        merchantId: product.merchantId,
      ),
      cartQuantityBefore,
    );
    expect(cart.totalQuantity, cartTotalBefore);
  });
}

ProductDetailsProduct _product(
  String id, {
  String? name,
  String serviceType = 'local_store',
  String? merchantId = 'store-1',
}) {
  return ProductDetailsProduct(
    id: id,
    serviceType: serviceType,
    merchantId: merchantId,
    name: name ?? id,
    icon: Icons.inventory_2_rounded,
    available: true,
  );
}
