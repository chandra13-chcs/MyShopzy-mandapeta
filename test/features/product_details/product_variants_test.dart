import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/local_stores/models/local_store.dart';
import 'package:myshopzy/features/local_stores/presentation/local_store_catalog_page.dart';
import 'package:myshopzy/features/product_details/data/product_availability_store.dart';
import 'package:myshopzy/features/product_details/models/product_variant.dart';
import 'package:myshopzy/features/product_details/presentation/product_details_page.dart';
import 'package:myshopzy/features/search/data/search_index.dart';
import 'package:myshopzy/features/search/models/search_result.dart';
import 'package:myshopzy/features/wishlist/data/wishlist_store.dart';
import 'package:myshopzy/features/wishlist/presentation/wishlist_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

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
    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));

    expect(find.text('Sign in to access your wishlist.'), findsOneWidget);
    expect(find.byType(ProductDetailsPage), findsNothing);
    expect(cart.items, isEmpty);
  });

  testWidgets('catalog variants cannot create a cart while signed out', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _catalogPage()));

    expect(find.text('OPTIONS'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, '1 KG'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '2 KG'), findsOneWidget);
    final fiveKg = find.widgetWithText(ChoiceChip, '5 KG');
    await tester.ensureVisible(fiveKg);
    await tester.tap(fiveKg);
    await tester.pumpAndSettle();
    expect(find.text('₹310'), findsOneWidget);

    final addButton = find.text('ADD').last;
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(cart.items, isEmpty);
    expect(find.text('Sign in to add items to your cart.'), findsOneWidget);
  });

  testWidgets(
    'development guest mode adds the selected catalog variant locally',
    (tester) async {
      final previousApi = CustomerApi.instance;
      final guestApi = CustomerApi(
        baseUrl: '',
        enableDevelopmentGuestCart: true,
      );
      CustomerApi.instance = guestApi;
      addTearDown(() {
        guestApi.close();
        CustomerApi.instance = previousApi;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ProductDetailsPage(
            product: ProductDetailsProduct(
              id: 'slgs-ashirvad-atta',
              serviceType: 'local_store',
              merchantId: 'sri-lakshmi-general-store',
              name: 'Ashirvad Atta',
              icon: Icons.inventory_2_rounded,
              available: true,
              isBackendProduct: true,
              variants: _testVariants,
            ),
          ),
        ),
      );

      final fiveKg = find.widgetWithText(ChoiceChip, '5 KG');
      await tester.ensureVisible(fiveKg);
      await tester.tap(fiveKg);
      await tester.pumpAndSettle();

      final addButton = find.text('ADD').last;
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(cart.items, hasLength(1));
      expect(cart.items.single.productVariantId, '5-kg');
      expect(cart.items.single.variantLabel, '5 KG');
      expect(cart.items.single.priceInPaise, 31000);
      expect(cart.items.single.isBackendProduct, isFalse);
      expect(cart.totalQuantity, 1);
      expect(CustomerApi.instance.hasCustomerSession, isFalse);
      expect(cart.hasBackendCart, isFalse);
      expect(find.text('Sign in to add items to your cart.'), findsNothing);

      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();
      expect(cart.items.single.quantity, 2);

      await tester.tap(find.byTooltip('Decrease quantity'));
      await tester.pumpAndSettle();
      expect(cart.items.single.quantity, 1);
    },
  );

  testWidgets('Product Details keeps variant pricing and visible wishlist', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductDetailsPage(product: _detailsProduct())),
    );

    expect(find.text('₹70'), findsOneWidget);
    final saveButton = find.byTooltip('Add to wishlist');
    expect(saveButton, findsOneWidget);
    final saveIcon = tester.widget<Icon>(
      find.byIcon(Icons.bookmark_border_rounded),
    );
    expect(saveIcon.color, Colors.white);

    final fiveKg = find.widgetWithText(ChoiceChip, '5 KG');
    await tester.tap(fiveKg);
    await tester.pumpAndSettle();
    expect(find.text('₹310'), findsOneWidget);
  });

  testWidgets('unavailable variant cannot be added', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _catalogPage()));

    final twoKg = find.widgetWithText(ChoiceChip, '2 KG');
    await tester.ensureVisible(twoKg);
    await tester.tap(twoKg);
    await tester.pumpAndSettle();

    expect(find.text('OUT OF STOCK'), findsOneWidget);
    await tester.tap(find.text('OUT OF STOCK'));
    await tester.pump();
    expect(cart.items, isEmpty);
  });

  test('unauthenticated cart mutation is rejected', () {
    expect(
      () => cart.addItem(
        productId: 'slgs-ashirvad-atta',
        serviceType: 'local_store',
        merchantId: 'sri-lakshmi-general-store',
        productVariantId: '5-kg',
        variantLabel: '5 KG',
        name: 'Ashirvad Atta',
        description: 'Whole wheat flour',
        priceInPaise: 31000,
        icon: Icons.inventory_2_rounded,
      ),
      throwsA(
        isA<CustomerApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(cart.items, isEmpty);
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

ProductDetailsProduct _detailsProduct() => const ProductDetailsProduct(
  id: 'slgs-ashirvad-atta',
  serviceType: 'local_store',
  merchantId: 'sri-lakshmi-general-store',
  name: 'Ashirvad Atta',
  icon: Icons.inventory_2_rounded,
  available: true,
  variants: _testVariants,
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
