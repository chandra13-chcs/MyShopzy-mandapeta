import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_access_button.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  final cart = CartStore.instance;
  final requests = <http.Request>[];
  late CustomerApi demoApi;

  setUp(() {
    cart.clear();
    requests.clear();
    demoApi = CustomerApi(
      baseUrl: 'https://shop.example',
      enableDevelopmentGuestCart: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 500);
      }),
    );
    CustomerApi.instance = demoApi;
  });

  tearDown(() {
    cart.clear();
    demoApi.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  test('development demo adds catalog items only to the local cart', () async {
    expect(demoApi.isDevelopmentDemoMode, isTrue);
    expect(demoApi.canAccessCustomerFeatures, isTrue);
    expect(demoApi.hasCustomerSession, isFalse);

    final added = await cart.addCatalogItem(
      productId: 'demo-product',
      serviceType: 'local_store',
      merchantId: 'demo-store',
      categoryId: 'demo-category',
      productVariantId: 'demo-variant',
      variantLabel: '1 kg',
      name: 'Demo Rice',
      description: 'UI preview item',
      priceInPaise: 10000,
      icon: Icons.shopping_bag_outlined,
    );

    expect(added, isTrue);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.isBackendProduct, isFalse);
    expect(cart.hasBackendCart, isFalse);
    expect(cart.isDevelopmentDemoCart, isTrue);
    expect(requests, isEmpty);
  });

  test('development demo cannot label a local item as backend-owned', () {
    expect(
      () => cart.addItem(
        productId: 'demo-product',
        serviceType: 'local_store',
        merchantId: 'demo-store',
        name: 'Demo Rice',
        description: 'UI preview item',
        priceInPaise: 10000,
        icon: Icons.shopping_bag_outlined,
        isBackendProduct: true,
      ),
      throwsA(
        isA<CustomerApiException>().having(
          (error) => error.code,
          'code',
          'DEMO_CART_CANNOT_OWN_BACKEND_ITEMS',
        ),
      ),
    );
    expect(cart.items, isEmpty);
    expect(cart.hasBackendCart, isFalse);
    expect(requests, isEmpty);
  });

  testWidgets('demo cart quantity, totals, and item removal are local', (
    tester,
  ) async {
    await _addDemoItem(cart);
    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await tester.pumpAndSettle();

    expect(find.text('Demo Rice'), findsOneWidget);
    expect(
      find.text(
        'Demo cart · UI preview only; no order or payment will be submitted.',
      ),
      findsOneWidget,
    );
    expect(find.text('₹100'), findsWidgets);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    expect(cart.items.single.quantity, 2);
    expect(find.text('₹200'), findsWidgets);

    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pumpAndSettle();
    expect(cart.items.single.quantity, 1);
    expect(find.text('₹100'), findsWidgets);

    await tester.tap(find.byTooltip('Remove item'));
    await tester.pumpAndSettle();
    expect(cart.items, isEmpty);
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('shared Add controls cover every customer shopping category', (
    tester,
  ) async {
    const categories =
        <
          ({
            String name,
            String serviceType,
            String? merchantId,
            bool backendCatalogItem,
          })
        >[
          (
            name: 'Restaurant',
            serviceType: 'restaurant',
            merchantId: 'restaurant-demo',
            backendCatalogItem: true,
          ),
          (
            name: 'Bakery',
            serviceType: 'bakery',
            merchantId: 'bakery-demo',
            backendCatalogItem: false,
          ),
          (
            name: 'Grocery / Shopsy Mart',
            serviceType: 'local_store',
            merchantId: 'store-demo',
            backendCatalogItem: true,
          ),
          (
            name: 'Meat',
            serviceType: 'meat',
            merchantId: 'meat-demo',
            backendCatalogItem: false,
          ),
          (
            name: 'Vegetables & Fruits',
            serviceType: 'vegetables_fruits',
            merchantId: null,
            backendCatalogItem: false,
          ),
          (
            name: 'Product details / other catalog entry',
            serviceType: 'catalog',
            merchantId: 'other-demo',
            backendCatalogItem: true,
          ),
        ];

    for (final (index, category) in categories.indexed) {
      cart.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartProductControl(
              key: ValueKey(category.name),
              productId: 'demo-product-$index',
              serviceType: category.serviceType,
              merchantId: category.merchantId,
              productVariantId: category.backendCatalogItem
                  ? 'demo-variant-$index'
                  : null,
              variantLabel: category.backendCatalogItem ? '1 unit' : null,
              categoryId: 'demo-category',
              name: '${category.name} item',
              description: 'Local category preview item',
              priceInPaise: 12500,
              icon: Icons.shopping_bag_outlined,
              available: true,
              backendCatalogItem: category.backendCatalogItem,
            ),
          ),
        ),
      );
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      expect(
        cart.items,
        hasLength(1),
        reason: '${category.name} Add control should add to local cart',
      );
      expect(cart.items.single.serviceType, category.serviceType);
      expect(cart.items.single.isBackendProduct, isFalse);
      expect(cart.hasBackendCart, isFalse);
      expect(cart.isDevelopmentDemoCart, isTrue);
      expect(requests, isEmpty);
      expect(find.text('Sign in to add items to your cart.'), findsNothing);
    }
  });

  testWidgets('demo mode renders an empty cart without a session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Sign in to access your cart.'), findsNothing);
    expect(find.text('Proceed to Checkout'), findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets('category cart button opens the local demo cart', (tester) async {
    await _addDemoItem(cart);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [CartAccessButton()]),
          body: const SizedBox.expand(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined).first);
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsOneWidget);
    expect(find.text('Demo Rice'), findsOneWidget);
    expect(cart.hasBackendCart, isFalse);
    expect(requests, isEmpty);
  });

  testWidgets('demo cart can navigate to UI-only checkout but cannot submit', (
    tester,
  ) async {
    await _addDemoItem(cart);
    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('checkout-demo-mode-banner')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Orders and payments are disabled.'),
      findsOneWidget,
    );
    final demoCheckoutButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Demo Checkout · UI Only'),
    );
    expect(demoCheckoutButton.onPressed, isNull);
    expect(demoApi.hasCustomerSession, isFalse);
    expect(cart.hasBackendCart, isFalse);
    expect(find.text('₹130'), findsWidgets);
    expect(requests, isEmpty);
  });

  test('demo mode does not authorize protected cart API requests', () async {
    final protectedCalls = <Future<Object?> Function()>[
      demoApi.getCart,
      () => demoApi.placeOrder(const {'formattedAddress': 'Test address'}),
      () => demoApi.verifyRazorpayPayment(
        orderId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        razorpayOrderId: 'order_test',
        razorpayPaymentId: 'payment_test',
        razorpaySignature: 'signature',
      ),
    ];
    for (final call in protectedCalls) {
      await expectLater(
        call(),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'AUTHENTICATION_REQUIRED',
          ),
        ),
      );
    }
    expect(demoApi.hasCustomerSession, isFalse);
    expect(requests, isEmpty);
  });
}

Future<void> _addDemoItem(CartStore cart) async {
  final added = await cart.addCatalogItem(
    productId: 'demo-product',
    serviceType: 'local_store',
    merchantId: 'demo-store',
    categoryId: 'demo-category',
    productVariantId: 'demo-variant',
    variantLabel: '1 kg',
    name: 'Demo Rice',
    description: 'UI preview item',
    priceInPaise: 10000,
    icon: Icons.shopping_bag_outlined,
  );
  expect(added, isTrue);
}
