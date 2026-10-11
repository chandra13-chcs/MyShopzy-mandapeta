import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  group('CustomerApi', () {
    test('uses configured base URL and parses catalog resources', () async {
      final requests = <http.Request>[];
      final api = CustomerApi(
        baseUrl: 'https://shop.example/',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/shops')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'shop-id',
                    'name': 'Kitchen',
                    'partner_type': 'restaurant',
                    'address': 'Main Road',
                    'partner_name': 'Kitchen Group',
                  },
                ],
                'pagination': {'limit': 20, 'offset': 0},
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/categories')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'category-id',
                    'shop_id': 'shop-id',
                    'name': 'Meals',
                    'parent_category_id': null,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'product-id',
                  'shop_id': 'shop-id',
                  'category_id': 'category-id',
                  'name': 'Rice meal',
                  'description': 'Daily meal',
                  'price_minor': '12345',
                  'currency': 'INR',
                  'is_available': true,
                },
              ],
              'pagination': {'limit': 20, 'offset': 0},
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final shops = await api.getShops(partnerType: 'restaurant');
      final categories = await api.getCategories('shop-id');
      final products = await api.getProducts(shopId: 'shop-id');

      expect(api.isConfigured, isTrue);
      expect(shops.single.name, 'Kitchen');
      expect(shops.single.address, 'Main Road');
      expect(categories.single.name, 'Meals');
      expect(products.single.priceMinor, 12345);
      expect(products.single.priceMinor ~/ 100, 123);
      expect(requests.first.url.toString(), contains('partnerType=restaurant'));
      expect(requests.last.url.queryParameters['shopId'], 'shop-id');
    });

    test(
      'rejects malformed catalog responses with a sanitized exception',
      () async {
        final api = CustomerApi(
          baseUrl: 'https://shop.example',
          httpClient: MockClient(
            (request) async => http.Response('{"data":[{"name":5}]}', 200),
          ),
        );
        addTearDown(api.close);

        await expectLater(
          api.getShops(),
          throwsA(
            isA<CustomerApiException>()
                .having((error) => error.code, 'code', 'INVALID_RESPONSE')
                .having(
                  (error) => error.message,
                  'message',
                  'The server returned an invalid response.',
                ),
          ),
        );
      },
    );

    test('rejects invalid backend URLs with a configuration error', () async {
      final api = CustomerApi(
        baseUrl: 'not a URL',
        httpClient: MockClient(
          (request) async => http.Response('{"data":[]}', 200),
        ),
      );
      addTearDown(api.close);

      await expectLater(
        api.getShops(),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_BASE_URL',
          ),
        ),
      );
    });

    test('requires HTTPS for non-local backend requests', () async {
      var requestSent = false;
      final api = CustomerApi(
        baseUrl: 'http://api.example',
        httpClient: MockClient((request) async {
          requestSent = true;
          return http.Response('{"data":[]}', 200);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.getCart(),
        throwsA(
          isA<CustomerApiException>()
              .having((error) => error.code, 'code', 'INSECURE_BASE_URL')
              .having(
                (error) => error.message,
                'message',
                'Use HTTPS for non-local backend connections.',
              ),
        ),
      );
      expect(requestSent, isFalse);
    });

    test('uses the capability token for cart operations and quotes', () async {
      final requests = <http.Request>[];
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/carts')) {
            return http.Response(
              jsonEncode({
                'data': {'cartToken': 'a' * 43},
              }),
              201,
            );
          }
          if (request.url.path.endsWith('/checkout/quote')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'items': [
                    {
                      'productId': 'product-id',
                      'name': 'Server-priced item',
                      'quantity': 2,
                      'priceMinor': '12345',
                      'lineTotalMinor': '24690',
                    },
                  ],
                  'currency': 'INR',
                  'itemSubtotalMinor': '12345',
                  'deliveryFeeMinor': '0',
                  'discountMinor': '0',
                  'totalMinor': '12345',
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {'productId': 'product-id', 'quantity': 2},
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      await api.addCartItem('product-id', quantity: 2);
      final quote = await api.getCheckoutQuote();

      expect(api.hasCartToken, isTrue);
      expect(requests[1].headers['X-Cart-Token'], 'a' * 43);
      expect(jsonDecode(requests[1].body), {
        'productId': 'product-id',
        'quantity': 2,
      });
      expect(jsonDecode(requests[1].body), isNot(contains('price')));
      expect(requests[2].headers['X-Cart-Token'], 'a' * 43);
      expect(quote.totalMinor, 12345);
      expect(quote.items.single.priceMinor, 12345);
      expect(quote.items.single.lineTotalMinor, 24690);
    });

    test('supports cart quantity updates, removals, and clearing', () async {
      final requests = <http.Request>[];
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/carts')) {
            return http.Response(
              jsonEncode({
                'data': {'cartToken': 'd' * 43},
              }),
              201,
            );
          }
          return http.Response('', 204);
        }),
      );
      addTearDown(api.close);
      await api.ensureCart();

      await api.updateCartItem('product-id', 3);
      await api.removeCartItem('product-id');
      await api.clearCart();

      expect(requests.map((request) => request.method), [
        'POST',
        'PATCH',
        'DELETE',
        'DELETE',
      ]);
      expect(requests[1].headers['X-Cart-Token'], 'd' * 43);
      expect(jsonDecode(requests[1].body), {'quantity': 3});
      expect(requests[2].url.path, '/api/v1/cart/items/product-id');
      expect(requests[3].url.path, '/api/v1/cart/items');
      expect(
        requests
            .skip(2)
            .every((request) => request.headers['X-Cart-Token'] == 'd' * 43),
        isTrue,
      );
    });

    test('lists, creates, updates, and deletes saved addresses', () async {
      final requests = <http.Request>[];
      var listCount = 0;
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            listCount++;
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'address-id',
                    'label': 'Home',
                    'address_snapshot': {
                      'formattedAddress': '12 Green Park Road',
                    },
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'created-address-id',
                  'label': 'Home',
                  'address_snapshot': jsonDecode(request.body)['address'],
                },
              }),
              201,
            );
          }
          if (request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'address-id',
                  'label': jsonDecode(request.body)['label'],
                  'address_snapshot': jsonDecode(request.body)['address'],
                },
              }),
              200,
            );
          }
          return http.Response('', 204);
        }),
      );
      addTearDown(api.close);

      final addresses = await api.getSavedAddresses();
      final created = await api.createSavedAddress(
        label: 'Home',
        address: const {'formattedAddress': '4 Lake Road'},
      );
      final updated = await api.updateSavedAddress(
        'address-id',
        label: 'Work',
        address: const {'formattedAddress': '24 Market Street'},
      );
      await api.deleteSavedAddress('address-id');

      expect(listCount, 1);
      expect(addresses.single.formattedAddress, '12 Green Park Road');
      expect(created.id, 'created-address-id');
      expect(updated.label, 'Work');
      expect(updated.formattedAddress, '24 Market Street');
      expect(
        requests.map((request) => request.method),
        ['GET', 'POST', 'PATCH', 'DELETE'],
      );
      expect(requests.map((request) => request.url.path), [
        '/api/v1/me/addresses',
        '/api/v1/me/addresses',
        '/api/v1/me/addresses/address-id',
        '/api/v1/me/addresses/address-id',
      ]);
      expect(jsonDecode(requests[1].body), {
        'label': 'Home',
        'address': {'formattedAddress': '4 Lake Road'},
      });
    });

    test('surfaces saved-address authentication and API errors', () async {
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'AUTHENTICATION_REQUIRED',
                'message': 'Customer authentication is required.',
              },
            }),
            401,
          );
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.getSavedAddresses(),
        throwsA(
          isA<CustomerApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.code,
                'code',
                'AUTHENTICATION_REQUIRED',
              )
              .having(
                (error) => error.message,
                'message',
                'Customer authentication is required.',
              ),
        ),
      );
    });

    test('creates a cart once and parses the server cart listing', () async {
      final requests = <http.Request>[];
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/carts')) {
            return http.Response(
              jsonEncode({
                'data': {'cartToken': 'e' * 43},
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'shopId': 'shop-id',
                'items': [
                  {
                    'productId': 'product-id',
                    'shopId': 'shop-id',
                    'name': 'Server cart item',
                    'sku': 'SKU-1',
                    'quantity': 2,
                    'priceMinor': '12345',
                    'lineTotalMinor': '24690',
                    'currency': 'INR',
                    'available': false,
                  },
                ],
                'itemCount': 2,
                'itemSubtotalMinor': '24690',
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final cart = await api.getCart();
      await api.getCart();

      expect(cart.items.single.name, 'Server cart item');
      expect(cart.items.single.quantity, 2);
      expect(cart.items.single.priceMinor, 12345);
      expect(cart.items.single.available, isFalse);
      expect(cart.itemSubtotalMinor, 24690);
      expect(requests.map((request) => request.method), ['POST', 'GET', 'GET']);
      expect(requests[1].url.path, '/api/v1/cart');
      expect(requests[1].headers['X-Cart-Token'], 'e' * 43);
      expect(requests[2].headers['X-Cart-Token'], 'e' * 43);
    });

    test(
      'keeps the authentication boundary explicit on order placement',
      () async {
        final requests = <http.Request>[];
        final api = CustomerApi(
          baseUrl: 'https://shop.example',
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/carts')) {
              return http.Response(
                jsonEncode({
                  'data': {'cartToken': 'b' * 43},
                }),
                201,
              );
            }
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'AUTHENTICATION_REQUIRED',
                  'message':
                      'Customer authentication is required to place an order.',
                },
              }),
              401,
            );
          }),
        );
        addTearDown(api.close);
        await api.ensureCart();

        await expectLater(
          api.placeOrder({'formattedAddress': 'Main Road'}),
          throwsA(
            isA<CustomerApiException>()
                .having((error) => error.statusCode, 'statusCode', 401)
                .having(
                  (error) => error.code,
                  'code',
                  'AUTHENTICATION_REQUIRED',
                ),
          ),
        );
        expect(requests.last.headers['X-Cart-Token'], 'b' * 43);
        expect(jsonDecode(requests.last.body), {
          'deliveryAddress': {'formattedAddress': 'Main Road'},
        });
      },
    );

    test('converts request timeouts into safe client errors', () async {
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        timeout: const Duration(milliseconds: 10),
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{"data":[]}', 200);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.getShops(),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'REQUEST_TIMEOUT',
          ),
        ),
      );
    });
  });
}
