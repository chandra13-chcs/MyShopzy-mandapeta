import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  group('CustomerApi', () {
    test(
      'requests and verifies OTP through the production API contract',
      () async {
        final requests = <http.Request>[];
        final api = CustomerApi(
          baseUrl: 'https://shop.example',
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/auth/otp/request')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'message': 'If this number can receive verification messages, a code may be sent.',
                    'expiresIn': 300,
                    'resendAfter': 30,
                  },
                }),
                202,
              );
            }
            if (request.url.path.endsWith('/auth/otp/verify')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'accessToken': 'header.payload.signature',
                    'tokenType': 'Bearer',
                    'expiresIn': 900,
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'data': [],
                'pagination': {'limit': 20, 'offset': 0},
              }),
              200,
            );
          }),
        );
        addTearDown(api.close);

        await api.requestOtp(phoneNumber: '+919876543210');
        expect(api.hasCustomerSession, isFalse);
        await api.verifyOtp(phoneNumber: '+919876543210', otp: '123456');
        expect(api.hasCustomerSession, isTrue);
        await api.getShops();

        expect(requests.map((request) => request.url.path), [
          '/api/v1/auth/otp/request',
          '/api/v1/auth/otp/verify',
          '/api/v1/shops',
        ]);
        expect(jsonDecode(requests[0].body), {'phoneNumber': '+919876543210'});
        expect(jsonDecode(requests[1].body), {
          'phoneNumber': '+919876543210',
          'otp': '123456',
        });
        expect(
          requests[2].headers['Authorization'],
          'Bearer header.payload.signature',
        );
      },
    );

    test(
      'does not create a customer session when OTP verification fails',
      () async {
        final api = CustomerApi(
          baseUrl: 'https://shop.example',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'INVALID_OTP',
                  'message': 'The verification code is invalid or expired.',
                },
              }),
              401,
            ),
          ),
        );
        addTearDown(api.close);

        await expectLater(
          api.verifyOtp(phoneNumber: '+919876543210', otp: '123456'),
          throwsA(
            isA<CustomerApiException>()
                .having((error) => error.statusCode, 'statusCode', 401)
                .having((error) => error.code, 'code', 'INVALID_OTP'),
          ),
        );
        expect(api.hasCustomerSession, isFalse);
      },
    );

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
                    'partner_id': 'partner-id',
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
                  'image_url': 'https://shop.example/rice.jpg',
                  'thumb_url': 'https://shop.example/rice-thumb.jpg',
                  'variants': [
                    {
                      'id': 'variant-id',
                      'label': '500 g',
                      'unit': 'g',
                      'quantity': 500,
                      'price_minor': '7650',
                      'stock': 12,
                      'is_available': true,
                      'sort_order': 0,
                    },
                  ],
                  'attributes': {
                    'rating': 4.6,
                    'mrp_minor': 15000,
                    'discount_percent': 18,
                    'badge': 'Popular',
                    'brand': 'Farmhouse',
                    'pack_size': '1 kg',
                  },
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
      expect(shops.single.partnerId, 'partner-id');
      expect(shops.single.address, 'Main Road');
      expect(shops.single.storeOpen, isTrue);
      expect(categories.single.name, 'Meals');
      expect(products.single.priceMinor, 12345);
      expect(products.single.storeOpen, isTrue);
      expect(products.single.priceMinor ~/ 100, 123);
      expect(products.single.imageUrl, 'https://shop.example/rice.jpg');
      expect(products.single.thumbUrl, 'https://shop.example/rice-thumb.jpg');
      expect(products.single.variants.single.id, 'variant-id');
      expect(products.single.variants.single.label, '500 g');
      expect(products.single.variants.single.unit, 'g');
      expect(products.single.variants.single.quantity, 500);
      expect(products.single.variants.single.priceInPaise, 7650);
      expect(products.single.variants.single.stock, 12);
      expect(products.single.rating, 4.6);
      expect(products.single.mrpMinor, 15000);
      expect(products.single.discountPercent, 18);
      expect(products.single.badge, 'Popular');
      expect(products.single.brand, 'Farmhouse');
      expect(products.single.packSize, '1 kg');
      expect(requests.first.url.toString(), contains('partnerType=restaurant'));
      expect(requests.last.url.queryParameters['shopId'], 'shop-id');
      expect(requests.last.url.queryParameters['limit'], '100');
      expect(requests.last.url.queryParameters['offset'], '0');
    });

    test('parses optional store hours and defaults storeOpen to true', () {
      final shop = ApiShop.fromJson({
        'id': 'shop-id',
        'name': 'Kitchen',
        'partner_type': 'restaurant',
        'storeOpen': false,
        'opensAt': '07:00',
        'closesAt': '23:00',
      });
      final product = ApiProduct.fromJson({
        'id': 'product-id',
        'shop_id': 'shop-id',
        'name': 'Rice meal',
        'price_minor': '12345',
        'currency': 'INR',
        'is_available': true,
        'storeOpen': false,
        'opensAt': '07:00',
        'closesAt': '23:00',
      });
      final quote = ApiCartQuote.fromJson({
        'currency': 'INR',
        'itemSubtotalMinor': '100',
        'deliveryFeeMinor': '0',
        'platformFeeMinor': '1000',
        'discountMinor': '0',
        'totalMinor': '1100',
        'isDeliverable': true,
        'message': 'Delivery is available at this location.',
        'distanceMeters': 4000,
        'items': const [],
        'storeOpen': false,
        'opensAt': '07:00',
        'closesAt': '23:00',
      });

      expect(shop.storeOpen, isFalse);
      expect(shop.opensAt, '07:00');
      expect(shop.closesAt, '23:00');
      expect(product.storeOpen, isFalse);
      expect(product.opensAt, '07:00');
      expect(product.closesAt, '23:00');
      expect(quote.storeOpen, isFalse);
      expect(quote.opensAt, '07:00');
      expect(quote.closesAt, '23:00');
      expect(
        ApiCartQuote.fromJson({
          'currency': 'INR',
          'itemSubtotalMinor': '0',
          'deliveryFeeMinor': null,
          'platformFeeMinor': null,
          'discountMinor': '0',
          'totalMinor': null,
          'isDeliverable': false,
          'message': "Sorry! We don't deliver here yet",
          'distanceMeters': 18001,
          'items': const [],
        }).storeOpen,
        isTrue,
      );
    });

    test('loads every product page within the API page-size limit', () async {
      final offsets = <String?>[];
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          final offset = request.url.queryParameters['offset'];
          offsets.add(offset);
          final start = int.parse(offset!);
          final count = start == 0 ? 100 : 1;
          return http.Response(
            jsonEncode({
              'data': List.generate(
                count,
                (index) => {
                  'id': 'product-${start + index}',
                  'shop_id': 'shop-id',
                  'name': 'Product ${start + index}',
                  'price_minor': 100,
                  'currency': 'INR',
                  'is_available': true,
                },
              ),
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final products = await api.getAllProducts();

      expect(products, hasLength(101));
      expect(offsets, ['0', '100']);
    });

    test('loads every shop page within the API page-size limit', () async {
      final offsets = <String?>[];
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          final offset = request.url.queryParameters['offset'];
          offsets.add(offset);
          final start = int.parse(offset!);
          final count = start == 0 ? 100 : 1;
          return http.Response(
            jsonEncode({
              'data': List.generate(
                count,
                (index) => {
                  'id': 'shop-${start + index}',
                  'name': 'Shop ${start + index}',
                  'partner_type': 'grocery',
                },
              ),
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final shops = await api.getAllShops();

      expect(shops, hasLength(101));
      expect(offsets, ['0', '100']);
    });

    test('loads dynamic partner categories and their metadata', () async {
      late http.Request request;
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'partner_type': 'sweet_shop',
                  'display_name': 'Sweet Shop',
                  'partner_count': 2,
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final categories = await api.getPartnerCategories();

      expect(categories.single.partnerType, 'sweet_shop');
      expect(categories.single.displayName, 'Sweet Shop');
      expect(categories.single.partnerCount, 2);
      expect(request.url.path, '/api/v1/partner-categories');
    });

    test('checks delivery serviceability with location and pincode', () async {
      late http.Request request;
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'data': {
                'isDeliverable': true,
                'message': 'Delivery is available.',
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final result = await api.checkLocationServiceability(
        16.87,
        81.93,
        '533308',
      );

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/delivery/serviceability');
      expect(jsonDecode(request.body), {
        'latitude': 16.87,
        'longitude': 81.93,
        'pincode': '533308',
      });
      expect(result.isDeliverable, isTrue);
      expect(result.message, 'Delivery is available.');
    });

    test('rejects invalid serviceability coordinates and pincodes', () async {
      var requestSent = false;
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          requestSent = true;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.checkLocationServiceability(91, 81.93, '533308'),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_REQUEST',
          ),
        ),
      );
      await expectLater(
        api.checkLocationServiceability(16.87, 81.93, '53330'),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_REQUEST',
          ),
        ),
      );
      expect(requestSent, isFalse);
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

    test(
      'rejects checkout quote addresses without valid coordinates',
      () async {
        var requestSent = false;
        final api = CustomerApi(
          baseUrl: 'https://shop.example',
          httpClient: MockClient((request) async {
            requestSent = true;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(api.close);

        for (final coordinates in [
          (latitude: 91.0, longitude: 81.93),
          (latitude: 16.87, longitude: -181.0),
        ]) {
          await expectLater(
            api.getCheckoutQuote(
              formattedAddress: '12 Green Park Road',
              pincode: '533308',
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
            ),
            throwsA(
              isA<CustomerApiException>().having(
                (error) => error.code,
                'code',
                'INVALID_REQUEST',
              ),
            ),
          );
        }
        await expectLater(
          api.getCheckoutQuote(
            formattedAddress: '12 Green Park Road',
            pincode: '5333',
            latitude: 16.87,
            longitude: 81.93,
          ),
          throwsA(isA<CustomerApiException>()),
        );
        expect(requestSent, isFalse);
      },
    );

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
                      'variantId': 'variant-id',
                      'variantLabel': '500 g',
                      'name': 'Server-priced item',
                      'quantity': 2,
                      'priceMinor': '12345',
                      'lineTotalMinor': '24690',
                    },
                  ],
                  'currency': 'INR',
                  'itemSubtotalMinor': '24690',
                  'deliveryFeeMinor': '0',
                  'platformFeeMinor': '1000',
                  'discountMinor': '0',
                  'totalMinor': '25690',
                  'isDeliverable': true,
                  'message': 'Delivery is available at this location.',
                  'distanceMeters': 2000,
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'productId': 'product-id',
                'variantId': 'variant-id',
                'quantity': 2,
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      expect(
        await api.addCartItem(
          'product-id',
          variantId: 'variant-id',
          quantity: 2,
        ),
        2,
      );
      final quote = await api.getCheckoutQuote(
        formattedAddress: '  12 Green Park Road  ',
        pincode: '533308',
        latitude: 16.87,
        longitude: 81.93,
      );

      expect(api.hasCartToken, isTrue);
      expect(requests[1].headers['X-Cart-Token'], 'a' * 43);
      expect(jsonDecode(requests[1].body), {
        'productId': 'product-id',
        'variantId': 'variant-id',
        'quantity': 2,
      });
      expect(jsonDecode(requests[1].body), isNot(contains('price')));
      expect(requests[2].headers['X-Cart-Token'], 'a' * 43);
      expect(jsonDecode(requests[2].body), {
        'deliveryAddress': {
          'formattedAddress': '12 Green Park Road',
          'pincode': '533308',
          'latitude': 16.87,
          'longitude': 81.93,
        },
      });
      expect(quote.totalMinor, 25690);
      expect(quote.platformFeeMinor, 1000);
      expect(quote.items.single.priceMinor, 12345);
      expect(quote.items.single.lineTotalMinor, 24690);
      expect(quote.items.single.variantId, 'variant-id');
      expect(quote.items.single.variantLabel, '500 g');
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
          if (request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'data': {
                  'productId': 'product-id',
                  'variantId': 'variant-id',
                  'quantity': 3,
                },
              }),
              200,
            );
          }
          return http.Response('', 204);
        }),
      );
      addTearDown(api.close);
      await api.ensureCart();

      final quantity = await api.updateCartItem('product-id', 'variant-id', 3);
      await api.removeCartItem('product-id', 'variant-id');
      await api.clearCart();

      expect(quantity, 3);
      expect(requests.map((request) => request.method), [
        'POST',
        'PATCH',
        'DELETE',
        'DELETE',
      ]);
      expect(requests[1].headers['X-Cart-Token'], 'd' * 43);
      expect(jsonDecode(requests[1].body), {'quantity': 3});
      expect(requests[2].url.path, '/api/v1/cart/items/product-id/variant-id');
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
      expect(requests.map((request) => request.method), [
        'GET',
        'POST',
        'PATCH',
        'DELETE',
      ]);
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
              .having((error) => error.code, 'code', 'AUTHENTICATION_REQUIRED')
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
                    'variantId': 'variant-id',
                    'variantLabel': '500 g',
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
      expect(cart.items.single.variantId, 'variant-id');
      expect(cart.items.single.variantLabel, '500 g');
      expect(cart.items.single.quantity, 2);
      expect(cart.items.single.priceMinor, 12345);
      expect(cart.items.single.available, isFalse);
      expect(cart.itemSubtotalMinor, 24690);
      expect(requests.map((request) => request.method), ['POST', 'GET', 'GET']);
      expect(requests[1].url.path, '/api/v1/cart');
      expect(requests[1].headers['X-Cart-Token'], 'e' * 43);
      expect(requests[2].headers['X-Cart-Token'], 'e' * 43);
    });

    test('reads the product variant label from an order snapshot', () {
      final order = ApiCustomerOrderDetail.fromJson({
        'id': 'order-id',
        'shop_id': 'shop-id',
        'shop_name': 'Shop',
        'status': 'placed',
        'currency': 'INR',
        'items_subtotal_minor': '25000',
        'delivery_fee_minor': '0',
        'discount_minor': '0',
        'total_minor': '25000',
        'placed_at': '2026-10-11T06:00:00.000Z',
        'delivery_address_snapshot': {'formattedAddress': 'Home'},
        'items': [
          {
            'product_name_snapshot': 'Backend product',
            'sku_snapshot': 'SKU-500',
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
      });

      expect(order.items.single.variantLabel, '500 g');
      expect(order.items.single.variantSnapshot?['variantId'], 'variant-id');
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
