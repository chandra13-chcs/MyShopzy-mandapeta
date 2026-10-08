import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';
import 'package:myshopzy/features/local_stores/models/local_store.dart';
import 'package:myshopzy/features/local_stores/presentation/local_store_catalog_page.dart';
import 'package:myshopzy/features/product_details/data/product_availability_store.dart';
import 'package:myshopzy/features/product_details/models/product_variant.dart';
import 'package:myshopzy/features/product_details/presentation/product_details_page.dart';
import 'package:myshopzy/features/search/data/search_index.dart';
import 'package:myshopzy/features/search/models/search_result.dart';
import 'package:myshopzy/features/wishlist/data/wishlist_store.dart';
import 'package:myshopzy/features/wishlist/presentation/wishlist_page.dart';

void main() {
  final cart = CartStore.instance;
  final availability = ProductAvailabilityStore.instance;

  setUp(() {
    cart.clear();
    availability.clearOverrides();
    WishlistStore.instance.clear();
  });

  tearDown(() {
    cart.clear();
    availability.clearOverrides();
    WishlistStore.instance.clear();
  });

  test('search keeps variants on one product result', () {
    final results = SearchIndex.search('Ashirvad Atta')
        .where((result) => result.type == SearchResultType.storeProduct)
        .toList();

    expect(results, hasLength(1));
    final product = SearchIndex.productFor(results.single);
    expect(product.variants.map((variant) => variant.id), [
      '1-kg',
      '2-kg',
      '5-kg',
    ]);
  });

  testWidgets('wishlist requires an explicit variant choice', (tester) async {
    final result = SearchIndex.search('Ashirvad Atta')
        .firstWhere((result) => result.type == SearchResultType.storeProduct);
    final product = SearchIndex.productFor(result);
    WishlistStore.instance.save(
      ProductDetailsProduct(
        id: product.id,
        serviceType: product.serviceType,
        merchantId: product.merchantId,
        name: product.name,
        icon: product.icon,
        available: product.available,
        variants: product.variants,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    await tester.tap(find.text('Select Options'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductDetailsPage), findsOneWidget);
    expect(cart.items, isEmpty);
  });

  testWidgets('selecting a size updates price and cart variant', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _catalogPage()));

    await tester.ensureVisible(find.text('OPTIONS'));
    await tester.tap(find.text('OPTIONS'));
    await tester.pumpAndSettle();
    expect(find.text('Select Size'), findsOneWidget);
    expect(find.text('₹70'), findsOneWidget);
    final fiveKg = find.widgetWithText(ChoiceChip, '5 KG');
    await tester.ensureVisible(fiveKg);
    await tester.tap(fiveKg);
    await tester.pumpAndSettle();
    expect(find.text('₹310'), findsOneWidget);

    await tester.ensureVisible(find.text('ADD'));
    await tester.tap(find.text('ADD'));
    await tester.pump();

    expect(cart.items, hasLength(1));
    expect(cart.items.single.productVariantId, '5-kg');
    expect(cart.items.single.variantLabel, '5 KG');
    expect(cart.items.single.priceInPaise, 31000);
  });

  testWidgets('unavailable variant cannot be added', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _catalogPage()));

    await tester.ensureVisible(find.text('OPTIONS'));
    await tester.tap(find.text('OPTIONS'));
    await tester.pumpAndSettle();
    final twoKg = find.widgetWithText(ChoiceChip, '2 KG');
    await tester.ensureVisible(twoKg);
    await tester.tap(twoKg);
    await tester.pumpAndSettle();

    expect(find.text('OUT OF STOCK'), findsOneWidget);
    await tester.tap(find.text('OUT OF STOCK'));
    await tester.pump();
    expect(cart.items, isEmpty);
  });

  testWidgets('cart displays the selected variant label', (tester) async {
    cart.addItem(
      productId: 'slgs-ashirvad-atta',
      serviceType: 'local_store',
      merchantId: 'sri-lakshmi-general-store',
      productVariantId: '5-kg',
      variantLabel: '5 KG',
      name: 'Ashirvad Atta',
      description: 'Whole wheat flour',
      priceInPaise: 31000,
      icon: Icons.inventory_2_rounded,
    );

    await tester.pumpWidget(const MaterialApp(home: CartPage()));

    expect(find.text('Ashirvad Atta'), findsOneWidget);
    expect(find.text('5 KG'), findsOneWidget);
  });

  test('different sizes have separate cart lines and same sizes merge', () {
    bool addVariant(String variantId, String label, int price) {
      return cart.addItem(
        productId: 'slgs-ashirvad-atta',
        serviceType: 'local_store',
        merchantId: 'sri-lakshmi-general-store',
        productVariantId: variantId,
        variantLabel: label,
        name: 'Ashirvad Atta',
        description: 'Whole wheat flour',
        priceInPaise: price,
        icon: Icons.inventory_2_rounded,
      );
    }

    expect(addVariant('1-kg', '1 KG', 7000), isTrue);
    expect(addVariant('1-kg', '1 KG', 7000), isTrue);
    expect(addVariant('5-kg', '5 KG', 31000), isTrue);

    expect(cart.items, hasLength(2));
    expect(
      cart.quantityFor(
        productId: 'slgs-ashirvad-atta',
        serviceType: 'local_store',
        merchantId: 'sri-lakshmi-general-store',
        productVariantId: '1-kg',
      ),
      2,
    );
    expect(cart.subtotalInPaise, 45000);
    expect(
      cart.addItem(
        productId: 'other-store-item',
        serviceType: 'local_store',
        merchantId: 'venkateswara-stores',
        productVariantId: '1-kg',
        variantLabel: '1 KG',
        name: 'Atta',
        description: '',
        priceInPaise: 7000,
        icon: Icons.inventory_2_rounded,
      ),
      isFalse,
    );
  });

  test(
    'variant availability is independent and legacy products remain intact',
    () {
      availability.setAvailability(
        productId: 'slgs-ashirvad-atta',
        serviceType: 'local_store',
        merchantId: 'sri-lakshmi-general-store',
        isAvailable: true,
      );
      expect(
        availability.isAvailable(
          productId: 'slgs-ashirvad-atta',
          serviceType: 'local_store',
          merchantId: 'sri-lakshmi-general-store',
          variantId: '2-kg',
          defaultAvailable: false,
        ),
        isFalse,
      );

      availability.setAvailability(
        productId: 'slgs-ashirvad-atta',
        serviceType: 'local_store',
        merchantId: 'sri-lakshmi-general-store',
        variantId: '2-kg',
        isAvailable: true,
      );
      expect(
        availability.isAvailable(
          productId: 'slgs-ashirvad-atta',
          serviceType: 'local_store',
          merchantId: 'sri-lakshmi-general-store',
          variantId: '2-kg',
          defaultAvailable: false,
        ),
        isTrue,
      );
      expect(
        CartItem.keyFor(
          serviceType: 'store',
          productId: 'plain-item',
          merchantId: 'store-1',
        ),
        'store:store-1:plain-item',
      );
    },
  );
}

Widget _catalogPage() => LocalStoreCatalogPage(
  store: sampleLocalStores.first,
  categories: const [
    CommonCategory(id: 'atta', name: 'Atta', icon: Icons.grain_rounded),
  ],
  initialCategoryId: 'atta',
  products: const [
    StoreProduct(
      id: 'slgs-ashirvad-atta',
      storeId: 'sri-lakshmi-general-store',
      categoryId: 'atta',
      name: 'Ashirvad Atta',
      brand: 'Aashirvaad',
      description: '',
      packSize: '',
      price: 70,
      mrp: 80,
      discount: 13,
      rating: 4.6,
      available: true,
      variants: _testVariants,
    ),
  ],
);

const _testVariants = [
  ProductVariant(
    id: '1-kg',
    productId: 'slgs-ashirvad-atta',
    label: '1 KG',
    priceInPaise: 7000,
    available: true,
  ),
  ProductVariant(
    id: '2-kg',
    productId: 'slgs-ashirvad-atta',
    label: '2 KG',
    priceInPaise: 13500,
    available: false,
  ),
  ProductVariant(
    id: '5-kg',
    productId: 'slgs-ashirvad-atta',
    label: '5 KG',
    priceInPaise: 31000,
    available: true,
  ),
];
