import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/presentation/order_details_page.dart';
import 'package:myshopzy/features/orders/presentation/orders_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

const _orderId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _shopId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _productId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

void main() {
  setUp(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('renders the variant label saved in the order snapshot', (
    tester,
  ) async {
    CustomerApi.instance = _api((request) async {
      expect(request.url.path, '/api/v1/me/orders/$_orderId');
      return _jsonResponse(_orderDetailJson());
    });
    await _authenticate();

    await tester.pumpWidget(
      MaterialApp(home: BackendOrderDetailsPage(order: _backendOrderRecord())),
    );
    await tester.pumpAndSettle();

    expect(find.text('API Product · 500 g × 2'), findsOneWidget);
  });

  testWidgets('loads backend orders and opens order details from API', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final ordersResponse = Completer<http.Response>();
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/me/orders') {
        return ordersResponse.future;
      }
      return _jsonResponse(_orderDetailJson());
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
    expect(find.byKey(const ValueKey('orders-loading')), findsOneWidget);
    ordersResponse.complete(
      _jsonResponse({
        'data': [_orderJson()],
        'pagination': {'limit': 20, 'offset': 0},
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend order history'), findsOneWidget);
    expect(find.text('Backend Shop'), findsOneWidget);
    expect(find.text('placed'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('MSZ-DEMO-1042'), findsNothing);
    expect(requests.single.url.path, '/api/v1/me/orders');
    expect(requests.single.url.queryParameters, {'limit': '20', 'offset': '0'});

    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/v1/me/orders/$_orderId');
    expect(find.byType(BackendOrderDetailsPage), findsOneWidget);

    expect(find.byType(BackendOrderDetailsPage), findsOneWidget);
    expect(find.text('Backend order'), findsOneWidget);
    expect(find.text('API Product · 500 g × 2'), findsOneWidget);
    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('Track Order'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Home · 42 Backend Road'), findsOneWidget);
    expect(find.text('Payment status'), findsNothing);
  });

  testWidgets('shows honest empty backend order history in selected tabs', (
    tester,
  ) async {
    CustomerApi.instance = _api(
      (request) async => _jsonResponse({
        'data': <Object>[],
        'pagination': {'limit': 20, 'offset': 0},
      }),
    );
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
    await tester.pumpAndSettle();
    expect(find.text('Backend order history'), findsOneWidget);
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('MSZ-DEMO-1042'), findsNothing);
    await tester.tap(find.text('Delivered'));
    await tester.pumpAndSettle();
    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('shows list error, retries, and does not display demo orders', (
    tester,
  ) async {
    var getCount = 0;
    CustomerApi.instance = _api((request) async {
      getCount++;
      if (getCount == 1) {
        return _jsonResponse({
          'error': {
            'code': 'DATABASE_UNAVAILABLE',
            'message': 'Order history is temporarily unavailable.',
          },
        }, statusCode: 503);
      }
      return _jsonResponse({
        'data': [_orderJson()],
        'pagination': {'limit': 20, 'offset': 0},
      });
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
    await tester.pumpAndSettle();
    expect(
      find.text('Order history is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(find.text('MSZ-DEMO-1042'), findsNothing);

    await tester.tap(find.text('Retry orders'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Shop'), findsOneWidget);
    expect(getCount, 2);
  });

  testWidgets('shows 401 rather than demo orders or detail data', (
    tester,
  ) async {
    CustomerApi.instance = _api(
      (request) async => _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required for order history.',
        },
      }, statusCode: 401),
    );
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
    await tester.pumpAndSettle();

    expect(
      find.text('Customer authentication is required for order history.'),
      findsOneWidget,
    );
    expect(find.text('MSZ-DEMO-1042'), findsNothing);
    expect(find.text('Retry orders'), findsOneWidget);
  });

  testWidgets('order details reports 401 and offers retry', (tester) async {
    final requests = <http.Request>[];
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/me/orders') {
        return _jsonResponse({
          'data': [_orderJson()],
          'pagination': {'limit': 20, 'offset': 0},
        });
      }
      return _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required for order details.',
        },
      }, statusCode: 401);
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Customer authentication is required for order details.'),
      findsOneWidget,
    );
    expect(find.text('Payment status'), findsNothing);
    expect(requests.last.url.path, '/api/v1/me/orders/$_orderId');
    expect(find.text('Retry order details'), findsOneWidget);
  });

  testWidgets('backend cancellation submits the selected reason once', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return _jsonResponse(_orderDetailJson());
      }
      return _jsonResponse({
        'data': {
          'id': _orderId,
          'status': 'cancelled',
          'cancellation_reason': 'Changed my mind',
        },
      });
    });
    await _authenticate();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      BackendOrderDetailsPage(order: _backendOrderRecord()),
                ),
              ),
              child: const Text('Open order'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open order'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cancel order · 01:30 remaining'),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('Cancel order ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Changed my mind'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();

    final cancellationRequest = requests.singleWhere(
      (request) => request.method == 'POST',
    );
    expect(cancellationRequest.url.path, '/api/v1/me/orders/$_orderId/cancel');
    expect(jsonDecode(cancellationRequest.body), {'reason': 'Changed my mind'});
    expect(find.text('Open order'), findsOneWidget);
  });

  testWidgets('closed cancellation window never exposes the cancel action', (
    tester,
  ) async {
    CustomerApi.instance = _api(
      (request) async => _jsonResponse(
        _orderDetailJson(
          cancellationEligible: false,
          serverNow: '2026-10-11T06:02:00.000Z',
        ),
      ),
    );
    await _authenticate();

    await tester.pumpWidget(
      MaterialApp(home: BackendOrderDetailsPage(order: _backendOrderRecord())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancellation window closed'), findsOneWidget);
    expect(find.textContaining('Cancel order ·'), findsNothing);
  });
}

CustomerApi _api(Future<http.Response> Function(http.Request) handler) {
  return CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/v1/auth/otp/verify') {
        return _jsonResponse({
          'data': {
            'accessToken': 'test-session',
            'tokenType': 'Bearer',
            'expiresIn': 300,
          },
        });
      }
      return handler(request);
    }),
  );
}

Future<void> _authenticate() =>
    CustomerApi.instance.verifyOtp(phoneNumber: '9876543210', otp: '123456');

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode);
}

Map<String, Object?> _orderJson() => {
  'id': _orderId,
  'partner_id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'shop_id': _shopId,
  'shop_name': 'Backend Shop',
  'status': 'placed',
  'currency': 'INR',
  'items_subtotal_minor': '2500',
  'delivery_fee_minor': '300',
  'discount_minor': '0',
  'total_minor': '2800',
  'placed_at': '2026-10-11T06:00:00.000Z',
  'updated_at': '2026-10-11T06:00:00.000Z',
  'cancellation_reason': null,
  'cancellation_deadline_at': '2026-10-11T06:02:00.000Z',
  'server_now': '2026-10-11T06:00:30.000Z',
  'cancellation_eligible': true,
  'item_count': 2,
};

Map<String, Object?> _orderDetailJson({
  bool cancellationEligible = true,
  String serverNow = '2026-10-11T06:00:30.000Z',
}) => {
  'data': {
    'id': _orderId,
    'partner_id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'shop_id': _shopId,
    'shop_name': 'Backend Shop',
    'status': 'placed',
    'currency': 'INR',
    'items_subtotal_minor': '2500',
    'delivery_fee_minor': '300',
    'discount_minor': '0',
    'total_minor': '2800',
    'delivery_address_snapshot': {
      'label': 'Home',
      'formattedAddress': 'Home · 42 Backend Road',
    },
    'placed_at': '2026-10-11T06:00:00.000Z',
    'updated_at': '2026-10-11T06:00:00.000Z',
    'cancellation_reason': null,
    'cancellation_deadline_at': '2026-10-11T06:02:00.000Z',
    'server_now': serverNow,
    'cancellation_eligible': cancellationEligible,
    'rider': null,
    'items': [
      {
        'product_id': _productId,
        'product_name_snapshot': 'API Product',
        'sku_snapshot': 'SKU-1',
        'unit_price_minor': '1250',
        'quantity': 2,
        'line_total_minor': '2500',
        'currency': 'INR',
        'variant_snapshot': {
          'variantId': 'variant-id',
          'label': '500 g',
          'unit': 'g',
          'quantity': 500,
          'sku': 'SKU-1',
          'unitPriceMinor': '1250',
        },
      },
    ],
  },
};

OrderRecord _backendOrderRecord() => OrderRecord(
  storeName: 'Backend Shop',
  icon: Icons.storefront_outlined,
  orderId: _orderId,
  dateTime: '2026-10-11T06:00:00.000Z',
  itemSummary: 'API Product',
  totalInPaise: 2800,
  status: 'placed',
  statusMessage: 'Order placed',
  orderTab: OrdersTab.ongoing,
  serviceType: 'local_store',
  items: const [],
  deliveryAddress: 'Home · 42 Backend Road',
  paymentMethod: 'UPI',
  paymentStatus: 'Pending',
  deliveryChargeInPaise: 300,
  discountInPaise: 0,
  isBackendData: true,
);
