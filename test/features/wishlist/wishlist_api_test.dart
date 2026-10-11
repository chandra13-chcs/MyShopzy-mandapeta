import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/product_details/models/product_details_product.dart';
import 'package:myshopzy/features/wishlist/data/wishlist_store.dart';
import 'package:myshopzy/features/wishlist/presentation/save_list_button.dart';
import 'package:myshopzy/features/wishlist/presentation/wishlist_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

const _productId = '33333333-3333-4333-8333-333333333333';
const _shopId = '11111111-1111-4111-8111-111111111111';

void main() {
  final wishlist = WishlistStore.instance;

  setUp(() {
    wishlist.clear();
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  tearDown(() {
    wishlist.clear();
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('loads backend wishlist and removes after server success', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final listResponse = Completer<http.Response>();
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return listResponse.future;
      }
      return http.Response('', 204);
    });

    wishlist.save(_product(id: 'demo-product', isBackendProduct: false));
    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    listResponse.complete(
      _jsonResponse({
        'data': [_wishlistItem()],
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend wishlist'), findsOneWidget);
    expect(find.text('Server Product'), findsOneWidget);
    expect(find.text('Server Shop'), findsOneWidget);
    expect(find.text('Demo Product'), findsNothing);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();
    expect(wishlist.products, isEmpty);
    expect(find.text('Your Wishlist is empty'), findsOneWidget);
    expect(requests.map((request) => request.method), ['GET', 'DELETE']);
    expect(requests.last.url.path, '/api/v1/me/wishlist/items/$_productId');
  });

  testWidgets('adds and removes a product through shared save button', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return _jsonResponse({
          'data': {'productId': _productId, 'saved': true},
        }, statusCode: 201);
      }
      return http.Response('', 204);
    });
    final product = _product(id: _productId, isBackendProduct: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaveListButton(product: product)),
      ),
    );
    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pumpAndSettle();
    expect(wishlist.contains(product), isTrue);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();
    expect(wishlist.contains(product), isFalse);
    expect(requests.map((request) => request.method), ['POST', 'DELETE']);
    expect(requests.first.url.path, '/api/v1/me/wishlist/items');
    expect(jsonDecode(requests.first.body), {'productId': _productId});
    expect(requests.last.url.path, '/api/v1/me/wishlist/items/$_productId');
  });

  testWidgets('shows listing errors and retries without demo fallback', (
    tester,
  ) async {
    var getCount = 0;
    CustomerApi.instance = _api((request) async {
      getCount++;
      if (getCount == 1) {
        return _jsonResponse({
          'error': {
            'code': 'DATABASE_UNAVAILABLE',
            'message': 'Wishlist is temporarily unavailable.',
          },
        }, statusCode: 503);
      }
      return _jsonResponse({
        'data': [_wishlistItem()],
      });
    });

    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    await tester.pumpAndSettle();
    expect(find.text('Wishlist is temporarily unavailable.'), findsOneWidget);
    expect(find.text('Demo Product'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Server Product'), findsOneWidget);
    expect(getCount, 2);
  });

  testWidgets('honestly reports 401 and leaves wishlist unchanged', (
    tester,
  ) async {
    CustomerApi.instance = _api(
      (request) async => _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required for wishlist access.',
        },
      }, statusCode: 401),
    );
    final product = _product(id: _productId, isBackendProduct: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaveListButton(product: product)),
      ),
    );
    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pumpAndSettle();

    expect(wishlist.products, isEmpty);
    expect(
      find.text('Customer authentication is required for wishlist access.'),
      findsOneWidget,
    );
  });

  testWidgets('failed remove keeps backend wishlist item visible', (
    tester,
  ) async {
    CustomerApi.instance = _api(
      (request) async => _jsonResponse({
        'error': {
          'code': 'DATABASE_UNAVAILABLE',
          'message': 'Could not remove wishlist item.',
        },
      }, statusCode: 503),
    );
    final product = _product(id: _productId, isBackendProduct: true);
    wishlist.save(product);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaveListButton(product: product)),
      ),
    );
    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();

    expect(wishlist.contains(product), isTrue);
    expect(find.text('Could not remove wishlist item.'), findsOneWidget);
  });

  testWidgets('wishlist listing shows 401 instead of demo entries', (
    tester,
  ) async {
    wishlist.save(_product());
    CustomerApi.instance = _api(
      (request) async => _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required for wishlist access.',
        },
      }, statusCode: 401),
    );

    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    await tester.pumpAndSettle();

    expect(
      find.text('Customer authentication is required for wishlist access.'),
      findsOneWidget,
    );
    expect(find.text('Demo Product'), findsNothing);
    expect(wishlist.products, isEmpty);
    expect(find.text('Retry'), findsOneWidget);
  });
}

CustomerApi _api(Future<http.Response> Function(http.Request) handler) {
  return CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient(handler),
  );
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode);
}

Map<String, Object?> _wishlistItem() => {
  'product_id': _productId,
  'shop_id': _shopId,
  'name': 'Server Product',
  'description': 'Loaded from the backend',
  'price_minor': '1250',
  'currency': 'INR',
  'is_available': true,
  'available': true,
  'shop_name': 'Server Shop',
};

ProductDetailsProduct _product({
  String id = 'demo-product',
  bool isBackendProduct = false,
}) {
  return ProductDetailsProduct(
    id: id,
    serviceType: 'restaurant',
    merchantId: _shopId,
    merchantName: 'Server Shop',
    name: isBackendProduct ? 'Server Product' : 'Demo Product',
    description: 'Product for wishlist tests',
    icon: Icons.restaurant,
    available: true,
    priceInPaise: 1250,
    isBackendProduct: isBackendProduct,
  );
}
