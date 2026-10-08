import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/product_details/data/product_availability_store.dart';
import 'package:myshopzy/features/product_details/data/recently_viewed_store.dart';
import 'package:myshopzy/features/product_details/presentation/product_details_page.dart';
import 'package:myshopzy/features/local_stores/models/local_store.dart';
import 'package:myshopzy/features/local_stores/presentation/local_store_catalog_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurant_menu_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurants_page.dart';
import 'package:myshopzy/features/wishlist/data/wishlist_store.dart';
import 'package:myshopzy/features/wishlist/presentation/wishlist_page.dart';
import 'package:myshopzy/features/wishlist/presentation/save_list_button.dart';

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

  testWidgets('Restaurant product can be saved and immediately unsaved', (
    tester,
  ) async {
    final product = _product(
      id: 'menu-product',
      serviceType: 'restaurant',
      merchantId: 'restaurant-a',
      merchantName: 'Restaurant A',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaveListButton(product: product)),
      ),
    );

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pump();
    expect(wishlist.contains(product), isTrue);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pump();
    expect(wishlist.contains(product), isFalse);
    expect(wishlist.products, isEmpty);
  });

  testWidgets('Local Store product can be saved and immediately unsaved', (
    tester,
  ) async {
    final product = _product(
      id: 'grocery-product',
      serviceType: 'local_store',
      merchantId: 'store-a',
      merchantName: 'Store A',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaveListButton(product: product)),
      ),
    );

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pump();
    expect(wishlist.contains(product), isTrue);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pump();
    expect(wishlist.contains(product), isFalse);
    expect(wishlist.products, isEmpty);
  });

  testWidgets('Restaurant menu save button toggles its product record', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RestaurantMenuPage(restaurant: sampleRestaurants.first),
      ),
    );

    await tester.tap(find.byTooltip('Add to wishlist').first);
    await tester.pump();
    final product = _product(
      id: 'chicken-dum-biryani',
      serviceType: 'restaurant',
      merchantId: 'spice-route',
      merchantName: 'Spice Route Kitchen',
    );
    expect(wishlist.contains(product), isTrue);

    await tester.tap(find.byTooltip('Remove from wishlist').first);
    await tester.pump();
    expect(wishlist.contains(product), isFalse);
  });

  testWidgets('Local Store catalogue save button toggles its product record', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocalStoreCatalogPage(
          store: sampleLocalStores.first,
          categories: const [
            CommonCategory(
              id: 'test-category',
              name: 'Test Category',
              icon: Icons.shopping_bag_outlined,
            ),
          ],
          initialCategoryId: 'test-category',
          products: const [
            StoreProduct(
              id: 'catalog-product',
              storeId: 'sri-lakshmi-general-store',
              categoryId: 'test-category',
              name: 'Catalog Product',
              brand: 'Demo',
              description: 'Demo product',
              packSize: '1 pack',
              price: 10,
              mrp: 10,
              discount: 0,
              rating: 4.5,
              available: true,
            ),
          ],
        ),
      ),
    );
    final product = _product(
      id: 'catalog-product',
      serviceType: 'local_store',
      merchantId: 'sri-lakshmi-general-store',
      merchantName: 'Sri Lakshmi General Store',
    );

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pump();
    expect(wishlist.contains(product), isTrue);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pump();
    expect(wishlist.contains(product), isFalse);
    expect(wishlist.products, isEmpty);
  });

  test(
    'service variants do not create separate Wishlist product identities',
    () {
      final product = _product(
        serviceType: 'vegetables_fruits',
        merchantId: 'produce-store',
      );
      final sameProductDifferentContext = ProductDetailsProduct(
        id: product.id,
        serviceType: product.serviceType,
        merchantId: product.merchantId,
        serviceVariant: 'fruit',
        merchantName: product.merchantName,
        categoryId: product.categoryId,
        name: product.name,
        description: product.description,
        icon: product.icon,
        available: product.available,
        priceInPaise: product.priceInPaise,
      );

      wishlist.save(product);
      expect(wishlist.contains(sameProductDifferentContext), isTrue);
      wishlist.toggle(sameProductDifferentContext);
      expect(wishlist.products, isEmpty);
    },
  );

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
