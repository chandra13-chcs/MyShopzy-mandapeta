import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
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
              },
            ],
          });
        }
        if (request.url.path == '/api/v1/carts') {
          return _jsonResponse({
            'data': {'cartToken': 'c' * 43},
          }, statusCode: 201);
        }
        if (request.url.path == '/api/v1/cart/items') {
          return _jsonResponse({
            'data': {'productId': productId, 'quantity': 1},
          });
        }
        if (request.url.path == '/api/v1/checkout/quote') {
          return _jsonResponse({
            'data': {
              'items': [
                {
                  'productId': productId,
                  'name': 'Backend Rice Meal',
                  'quantity': 1,
                  'priceMinor': '1300',
                  'lineTotalMinor': '1300',
                },
              ],
              'currency': 'INR',
              'itemSubtotalMinor': '1300',
              'deliveryFeeMinor': '0',
              'platformFeeMinor': '1000',
              'discountMinor': '0',
              'totalMinor': '2300',
              'isDeliverable': true,
              'message': 'Delivery is available at this location.',
              'distanceMeters': 2000,
              'storeOpen': true,
              'opensAt': '07:00',
              'closesAt': '22:00',
            },
          });
        }
        if (request.url.path == '/api/v1/me/addresses') {
          return _jsonResponse({
            'error': {
              'code': 'AUTHENTICATION_REQUIRED',
              'message': 'Customer authentication is required.',
            },
          }, statusCode: 401);
        }
        if (request.url.path == '/api/v1/orders') {
          return _jsonResponse({
            'error': {
              'code': 'AUTHENTICATION_REQUIRED',
              'message':
                  'Customer authentication is required to place an order.',
            },
          }, statusCode: 401);
        }
        return _jsonResponse({
          'error': {'code': 'NOT_FOUND'},
        }, statusCode: 404);
      }),
    );
    CartStore.instance.clear();

    await tester.pumpWidget(const MaterialApp(home: RestaurantsPage()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

    expect(CartStore.instance.hasBackendCart, isTrue);
    expect(CartStore.instance.items.single.productId, productId);
    expect(CartStore.instance.items.single.priceInPaise, 1250);
    expect(CartStore.instance.items.single.merchantId, shopId);
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
    expect(requests.last.headers['X-Cart-Token'], 'c' * 43);

    await tester.tap(find.text('Backend Rice Meal'));
    await _pumpFor(tester);
    expect(find.text('Fresh Backend Rice Meal'), findsOneWidget);
    expect(find.text('Backend catalog product'), findsOneWidget);
    expect(
      requests.map((request) => request.url.path),
      contains('/api/v1/products/$productId'),
    );

    Navigator.of(tester.element(find.text('Fresh Backend Rice Meal')))
        .push(MaterialPageRoute<void>(builder: (_) => const CheckoutPage()));
    await _pumpFor(tester);
    expect(
      find.text(
        'Backend quote · coupons and delivery fees are not configured.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('checkout-total-value')))
          .data,
      '₹13',
    );
    expect(find.text('Qty 1 · ₹13 each'), findsOneWidget);
    await tester.tap(find.text('Change').first);
    await _pumpFor(tester);
    expect(find.text('Saved Addresses · backend'), findsOneWidget);
    expect(find.text('Customer authentication is required.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    await tester.tap(find.text('Use Current Location'));
    await _pumpFor(tester);
    await tester.tap(find.text('Confirm this location'));
    await _pumpFor(tester);
    await tester.ensureVisible(find.text('Place Order'));
    await tester.tap(find.text('Place Order'));
    await _pumpFor(tester);

    expect(
      find.text('Customer authentication is required to place an order.'),
      findsOneWidget,
    );
    expect(find.textContaining('Order placed'), findsNothing);
    expect(CartStore.instance.items, hasLength(1));
    expect(requests.last.url.path, '/api/v1/orders');
    expect(requests.last.headers['X-Cart-Token'], 'c' * 43);
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

  testWidgets('loads grocery shops and products into the backend cart', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/shops') {
          expect(request.url.queryParameters['partnerType'], 'grocery');
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
          return _jsonResponse({
            'data': [
              {
                'id': categoryId,
                'shop_id': shopId,
                'name': 'Fresh Food',
                'parent_category_id': null,
              },
            ],
          });
        }
        if (request.url.path == '/api/v1/products') {
          expect(request.url.queryParameters['shopId'], shopId);
          return _jsonResponse({
            'data': [
              {
                'id': productId,
                'shop_id': shopId,
                'category_id': categoryId,
                'name': 'Backend Grocery Apples',
                'description': 'Price from the backend catalog',
                'price_minor': '1234',
                'currency': 'INR',
                'is_available': true,
              },
            ],
          });
        }
        if (request.url.path == '/api/v1/carts') {
          return _jsonResponse({
            'data': {'cartToken': 'g' * 43},
          }, statusCode: 201);
        }
        if (request.url.path == '/api/v1/cart/items') {
          return _jsonResponse({
            'data': {'productId': productId, 'quantity': 1},
          });
        }
        return _jsonResponse({
          'error': {'code': 'NOT_FOUND'},
        }, statusCode: 404);
      }),
    );
    CartStore.instance.clear();

    await tester.pumpWidget(const MaterialApp(home: LocalStoresPage()));
    await _pumpFor(tester);
    expect(find.text('Backend catalog'), findsOneWidget);
    expect(find.text('Backend Grocery'), findsOneWidget);
    expect(find.text('Hours not provided'), findsOneWidget);
    expect(find.text('4.5'), findsNothing);

    await tester.tap(find.text('Backend Grocery'));
    await _pumpFor(tester);
    expect(find.text('Backend Grocery Apples'), findsOneWidget);
    expect(find.text('₹12.34'), findsOneWidget);
    expect(find.text('Backend catalog'), findsOneWidget);

    await tester.tap(find.text('ADD'));
    await _pumpFor(tester);
    expect(CartStore.instance.hasBackendCart, isTrue);
    expect(CartStore.instance.items.single.productId, productId);
    expect(CartStore.instance.items.single.priceInPaise, 1234);
    expect(CartStore.instance.items.single.merchantId, shopId);
    expect(
      requests.map((request) => request.url.path),
      contains('/api/v1/shops/$shopId/categories'),
    );
    expect(requests.last.headers['X-Cart-Token'], 'g' * 43);
  });

  testWidgets('loads, updates, and removes backend cart items', (tester) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/carts') {
          return _jsonResponse({
            'data': {'cartToken': 'k' * 43},
          }, statusCode: 201);
        }
        if (request.url.path == '/api/v1/cart' && request.method == 'GET') {
          return _jsonResponse({
            'data': {
              'shopId': shopId,
              'items': [
                {
                  'productId': productId,
                  'shopId': shopId,
                  'name': 'Server cart item',
                  'sku': 'SKU-1',
                  'quantity': 2,
                  'priceMinor': '1250',
                  'lineTotalMinor': '2500',
                  'currency': 'INR',
                  'available': true,
                },
              ],
              'itemCount': 2,
              'itemSubtotalMinor': '2500',
            },
          });
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/v1/cart/items') {
          return _jsonResponse({
            'data': {
              'shopId': null,
              'items': <Object>[],
              'itemCount': 0,
              'itemSubtotalMinor': '0',
            },
          });
        }
        return http.Response('', 204);
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await _pumpFor(tester);

    expect(find.text('Server cart item'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease quantity'));
    await _pumpFor(tester);
    expect(
      requests.any(
        (request) =>
            request.method == 'PATCH' &&
            request.url.path.endsWith('/$productId') &&
            jsonDecode(request.body)['quantity'] == 1,
      ),
      isTrue,
    );

    await tester.tap(find.byTooltip('Remove item'));
    await _pumpFor(tester);
    expect(
      requests.any(
        (request) =>
            request.method == 'DELETE' &&
            request.url.path == '/api/v1/cart/items/$productId',
      ),
      isTrue,
    );
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('clears all backend cart items through the API', (tester) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/carts') {
          return _jsonResponse({
            'data': {'cartToken': 's' * 43},
          }, statusCode: 201);
        }
        if (request.url.path == '/api/v1/cart') {
          return _jsonResponse({
            'data': {
              'shopId': shopId,
              'items': [
                {
                  'productId': productId,
                  'shopId': shopId,
                  'name': 'Item to clear',
                  'sku': null,
                  'quantity': 1,
                  'priceMinor': '500',
                  'lineTotalMinor': '500',
                  'currency': 'INR',
                  'available': true,
                },
              ],
              'itemCount': 1,
              'itemSubtotalMinor': '500',
            },
          });
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/v1/cart/items') {
          return _jsonResponse({
            'data': {
              'shopId': null,
              'items': <Object>[],
              'itemCount': 0,
              'itemSubtotalMinor': '0',
            },
          });
        }
        return _jsonResponse({'data': {}});
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await _pumpFor(tester);
    expect(find.text('Item to clear'), findsOneWidget);

    await tester.tap(find.text('Clear cart'));
    await _pumpFor(tester);

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(
      requests.any(
        (request) =>
            request.method == 'DELETE' &&
            request.url.path == '/api/v1/cart/items' &&
            request.headers['X-Cart-Token'] == 's' * 43,
      ),
      isTrue,
    );
  });

  testWidgets(
    'marks unavailable backend cart products and prevents increases',
    (tester) async {
      CustomerApi.instance = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/carts') {
            return _jsonResponse({
              'data': {'cartToken': 'u' * 43},
            }, statusCode: 201);
          }
          return _jsonResponse({
            'data': {
              'shopId': shopId,
              'items': [
                {
                  'productId': productId,
                  'shopId': shopId,
                  'name': 'Unavailable product',
                  'quantity': 1,
                  'priceMinor': '900',
                  'lineTotalMinor': '900',
                  'currency': 'INR',
                  'available': false,
                },
              ],
              'itemCount': 1,
              'itemSubtotalMinor': '900',
            },
          });
        }),
      );

      await tester.pumpWidget(const MaterialApp(home: CartPage()));
      await _pumpFor(tester);

      expect(find.text('Out of Stock'), findsOneWidget);
      await tester.tap(find.byTooltip('Increase quantity'));
      await _pumpFor(tester);
      expect(
        find.text('This product is currently out of stock.'),
        findsOneWidget,
      );
      expect(CartStore.instance.items.single.quantity, 1);
    },
  );

  testWidgets('shows a retryable state when the backend cart cannot load', (
    tester,
  ) async {
    var cartReads = 0;
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/carts') {
          return _jsonResponse({
            'data': {'cartToken': 'r' * 43},
          }, statusCode: 201);
        }
        if (request.url.path == '/api/v1/cart') {
          cartReads++;
          if (cartReads == 1) {
            return _jsonResponse({
              'error': {'code': 'DATABASE_UNAVAILABLE'},
            }, statusCode: 503);
          }
          return _jsonResponse({
            'data': {
              'shopId': null,
              'items': <Object>[],
              'itemCount': 0,
              'itemSubtotalMinor': '0',
            },
          });
        }
        return _jsonResponse({'data': {}});
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await _pumpFor(tester);
    expect(find.text('Could not load your cart.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await _pumpFor(tester);
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(cartReads, 2);
  });
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
