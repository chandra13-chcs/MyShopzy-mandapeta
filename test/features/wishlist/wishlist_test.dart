import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/product_details/data/product_availability_store.dart';
import 'package:myshopzy/features/product_details/data/recently_viewed_store.dart';
import 'package:myshopzy/features/product_details/presentation/product_details_page.dart';
import 'package:myshopzy/features/wishlist/data/wishlist_store.dart';
import 'package:myshopzy/features/wishlist/presentation/wishlist_page.dart';

void main() {
  final wishlist = WishlistStore.instance;

  setUp(() {
    wishlist.clear();
    CartStore.instance.clear();
    ProductAvailabilityStore.instance.clearOverrides();
  });

  tearDown(() {
    wishlist.clear();
    CartStore.instance.clear();
    ProductAvailabilityStore.instance.clearOverrides();
  });

  test('saves and unsaves a product', () {
    final product = _product();

    wishlist.toggle(product);
    expect(wishlist.products, [product]);
    expect(wishlist.contains(product), isTrue);

    wishlist.toggle(product);
    expect(wishlist.products, isEmpty);
    expect(wishlist.contains(product), isFalse);
  });

  test('duplicate save does not create duplicate entries', () {
    final product = _product();
    wishlist.save(product);
    wishlist.save(_product());

    expect(wishlist.products, hasLength(1));
  });

  test('same product IDs from different merchants remain separate', () {
    final firstStoreProduct = _product(merchantId: 'store-1');
    final secondStoreProduct = _product(merchantId: 'store-2');
    final otherServiceProduct = _product(
      merchantId: 'store-1',
      serviceType: 'bakery',
    );

    wishlist.toggle(firstStoreProduct);
    wishlist.toggle(secondStoreProduct);
    wishlist.toggle(otherServiceProduct);

    expect(wishlist.products, hasLength(3));
  });

  testWidgets('Product Details and Wishlist use the same saved state', (
    tester,
  ) async {
    final product = _product();
    await tester.pumpWidget(
      MaterialApp(home: ProductDetailsPage(product: product)),
    );

    expect(wishlist.contains(product), isFalse);
    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pump();
    expect(wishlist.contains(product), isTrue);
    expect(CartStore.instance.items, isEmpty);

    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    expect(find.text('Saved Product'), findsOneWidget);
    expect(find.text('Demo Store'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pump();
    expect(wishlist.products, isEmpty);
    expect(find.text('Your Wishlist is empty'), findsOneWidget);
  });

  testWidgets('empty Wishlist shows its empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));

    expect(find.text('Your Wishlist is empty'), findsOneWidget);
    expect(
      find.text('Save items you love and find them here.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a saved product opens its matching Product Details', (
    tester,
  ) async {
    final product = _product();
    wishlist.save(product);

    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    await tester.tap(find.text(product.name));
    await tester.pumpAndSettle();

    expect(find.byType(ProductDetailsPage), findsOneWidget);
    expect(
      RecentlyViewedStore.instance.products.first.merchantId,
      product.merchantId,
    );
    RecentlyViewedStore.instance.clear();
  });

  testWidgets('Add to Cart uses CartStore and respects availability', (
    tester,
  ) async {
    final product = _product();
    wishlist.toggle(product);
    ProductAvailabilityStore.instance.setAvailability(
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.merchantId,
      isAvailable: false,
    );

    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    await tester.tap(find.text('Add to Cart'));
    await tester.pump();

    expect(CartStore.instance.items, isEmpty);
    expect(find.text('Saved Product is out of stock.'), findsOneWidget);

    ProductAvailabilityStore.instance.setAvailability(
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.merchantId,
      isAvailable: true,
    );
    await tester.tap(find.text('Add to Cart'));
    await tester.pump();

    expect(CartStore.instance.items, hasLength(1));
    expect(CartStore.instance.items.single.productId, product.id);
  });
}

ProductDetailsProduct _product({
  String id = 'saved-product',
  String serviceType = 'local_store',
  String? merchantId = 'demo-store',
  String? merchantName = 'Demo Store',
}) {
  return ProductDetailsProduct(
    id: id,
    serviceType: serviceType,
    merchantId: merchantId,
    merchantName: merchantName,
    categoryId: 'demo-category',
    name: 'Saved Product',
    description: null,
    icon: Icons.inventory_2_rounded,
    available: true,
    priceInPaise: 1250,
  );
}
