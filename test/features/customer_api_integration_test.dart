import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/local_stores/presentation/local_stores_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurant_menu_page.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurants_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  final shopId = '11111111-1111-4111-8111-111111111111';
  final categoryId = '22222222-2222-4222-8222-222222222222';
  final productId = '33333333-3333-4333-8333-333333333333';

  tearDown(() {
    CartStore.instance.clear();
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('loads backend shops, categories, and products into cart', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/shops') {
          return _jsonResponse({
            'data': [
              {
                'id': shopId,
                'name': 'Backend Kitchen',
                'partner_type': 'restaurant',
                'address': 'Main Road',
                'partner_name': 'Kitchen Group',
              },
            ],
          });
        }
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({
            'data': [
              {
                'id': categoryId,
                'shop_id': shopId,
                'name': 'Meals',
                'parent_category_id': null,
              },
            ],
          });
        }
        if (request.url.path == '/api/v1/products/$productId') {
          return _jsonResponse({
            'data': {
              'id': productId,
              'shop_id': shopId,
              'category_id': categoryId,
              'name': 'Fresh Backend Rice Meal',
              'description': 'Price refreshed from PostgreSQL',
              'price_minor': '1300',
              'currency': 'INR',
              'is_available': true,
              'variants': [
                {
                  'id': '44444444-4444-4444-8444-444444444444',
                  'label': '1 serving',
                  'unit': 'each',
                  'quantity': 1,
                  'price_minor': '1300',
                  'is_available': true,
                  'sku': null,
                  'stock': null,
                },
              ],
            },
          });
        }
        if (request.url.path == '/api/v1/products') {
          return _jsonResponse({
            'data': [
              {
                'id': productId,
                'shop_id': shopId,
                'category_id': categoryId,
                'name': 'Backend Rice Meal',
                'description': 'Fresh meal',
                'price_minor': '1250',
                'currency': 'INR',
                'is_available': true,
                'variants': [
                  {
                    'id': '44444444-4444-4444-8444-444444444444',
                    'label': '1 serving',
                    'unit': 'each',
                    'quantity': 1,
                    'price_minor': '1250',
                    'is_available': true,
                    'sku': null,
                    'stock': null,
                  },
                ],
              },
            ],
          });
        }
        return _jsonResponse({
          'error': {'code': 'NOT_FOUND'},
        }, statusCode: 404);
      }),
    );
    CartStore.instance.clear();

    await tester.pumpWidget(const MaterialApp(home: RestaurantsPage()));
    await _pumpFor(tester);
    expect(find.text('Backend catalog'), findsOneWidget);
    expect(find.text('Backend Kitchen'), findsOneWidget);
    expect(find.text('4.5'), findsNothing);

    await tester.tap(find.text('Backend Kitchen'));
    await _pumpFor(tester);
    expect(find.text('Backend Rice Meal'), findsOneWidget);
    expect(
      find.text('Dietary details are not provided by the catalog.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await _pumpFor(tester);
    await tester.tap(find.text('ADD'));
    await _pumpFor(tester);

    expect(CartStore.instance.items, isEmpty);
    expect(
      requests.map((request) => request.url.path),
      contains('/api/v1/shops'),
    );
    expect(
      requests.map((request) => request.url.path),
      contains('/api/v1/shops/$shopId/categories'),
    );
    expect(
      requests.map((request) => request.url.path),
      contains('/api/v1/products'),
    );
    expect(
      requests.map((request) => request.url.path),
      isNot(contains('/api/v1/carts')),
    );
    await tester.tap(find.text('Backend Rice Meal'));
    await _pumpFor(tester);
    expect(find.text('Fresh Backend Rice Meal'), findsOneWidget);
    expect(find.text('Backend catalog product'), findsOneWidget);
    expect(
      requests.map((request) => request.url.path),
      contains('/api/v1/products/$productId'),
    );

    expect(
      requests.map((request) => request.url.path),
      isNot(contains('/api/v1/carts')),
    );
    expect(
      requests.map((request) => request.url.path),
      isNot(contains('/api/v1/cart/items')),
    );
    expect(
      requests.map((request) => request.url.path),
      isNot(contains('/api/v1/checkout/quote')),
    );
    expect(
      requests.map((request) => request.url.path),
      isNot(contains('/api/v1/orders')),
    );
  });

  testWidgets(
    'shows a retryable restaurant API error without substituting demo data',
    (tester) async {
      var attempts = 0;
      CustomerApi.instance = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          attempts++;
          if (attempts == 1) {
            return _jsonResponse({
              'error': {'code': 'DATABASE_UNAVAILABLE'},
            }, statusCode: 503);
          }
          return _jsonResponse({
            'data': [
              {
                'id': shopId,
                'name': 'Recovered Kitchen',
                'partner_type': 'restaurant',
                'address': 'Market Road',
              },
            ],
          });
        }),
      );

      await tester.pumpWidget(const MaterialApp(home: RestaurantsPage()));
      await _pumpFor(tester);

      expect(find.text('Could not load restaurants.'), findsOneWidget);
      expect(find.text('Spice Route Kitchen'), findsNothing);
      await tester.tap(find.text('Retry restaurants'));
      await _pumpFor(tester);
      expect(find.text('Recovered Kitchen'), findsOneWidget);
      expect(attempts, 2);
    },
  );

  testWidgets(
    'shows a retryable local-store API error without substituting demo data',
    (tester) async {
      var attempts = 0;
      CustomerApi.instance = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          attempts++;
          if (attempts == 1) {
            return _jsonResponse({
              'error': {'code': 'DATABASE_UNAVAILABLE'},
            }, statusCode: 503);
          }
          return _jsonResponse({
            'data': [
              {
                'id': shopId,
                'name': 'Recovered Grocery',
                'partner_type': 'grocery',
                'address': 'Market Road',
              },
            ],
          });
        }),
      );

      await tester.pumpWidget(const MaterialApp(home: LocalStoresPage()));
      await _pumpFor(tester);

      expect(find.text('Could not load local stores.'), findsOneWidget);
      expect(find.text('Sri Lakshmi General Store'), findsNothing);
      await tester.tap(find.text('Retry stores'));
      await _pumpFor(tester);
      expect(find.text('Recovered Grocery'), findsOneWidget);
      expect(attempts, 2);
    },
  );

  testWidgets(
    'retries failed live local-store catalogs without showing demo products',
    (tester) async {
      var categoryRequests = 0;
      CustomerApi.instance = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/shops') {
            return _jsonResponse({
              'data': [
                {
                  'id': shopId,
                  'name': 'Backend Grocery',
                  'partner_type': 'grocery',
                  'address': 'Market Road',
                },
              ],
            });
          }
          if (request.url.path == '/api/v1/shops/$shopId/categories') {
            categoryRequests++;
            if (categoryRequests == 1) {
              return _jsonResponse({
                'error': {'code': 'DATABASE_UNAVAILABLE'},
              }, statusCode: 503);
            }
            return _jsonResponse({'data': <Object>[]});
          }
          return _jsonResponse({'data': <Object>[]});
        }),
      );

      await tester.pumpWidget(const MaterialApp(home: LocalStoresPage()));
      await _pumpFor(tester);
      await tester.tap(find.text('Backend Grocery'));
      await _pumpFor(tester);

      expect(find.text('Could not load this store catalog.'), findsOneWidget);
      expect(find.text('Marie Gold'), findsNothing);
      await tester.tap(find.text('Retry catalog'));
      await _pumpFor(tester);
      expect(find.text('Backend catalog'), findsOneWidget);
      expect(categoryRequests, 2);
    },
  );

  testWidgets('searches backend restaurant shops through the catalog API', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        return _jsonResponse({
          'data': [
            {
              'id': shopId,
              'name': request.url.queryParameters['q'] == 'Tiffin'
                  ? 'Tiffin House'
                  : 'All-day Kitchen',
              'partner_type': 'restaurant',
              'address': 'Market Road',
            },
          ],
        });
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: RestaurantsPage()));
    await _pumpFor(tester);
    expect(find.text('All-day Kitchen'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('restaurant-search')),
      'Tiffin',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpFor(tester);

    expect(find.text('Tiffin House'), findsOneWidget);
    expect(find.text('All-day Kitchen'), findsNothing);
    expect(requests.last.url.queryParameters['partnerType'], 'restaurant');
    expect(requests.last.url.queryParameters['q'], 'Tiffin');
  });

  testWidgets('shows a clear empty state for an empty backend shop result', (
    tester,
  ) async {
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient(
        (request) async => _jsonResponse({'data': <Object>[]}),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: RestaurantsPage()));
    await _pumpFor(tester);

    expect(find.text('Backend catalog'), findsOneWidget);
    expect(find.text('No restaurants available.'), findsOneWidget);
    expect(find.text('Spice Route Kitchen'), findsNothing);
  });

  testWidgets('searches backend restaurant products within the selected shop', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/categories')) {
          return _jsonResponse({
            'data': [
              {
                'id': categoryId,
                'shop_id': shopId,
                'name': 'Meals',
                'parent_category_id': null,
              },
            ],
          });
        }
        return _jsonResponse({
          'data': [
            {
              'id': productId,
              'shop_id': shopId,
              'category_id': categoryId,
              'name': request.url.queryParameters['q'] == 'Biryani'
                  ? 'Chicken Biryani'
                  : 'Rice Meal',
              'description': 'Catalog item',
              'price_minor': '1250',
              'currency': 'INR',
              'is_available': true,
            },
          ],
        });
      }),
    );
    const restaurant = Restaurant(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'Backend Kitchen',
      rating: 0,
      deliveryTime: 'Not provided',
      cuisine: 'Details not provided',
      distance: '—',
      location: 'Market Road',
      status: RestaurantStatus.unknown,
      isBackendData: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: RestaurantMenuPage(restaurant: restaurant)),
    );
    await _pumpFor(tester);
    expect(find.text('Rice Meal'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('restaurant-product-search')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('restaurant-product-search')),
      'Biryani',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpFor(tester);

    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Rice Meal'), findsNothing);
    expect(requests.last.url.queryParameters['shopId'], shopId);
    expect(requests.last.url.queryParameters['q'], 'Biryani');
    expect(
      requests.where((request) => request.url.path.endsWith('/categories')),
      hasLength(1),
    );
  });

  testWidgets(
    'retries a failed live restaurant menu without replacing it with demo items',
    (tester) async {
      var categoryRequests = 0;
      var productRequests = 0;
      CustomerApi.instance = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/categories')) {
            categoryRequests++;
            return _jsonResponse({'data': <Object>[]});
          }
          if (request.url.path == '/api/v1/products') {
            productRequests++;
            if (productRequests == 1) {
              return _jsonResponse({
                'error': {'code': 'DATABASE_UNAVAILABLE'},
              }, statusCode: 503);
            }
            return _jsonResponse({'data': <Object>[]});
          }
          return _jsonResponse({
            'error': {'code': 'NOT_FOUND'},
          }, statusCode: 404);
        }),
      );
      const restaurant = Restaurant(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Backend Kitchen',
        rating: 0,
        deliveryTime: 'Not provided',
        cuisine: 'Details not provided',
        distance: '—',
        location: 'Market Road',
        status: RestaurantStatus.unknown,
        isBackendData: true,
      );

      await tester.pumpWidget(
        const MaterialApp(home: RestaurantMenuPage(restaurant: restaurant)),
      );
      await _pumpFor(tester);

      expect(find.text('Could not load the backend menu.'), findsOneWidget);
      expect(find.text('Chicken Dum Biryani'), findsNothing);
      await tester.tap(find.text('Retry menu'));
      await _pumpFor(tester);
      expect(find.text('Backend catalog'), findsOneWidget);
      expect(categoryRequests, 1);
      expect(productRequests, 2);
    },
  );
}

Future<void> _pumpFor(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
