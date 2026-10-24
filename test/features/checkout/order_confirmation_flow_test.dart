import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/checkout/presentation/delivery_unavailable_page.dart';
import 'package:myshopzy/features/orders/presentation/order_success_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  final cart = CartStore.instance;

  setUp(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
    cart.clear();
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
    cart.clear();
  });

  testWidgets('demo Place Order confirms once and clears the cart', (
    tester,
  ) async {
    cart.addItem(
      productId: 'order-confirmation-test-item',
      serviceType: 'local_store',
      merchantId: 'order-confirmation-test-store',
      name: 'Test item',
      description: '',
      priceInPaise: 12000,
      icon: Icons.shopping_bag_outlined,
    );
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    final placeOrder = find.widgetWithText(FilledButton, 'Place Order');
    expect(tester.widget<FilledButton>(placeOrder).onPressed, isNull);

    await tester.ensureVisible(find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(placeOrder).onPressed, isNotNull);
    await tester.ensureVisible(placeOrder);
    await tester.tap(placeOrder);
    await tester.pumpAndSettle();

    expect(find.byType(OrderSuccessPage), findsOneWidget);
    expect(find.text('Order placed for'), findsOneWidget);
    expect(cart.items, isEmpty);
  });

  testWidgets('successful backend order opens success page with server data', (
    tester,
  ) async {
    final requests = <http.Request>[];
    _configureBackend((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/orders')) {
        return _response({
          'data': {
            'orderId': 'confirmed-order-id',
            'status': 'placed',
            'currency': 'INR',
            'itemSubtotalMinor': '25000',
            'deliveryFeeMinor': '0',
            'discountMinor': '0',
            'totalMinor': '25000',
            'items': 1,
          },
        }, statusCode: 201);
      }
      if (request.url.path.endsWith('/me/orders/confirmed-order-id')) {
        return _backendOrderDetailResponse();
      }
      return _backendSetupResponse(request);
    });
    _addBackendCartItem();

    await _openBackendCheckout(tester);
    await tester.ensureVisible(find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    final placeOrder = find.widgetWithText(FilledButton, 'Place Order');
    expect(find.text('Platform Fee'), findsOneWidget);
    expect(find.text('₹10'), findsOneWidget);
    await tester.ensureVisible(placeOrder);
    await tester.tap(placeOrder);
    await tester.pumpAndSettle();

    expect(find.byType(OrderSuccessPage), findsOneWidget);
    expect(find.text('Order placed for'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Order ID: confirmed-order-id'), findsOneWidget);
    final successPage = tester.widget<OrderSuccessPage>(
      find.byType(OrderSuccessPage),
    );
    expect(successPage.confirmedOrder.status, 'placed');
    expect(successPage.confirmedOrder.totalInPaise, 25000);
    expect(successPage.confirmedOrder.isBackendData, isTrue);
    expect(cart.items, isEmpty);
    final orderRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/orders'),
    );
    final quoteRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/checkout/quote'),
    );
    expect(jsonDecode(quoteRequest.body), {
      'deliveryAddress': {
        'formattedAddress': 'Home · 12 Green Park Road, Ravulapalem',
        'pincode': '533308',
        'latitude': 16.87,
        'longitude': 81.93,
      },
    });
    expect(jsonDecode(orderRequest.body), {
      'deliveryAddress': {
        'label': 'Home',
        'formattedAddress': 'Home · 12 Green Park Road, Ravulapalem',
        'pincode': '533308',
        'latitude': 16.87,
        'longitude': 81.93,
      },
    });

    expect(
      find.byKey(const ValueKey('order-success-track-order')),
      findsOneWidget,
    );
  });

  testWidgets(
    'unserviceable addresses stop checkout and allow changing location',
    (tester) async {
      var orderRequests = 0;
      _configureBackend((request) async {
        if (request.url.path.endsWith('/orders')) {
          orderRequests++;
        }
        if (request.url.path.endsWith('/checkout/quote')) {
          return _response({
            'data': {
              'items': const [],
              'currency': 'INR',
              'itemSubtotalMinor': '25000',
              'deliveryFeeMinor': null,
              'platformFeeMinor': null,
              'discountMinor': '0',
              'totalMinor': null,
              'isDeliverable': false,
              'message': "Sorry! We don't deliver here yet",
              'distanceMeters': 18001,
              'storeOpen': true,
            },
          });
        }
        return _backendSetupResponse(request);
      });
      _addBackendCartItem();

      await _openBackendCheckout(tester);
      await tester.ensureVisible(find.text('Change'));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(find.byType(ServiceabilityUnavailablePage), findsNothing);
      expect(find.text("Sorry! We don't deliver here yet"), findsOneWidget);
      expect(orderRequests, 0);
      expect(cart.totalQuantity, 1);

      await tester.tap(find.text('Change Location'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(find.text('Choose Delivery Location'), findsOneWidget);
    },
  );

  testWidgets(
    'saved addresses without coordinates cannot receive a fee or total',
    (tester) async {
      var quoteRequests = 0;
      _configureBackend((request) async {
        if (request.url.path.endsWith('/checkout/quote')) {
          quoteRequests++;
        }
        if (request.url.path.endsWith('/me/addresses')) {
          return _response({
            'data': [
              {
                'id': 'address-without-coordinates',
                'label': 'Home',
                'address_snapshot': {
                  'formattedAddress': '12 Green Park Road, Ravulapalem',
                  'pincode': '533308',
                },
              },
            ],
          });
        }
        return _backendSetupResponse(request);
      });
      _addBackendCartItem();

      await _openBackendCheckout(tester);
      await tester.ensureVisible(find.text('Change'));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(quoteRequests, 0);
      expect(
        find.text(
          'This address needs a valid pincode and map coordinates to calculate delivery.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('checkout-total-value')))
            .data,
        'Unavailable',
      );
    },
  );

  testWidgets('401 order failure stays at checkout and preserves cart', (
    tester,
  ) async {
    var orderRequests = 0;
    _configureBackend((request) async {
      if (request.url.path.endsWith('/orders')) {
        orderRequests++;
        return _response({
          'error': {
            'code': 'AUTHENTICATION_REQUIRED',
            'message': 'Customer authentication is required to place an order.',
          },
        }, statusCode: 401);
      }
      return _backendSetupResponse(request);
    });
    _addBackendCartItem();

    await _openBackendCheckout(tester);
    await _selectBackendAddressAndPlaceOrder(tester);

    expect(find.byType(OrderSuccessPage), findsNothing);
    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(
      find.text('Customer authentication is required to place an order.'),
      findsOneWidget,
    );
    expect(cart.totalQuantity, 1);
    final placeOrder = find.widgetWithText(FilledButton, 'Place Order');
    expect(tester.widget<FilledButton>(placeOrder).onPressed, isNotNull);
    await tester.ensureVisible(placeOrder);
    await tester.tap(placeOrder);
    await tester.pumpAndSettle();
    expect(orderRequests, 2);
    expect(cart.totalQuantity, 1);
    expect(CustomerApi.instance.orderOutcomeUnknown, isFalse);
  });

  testWidgets(
    'timed out backend order keeps cart and prevents a duplicate submission',
    (tester) async {
      var orderRequests = 0;
      _configureBackend((request) async {
        if (request.url.path.endsWith('/orders')) {
          orderRequests++;
          throw TimeoutException('simulated order response timeout');
        }
        return _backendSetupResponse(request);
      });
      _addBackendCartItem();

      await _openBackendCheckout(tester);
      await _selectBackendAddressAndPlaceOrder(tester);

      expect(find.byType(OrderSuccessPage), findsNothing);
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('checkout-order-outcome-unknown')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Order status is unknown. Your cart has been kept. Do not submit again until you have checked with customer support.',
        ),
        findsOneWidget,
      );
      expect(cart.totalQuantity, 1);
      expect(CustomerApi.instance.orderOutcomeUnknown, isTrue);
      expect(orderRequests, 1);

      final disabledButton = find.widgetWithText(
        FilledButton,
        'Order Status Unknown',
      );
      expect(tester.widget<FilledButton>(disabledButton).onPressed, isNull);
      await expectLater(
        CustomerApi.instance.placeOrder({'formattedAddress': 'Main Road'}),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'ORDER_OUTCOME_UNKNOWN',
          ),
        ),
      );
      await expectLater(
        cart.refreshBackendCart(),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'ORDER_OUTCOME_UNKNOWN',
          ),
        ),
      );
      expect(orderRequests, 1);
      expect(cart.totalQuantity, 1);
    },
  );

  testWidgets('invalid successful response does not confirm or clear cart', (
    tester,
  ) async {
    _configureBackend((request) async {
      if (request.url.path.endsWith('/orders')) {
        return _response({
          'data': {'orderId': 'unverified-order', 'status': 'pending'},
        }, statusCode: 201);
      }
      return _backendSetupResponse(request);
    });
    _addBackendCartItem();

    await _openBackendCheckout(tester);
    await _selectBackendAddressAndPlaceOrder(tester);

    expect(find.byType(OrderSuccessPage), findsNothing);
    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(
      find.text('Order status is unknown. Do not submit again until checked.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('checkout-order-outcome-unknown')),
      findsOneWidget,
    );
    expect(CustomerApi.instance.orderOutcomeUnknown, isTrue);
    expect(cart.totalQuantity, 1);
  });

  testWidgets('network order failure does not confirm or clear cart', (
    tester,
  ) async {
    _configureBackend((request) async {
      if (request.url.path.endsWith('/orders')) {
        throw http.ClientException('offline');
      }
      return _backendSetupResponse(request);
    });
    _addBackendCartItem();

    await _openBackendCheckout(tester);
    await _selectBackendAddressAndPlaceOrder(tester);

    expect(find.byType(OrderSuccessPage), findsNothing);
    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(
      find.text('Order status is unknown. Do not submit again until checked.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('checkout-order-outcome-unknown')),
      findsOneWidget,
    );
    expect(CustomerApi.instance.orderOutcomeUnknown, isTrue);
    expect(cart.totalQuantity, 1);
  });
}

void _configureBackend(Future<http.Response> Function(http.Request) handler) {
  CustomerApi.instance = CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient(handler),
  );
}

http.Response _backendSetupResponse(http.Request request) {
  if (request.url.path.endsWith('/carts')) {
    return _response({
      'data': {'cartToken': 'a' * 43},
    }, statusCode: 201);
  }
  if (request.url.path.endsWith('/checkout/quote')) {
    return _response({
      'data': {
        'items': [
          {
            'productId': 'product-id',
            'variantId': 'variant-id',
            'variantLabel': '500 g',
            'name': 'Backend product',
            'quantity': 1,
            'priceMinor': '25000',
            'lineTotalMinor': '25000',
          },
        ],
        'currency': 'INR',
        'itemSubtotalMinor': '25000',
        'deliveryFeeMinor': '3000',
        'platformFeeMinor': '1000',
        'discountMinor': '0',
        'totalMinor': '29000',
        'isDeliverable': true,
        'message': 'Delivery is available at this location.',
        'distanceMeters': 4000,
        'storeOpen': true,
        'opensAt': '07:00',
        'closesAt': '22:00',
      },
    });
  }
  if (request.url.path.endsWith('/delivery/serviceability')) {
    return _response({
      'data': {
        'isDeliverable': true,
        'message': 'Delivery is available at this location.',
      },
    });
  }
  if (request.url.path.endsWith('/me/addresses')) {
    return _response({
      'data': [
        {
          'id': 'address-id',
          'label': 'Home',
          'address_snapshot': {
            'formattedAddress': 'Home · 12 Green Park Road, Ravulapalem',
            'pincode': '533308',
            'latitude': 16.87,
            'longitude': 81.93,
          },
        },
      ],
    });
  }
  return _response({
    'error': {'message': 'Unexpected request'},
  }, statusCode: 404);
}

http.Response _backendOrderDetailResponse() => _response({
  'data': {
    'id': 'confirmed-order-id',
    'partner_id': 'partner-id',
    'shop_id': 'shop-id',
    'shop_name': 'Backend Shop',
    'status': 'placed',
    'currency': 'INR',
    'items_subtotal_minor': '25000',
    'delivery_fee_minor': '0',
    'discount_minor': '0',
    'total_minor': '25000',
    'delivery_address_snapshot': {
      'label': 'Home',
      'formattedAddress': 'Home · 12 Green Park Road, Ravulapalem',
    },
    'placed_at': '2026-10-11T06:00:00.000Z',
    'items': [
      {
        'product_id': 'product-id',
        'product_name_snapshot': 'Backend product',
        'sku_snapshot': null,
        'unit_price_minor': '25000',
        'quantity': 1,
        'line_total_minor': '25000',
        'currency': 'INR',
        'variant_snapshot': {
          'variantId': 'variant-id',
          'label': '500 g',
          'unit': 'g',
          'quantity': 500,
          'sku': 'SKU-500',
          'unitPriceMinor': '25000',
        },
      },
    ],
  },
});

http.Response _response(Object body, {int statusCode = 200}) =>
    http.Response(jsonEncode(body), statusCode);

void _addBackendCartItem() {
  CartStore.instance.addItem(
    productId: 'product-id',
    productVariantId: 'variant-id',
    variantLabel: '500 g',
    serviceType: 'backend_catalog',
    merchantId: 'shop-id',
    name: 'Backend product',
    description: '',
    priceInPaise: 25000,
    icon: Icons.shopping_bag_outlined,
    isBackendProduct: true,
  );
}

Future<void> _openBackendCheckout(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
  await tester.pumpAndSettle();
}

Future<void> _selectBackendAddressAndPlaceOrder(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Change'));
  await tester.tap(find.text('Change'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Home').last);
  await tester.pumpAndSettle();
  final placeOrder = find.widgetWithText(FilledButton, 'Place Order');
  await tester.ensureVisible(placeOrder);
  await tester.tap(placeOrder);
  await tester.pumpAndSettle();
}
