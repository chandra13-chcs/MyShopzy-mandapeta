import 'dart:async';
import 'dart:convert';

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
  late CustomerApi originalApi;
  CustomerApi? mockApi;

  setUp(() {
    cart.clear();
    originalApi = CustomerApi.instance;
  });
  tearDown(() {
    cart.clear();
    mockApi?.close();
    CustomerApi.instance = originalApi;
  });

  testWidgets('empty cart hides checkout and offers a clear empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CartPage()));

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Continue Shopping'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsNothing);
  });

  testWidgets('cart subtotal and quantity controls stay synchronized', (
    tester,
  ) async {
    cart.addItem(
      productId: 'cart-page-item',
      serviceType: 'local_store',
      merchantId: 'cart-page-store',
      name: 'Cart page item',
      description: 'Test item',
      priceInPaise: 15400,
      icon: Icons.shopping_bag_outlined,
    );
    await tester.pumpWidget(const MaterialApp(home: CartPage()));

    expect(find.text('₹154'), findsNWidgets(3));
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    expect(find.text('₹308'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pumpAndSettle();
    expect(find.text('₹154'), findsNWidgets(3));

    await tester.tap(find.byTooltip('Remove item'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsNothing);
  });

  testWidgets(
    'rapid backend quantity taps send one update and use the server quantity',
    (tester) async {
      final updateResponse = Completer<http.Response>();
      var updateCount = 0;
      _configureBackendCart(
        cart,
        onUpdate: (_) {
          updateCount++;
          return updateResponse.future;
        },
        onApiCreated: (api) {
          mockApi = api;
        },
      );

      await tester.pumpWidget(const MaterialApp(home: CartPage()));
      await tester.pumpAndSettle();
      final increaseButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Increase quantity',
      );

      await tester.tap(increaseButton);
      await tester.tap(increaseButton);
      await tester.pump();
      expect(updateCount, 1);
      expect(cart.items.single.quantity, 1);
      expect(cart.isQuantityMutationPending(cart.items.single.key), isTrue);
      expect(tester.widget<IconButton>(increaseButton).onPressed, isNull);

      updateResponse.complete(
        http.Response(
          jsonEncode({
            'data': {'productId': 'cart-page-backend-item', 'quantity': 3},
          }),
          200,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();

      expect(cart.items.single.quantity, 3);
      expect(cart.isQuantityMutationPending(cart.items.single.key), isFalse);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets('failed backend quantity update keeps the displayed quantity', (
    tester,
  ) async {
    final updateResponse = Completer<http.Response>();
    _configureBackendCart(
      cart,
      onUpdate: (_) => updateResponse.future,
      onApiCreated: (api) {
        mockApi = api;
      },
    );

    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();

    expect(cart.items.single.quantity, 1);
    updateResponse.complete(
      http.Response(
        jsonEncode({
          'error': {
            'code': 'INSUFFICIENT_STOCK',
            'message': 'The requested quantity is no longer available.',
          },
        }),
        409,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();

    expect(cart.items.single.quantity, 1);
    expect(cart.isQuantityMutationPending(cart.items.single.key), isFalse);
    expect(find.text('1'), findsOneWidget);
    expect(
      find.text('The requested quantity is no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets('backend catalog add shows pending without false cart success', (
    tester,
  ) async {
    final addResponse = Completer<http.Response>();
    var addCount = 0;
    final api = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/carts')) {
          return http.Response(
            jsonEncode({
              'data': {'cartToken': 'c' * 43},
            }),
            201,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/cart/items')) {
          addCount++;
          return addResponse.future;
        }
        throw StateError(
          'Unexpected cart API request: ${request.method} ${request.url}',
        );
      }),
    );
    mockApi = api;
    CustomerApi.instance = api;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartProductControl(
            productId: 'backend-product',
            serviceType: 'local_store',
            merchantId: 'backend-shop',
            categoryId: 'groceries',
            name: 'Backend product',
            description: 'Catalog product',
            priceInPaise: 7000,
            icon: Icons.shopping_bag_outlined,
            available: true,
            backendCatalogItem: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pump();

    expect(addCount, 1);
    expect(cart.items, isEmpty);
    expect(
      cart.isCatalogItemAddPending(
        productId: 'backend-product',
        serviceType: 'local_store',
        merchantId: 'backend-shop',
      ),
      isTrue,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    addResponse.complete(
      http.Response(
        jsonEncode({
          'data': {'productId': 'backend-product', 'quantity': 3},
        }),
        200,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();

    expect(cart.items, hasLength(1));
    expect(cart.items.single.productId, 'backend-product');
    expect(cart.items.single.quantity, 3);
    expect(
      cart.isCatalogItemAddPending(
        productId: 'backend-product',
        serviceType: 'local_store',
        merchantId: 'backend-shop',
      ),
      isFalse,
    );
  });

  testWidgets('failed backend catalog add leaves cart empty and reports error', (
    tester,
  ) async {
    final addResponse = Completer<http.Response>();
    final api = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/carts')) {
          return http.Response(
            jsonEncode({
              'data': {'cartToken': 'c' * 43},
            }),
            201,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/cart/items')) {
          return addResponse.future;
        }
        throw StateError(
          'Unexpected cart API request: ${request.method} ${request.url}',
        );
      }),
    );
    mockApi = api;
    CustomerApi.instance = api;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartProductControl(
            productId: 'backend-product',
            serviceType: 'local_store',
            merchantId: 'backend-shop',
            categoryId: 'groceries',
            name: 'Backend product',
            description: 'Catalog product',
            priceInPaise: 7000,
            icon: Icons.shopping_bag_outlined,
            available: true,
            backendCatalogItem: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pump();
    addResponse.complete(
      http.Response(
        jsonEncode({
          'error': {
            'code': 'PRODUCT_UNAVAILABLE',
            'message': 'This product is currently unavailable.',
          },
        }),
        409,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();

    expect(cart.items, isEmpty);
    expect(
      cart.isCatalogItemAddPending(
        productId: 'backend-product',
        serviceType: 'local_store',
        merchantId: 'backend-shop',
      ),
      isFalse,
    );
    expect(find.text('This product is currently unavailable.'), findsOneWidget);
  });
}

void _configureBackendCart(
  CartStore cart, {
  required Future<http.Response> Function(http.Request) onUpdate,
  required void Function(CustomerApi) onApiCreated,
}) {
  final api = CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/carts')) {
        return http.Response(
          jsonEncode({
            'data': {'cartToken': 'c' * 43},
          }),
          201,
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/cart')) {
        return http.Response(
          jsonEncode({
            'data': {
              'items': [
                {
                  'productId': 'cart-page-backend-item',
                  'shopId': 'cart-page-backend-shop',
                  'name': 'Backend cart item',
                  'quantity': 1,
                  'priceMinor': '15400',
                  'currency': 'INR',
                  'available': true,
                },
              ],
              'itemSubtotalMinor': '15400',
            },
          }),
          200,
        );
      }
      if (request.method == 'PATCH') return onUpdate(request);
      throw StateError(
        'Unexpected cart API request: ${request.method} ${request.url}',
      );
    }),
  );
  onApiCreated(api);
  CustomerApi.instance = api;
  cart.addItem(
    productId: 'cart-page-backend-item',
    serviceType: 'backend_catalog',
    merchantId: 'cart-page-backend-shop',
    name: 'Backend cart item',
    description: 'Test item',
    priceInPaise: 15400,
    icon: Icons.shopping_bag_outlined,
    isBackendProduct: true,
  );
}
