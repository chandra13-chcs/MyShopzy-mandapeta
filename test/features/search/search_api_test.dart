 import 'dart:async';
 import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/search/presentation/search_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  late CustomerApi api;

  tearDown(() {
    api.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('shows backend shop and product search results', (tester) async {
    api = _api((request) async {
      if (request.url.path.endsWith('/shops')) {
        return _response([
          {
            'id': 'shop-id',
            'name': 'Fresh Market',
            'partner_type': 'grocery',
            'address': 'Main Road',
            'partner_name': 'Fresh Group',
          },
        ]);
      }
      return _response([
        {
          'id': 'product-id',
          'shop_id': 'shop-id',
          'category_id': 'category-id',
          'name': 'Fresh Apples',
          'description': 'Red apples',
          'price_minor': 12500,
          'currency': 'INR',
          'is_available': true,
          'shop_name': 'Fresh Market',
          'partner_type': 'grocery',
        },
      ]);
    });
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), 'fresh');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Market'), findsNWidgets(2));
    expect(find.text('Fresh Apples'), findsOneWidget);
    expect(find.text('Live catalog · shops and products'), findsOneWidget);
    expect(find.text('Demo search · sample results'), findsNothing);
  });

  testWidgets('shows empty message for empty backend results', (tester) async {
    api = _api((_) async => _response([]));
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    expect(find.text('No results found'), findsOneWidget);
    expect(
      find.textContaining('Live category search is not available'),
      findsOneWidget,
    );
  });

  testWidgets('shows API error without demo data and retries', (tester) async {
    var requestCount = 0;
    var failedShopsRequest = false;
    api = _api((request) async {
      requestCount++;
      if (request.url.path.endsWith('/shops') && !failedShopsRequest) {
        failedShopsRequest = true;
        return http.Response('{"error":{"code":"UNAVAILABLE"}}', 503);
      }
      if (request.url.path.endsWith('/products')) return _response([]);
      return _response([
        {
          'id': 'shop-id',
          'name': 'Retry Market',
          'partner_type': 'grocery',
          'address': 'Main Road',
        },
      ]);
    });
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), 'retry');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    expect(find.text('Search is unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Spice Route Kitchen'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry Market'), findsOneWidget);
    expect(requestCount, 4);
  });

  testWidgets('debounces changed queries and uses only the latest query', (
    tester,
  ) async {
    final queries = <String>[];
    api = _api((request) async {
      queries.add(request.url.queryParameters['q']!);
      return _response([]);
    });
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), 'app');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    expect(queries, ['apple', 'apple']);
  });

  testWidgets('ignores older response when a query is repeated out of order', (
    tester,
  ) async {
    final firstAppleShops = Completer<http.Response>();
    final firstAppleProducts = Completer<http.Response>();
    var appleProductRequests = 0;
    api = _api((request) async {
      final query = request.url.queryParameters['q'];
      if (query == 'apple' && request.url.path.endsWith('/shops')) {
        if (appleProductRequests == 0) return firstAppleShops.future;
        return _response([]);
      }
      if (request.url.path.endsWith('/products') && query == 'apple') {
        appleProductRequests++;
        if (appleProductRequests == 1) return firstAppleProducts.future;
        return _response([
          _productResultJson('Current Apple Result'),
        ]);
      }
      if (query == 'banana' && request.url.path.endsWith('/products')) {
        return _response([_productResultJson('Banana Result')]);
      }
      return _response([]);
    });
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    expect(find.text('Banana Result'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    expect(find.text('Current Apple Result'), findsOneWidget);

    firstAppleShops.complete(_response([]));
    firstAppleProducts.complete(_response([_productResultJson('Stale Apple Result')]));
    await tester.pumpAndSettle();

    expect(find.text('Current Apple Result'), findsOneWidget);
    expect(find.text('Stale Apple Result'), findsNothing);
  });
}

CustomerApi _api(Future<http.Response> Function(http.Request) handler) {
  final api = CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient(handler),
  );
  CustomerApi.instance = api;
  return api;
}

http.Response _response(List<Map<String, Object?>> records) {
  return http.Response(
    jsonEncode({
      'data': records,
      'pagination': {'limit': 20, 'offset': 0},
    }),
    200,
  );
}

Map<String, Object?> _productResultJson(String name) => {
  'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'shop_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'category_id': null,
  'name': name,
  'description': 'Search test product',
  'price_minor': 12500,
  'currency': 'INR',
  'is_available': true,
  'shop_name': 'Fresh Market',
  'partner_type': 'grocery',
};

Future<void> _openSearch(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SearchPage()));
  await tester.pumpAndSettle();
}
