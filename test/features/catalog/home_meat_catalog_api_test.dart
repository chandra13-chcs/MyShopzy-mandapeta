import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/bakery/presentation/bakery_page.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/meat/presentation/meat_page.dart';
import 'package:myshopzy/features/vegetables_fruits/presentation/vegetables_fruits_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

const _shopId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _productId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  late CustomerApi api;

  setUp(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  tearDown(() {
    api.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('Home shows live shops and products without demo discovery', (
    tester,
  ) async {
    final requests = <http.Request>[];
    api = _api((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/shops')) {
        return _listResponse([_shopJson]);
      }
      return _listResponse([_productJson]);
    });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-live-catalog')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Live shops'), findsOneWidget);
    expect(find.text('Fresh Market'), findsWidgets);
    expect(find.text('Live products'), findsOneWidget);
    expect(find.text('Backend Apples'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('Demo offer · not verified by backend'), findsNothing);
    expect(
      find.text('Demo home catalog · sample shops and products'),
      findsNothing,
    );
    expect(requests.map((request) => request.url.path).toSet(), {
      '/api/v1/shops',
      '/api/v1/products',
    });
  });

  testWidgets('Home live grocery shop opens its scoped backend catalog', (
    tester,
  ) async {
    final requests = <http.Request>[];
    api = _api((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/shops')) {
        return _listResponse([_shopJson]);
      }
      return _listResponse([]);
    });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    final shopCard = find.byKey(const ValueKey('home-live-shop-$_shopId'));
    await tester.scrollUntilVisible(
      shopCard,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(shopCard);
    await tester.pumpAndSettle();

    expect(find.text('Backend catalog'), findsOneWidget);
    expect(
      requests.any(
        (request) => request.url.path == '/api/v1/shops/$_shopId/categories',
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) =>
            request.url.path == '/api/v1/products' &&
            request.url.queryParameters['shopId'] == _shopId,
      ),
      isTrue,
    );
  });

  testWidgets('Home indicates loading, empty results, and retries API errors', (
    tester,
  ) async {
    final firstShopResponse = Completer<http.Response>();
    final firstProductResponse = Completer<http.Response>();
    var initialRequest = true;
    api = _api((request) async {
      if (initialRequest) {
        if (request.url.path.endsWith('/shops')) {
          return firstShopResponse.future;
        }
        return firstProductResponse.future;
      }
      return _listResponse([]);
    });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-live-catalog')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    initialRequest = false;
    firstShopResponse.complete(
      http.Response('{"error":{"code":"UNAVAILABLE"}}', 503),
    );
    firstProductResponse.complete(_listResponse([]));
    await tester.pumpAndSettle();

    expect(find.text('Live catalog unavailable'), findsOneWidget);
    expect(find.text('Retry catalog'), findsOneWidget);
    expect(find.text('Demo Biryani Kitchen'), findsNothing);

    await tester.tap(find.text('Retry catalog'));
    await tester.pumpAndSettle();
    expect(
      find.text('No live shops or products are available right now.'),
      findsOneWidget,
    );
    expect(find.text('Demo Biryani Kitchen'), findsNothing);
  });

  testWidgets('Meat page queries supported meat_shop products and shows them', (
    tester,
  ) async {
    http.Request? request;
    final productResponse = Completer<http.Response>();
    api = _api((currentRequest) async {
      request = currentRequest;
      return productResponse.future;
    });

    await tester.pumpWidget(const MaterialApp(home: MeatPage()));
    await tester.pump();
    expect(find.text('Demo chicken and mutton categories'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(CircularProgressIndicator),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    productResponse.complete(_listResponse([_productJson]));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Live meat shop products'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(request?.url.path, '/api/v1/products');
    expect(request?.url.queryParameters['partnerType'], 'meat_shop');
    expect(find.text('Backend Apples'), findsOneWidget);
    expect(
      find.text('The catalog does not identify chicken versus mutton.'),
      findsOneWidget,
    );
  });

  testWidgets('Meat page shows empty response and retry on API error', (
    tester,
  ) async {
    var failed = false;
    api = _api((_) async {
      if (!failed) {
        failed = true;
        return http.Response('{"error":{"code":"UNAVAILABLE"}}', 503);
      }
      return _listResponse([]);
    });

    await tester.pumpWidget(const MaterialApp(home: MeatPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Retry meat catalog'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry meat catalog'), findsOneWidget);
    expect(find.text('Whole Chicken, Skinless'), findsNothing);
    await tester.tap(find.text('Retry meat catalog'));
    await tester.pumpAndSettle();
    expect(
      find.text('No live meat products are available right now.'),
      findsOneWidget,
    );
  });

  testWidgets('unsupported bakery and produce catalogs are labeled demo', (
    tester,
  ) async {
    var requestSent = false;
    api = _api((_) async {
      requestSent = true;
      return _listResponse([]);
    });

    await tester.pumpWidget(const MaterialApp(home: BakeryPage()));
    expect(
      find.text('Demo bakery catalog · the API has no bakery partner type.'),
      findsOneWidget,
    );
    expect(find.text('Sri Sai Bakery'), findsOneWidget);
    expect(requestSent, isFalse);

    await tester.pumpWidget(const MaterialApp(home: VegetablesFruitsPage()));
    expect(
      find.text(
        'Demo produce catalog · the API cannot distinguish produce from other shops.',
      ),
      findsOneWidget,
    );
    expect(requestSent, isFalse);
  });
}

CustomerApi _api(Future<http.Response> Function(http.Request) handler) {
  final instance = CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient(handler),
  );
  CustomerApi.instance = instance;
  return instance;
}

http.Response _listResponse(List<Map<String, Object?>> records) {
  return http.Response(
    jsonEncode({
      'data': records,
      'pagination': {'limit': 20, 'offset': 0},
    }),
    200,
  );
}

final Map<String, Object?> _shopJson = {
  'id': _shopId,
  'name': 'Fresh Market',
  'partner_type': 'grocery',
  'address': 'Main Road',
  'partner_name': 'Fresh Group',
};

final Map<String, Object?> _productJson = {
  'id': _productId,
  'shop_id': _shopId,
  'category_id': null,
  'name': 'Backend Apples',
  'description': 'Catalog apples',
  'price_minor': 12500,
  'currency': 'INR',
  'is_available': true,
  'shop_name': 'Fresh Market',
  'partner_type': 'meat_shop',
};
