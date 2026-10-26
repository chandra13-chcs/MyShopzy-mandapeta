import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/profile/presentation/saved_addresses_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('requires authentication before showing saved addresses', (
    tester,
  ) async {
    var requestCount = 0;
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requestCount++;
        return _jsonResponse({'data': <Object>[]});
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: SavedAddressesPage()));

    expect(find.text('Sign in to access saved addresses.'), findsOneWidget);
    expect(find.text('12 Green Park Road, Ravulapalem'), findsNothing);
    expect(requestCount, 0);
  });

  testWidgets(
    'loads backend addresses and shows an empty state when none exist',
    (tester) async {
      final response = Completer<http.Response>();
      CustomerApi.instance = _api((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/me/addresses');
        return response.future;
      });
      await _authenticate();

      await tester.pumpWidget(const MaterialApp(home: SavedAddressesPage()));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete(_jsonResponse({'data': <Object>[]}));
      await _pumpFor(tester);

      expect(find.text('Your saved addresses'), findsOneWidget);
      expect(find.text('No saved addresses yet.'), findsOneWidget);
      expect(find.textContaining('Ravulapalem'), findsNothing);
    },
  );

  testWidgets('creates, edits, and deletes an address after API success', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var currentLabel = 'Home';
    var currentAddress = '12 Green Park Road';
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return _jsonResponse({
          'data': [
            _address(
              id: 'address-id',
              label: currentLabel,
              formattedAddress: currentAddress,
            ),
          ],
        });
      }
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({
          'data': _address(
            id: 'new-address-id',
            label: body['label'] as String,
            formattedAddress:
                (body['address'] as Map<String, dynamic>)['formattedAddress']
                    as String,
          ),
        }, statusCode: 201);
      }
      if (request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        currentLabel = body['label'] as String;
        currentAddress =
            (body['address'] as Map<String, dynamic>)['formattedAddress']
                as String;
        return _jsonResponse({
          'data': _address(
            id: 'address-id',
            label: currentLabel,
            formattedAddress: currentAddress,
          ),
        });
      }
      return http.Response('', 204);
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: SavedAddressesPage()));
    await _pumpFor(tester);
    expect(find.text('12 Green Park Road'), findsOneWidget);

    await tester.tap(find.text('Add New Address'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('saved-address-label')),
      'Work',
    );
    await tester.enterText(
      find.byKey(const ValueKey('saved-address-formatted')),
      '24 Market Street',
    );
    await tester.tap(find.byKey(const ValueKey('saved-address-save')));
    await _pumpFor(tester);

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('24 Market Street'), findsOneWidget);
    expect(requests.any((request) => request.method == 'POST'), isTrue);

    await tester.tap(find.byTooltip('Edit address').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('saved-address-label')),
      'Office',
    );
    await tester.enterText(
      find.byKey(const ValueKey('saved-address-formatted')),
      '8 River View Lane',
    );
    await tester.tap(find.byKey(const ValueKey('saved-address-save')));
    await _pumpFor(tester);

    expect(find.text('Office'), findsOneWidget);
    expect(find.text('8 River View Lane'), findsOneWidget);
    expect(requests.any((request) => request.method == 'PATCH'), isTrue);

    await tester.tap(find.byTooltip('Delete address').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await _pumpFor(tester);

    expect(find.text('Office'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete address').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await _pumpFor(tester);
    expect(find.text('No saved addresses yet.'), findsOneWidget);
    expect(requests.any((request) => request.method == 'DELETE'), isTrue);
  });

  testWidgets(
    'validates required fields and preserves state after API failure',
    (tester) async {
      var createRequests = 0;
      CustomerApi.instance = _api((request) async {
        if (request.method == 'GET') {
          return _jsonResponse({
            'data': [
              _address(
                id: 'address-id',
                label: 'Home',
                formattedAddress: '12 Green Park Road',
              ),
            ],
          });
        }
        if (request.method == 'POST') {
          createRequests++;
          return _jsonResponse({
            'error': {
              'code': 'DATABASE_UNAVAILABLE',
              'message': 'The customer service is temporarily unavailable.',
            },
          }, statusCode: 503);
        }
        return http.Response('', 204);
      });
      await _authenticate();

      await tester.pumpWidget(const MaterialApp(home: SavedAddressesPage()));
      await _pumpFor(tester);

      await tester.tap(find.text('Add New Address'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saved-address-save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter an address label.'), findsOneWidget);
      expect(find.text('Enter the full address.'), findsOneWidget);
      expect(createRequests, 0);

      await tester.enterText(
        find.byKey(const ValueKey('saved-address-label')),
        'Work',
      );
      await tester.enterText(
        find.byKey(const ValueKey('saved-address-formatted')),
        '24 Market Street',
      );
      await tester.tap(find.byKey(const ValueKey('saved-address-save')));
      await _pumpFor(tester);

      expect(createRequests, 1);
      expect(find.text('12 Green Park Road'), findsOneWidget);
      expect(find.text('24 Market Street'), findsNothing);
      expect(
        find.text('The customer service is temporarily unavailable.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows honest unauthorized state and retry without demo data', (
    tester,
  ) async {
    var requests = 0;
    CustomerApi.instance = _api((request) async {
      requests++;
      return _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required.',
        },
      }, statusCode: 401);
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: SavedAddressesPage()));
    await _pumpFor(tester);

    expect(find.text('Customer authentication is required.'), findsOneWidget);
    expect(find.text('12 Green Park Road, Ravulapalem'), findsNothing);
    expect(find.text('Add New Address'), findsNothing);

    await tester.tap(find.text('Retry'));
    await _pumpFor(tester);
    expect(requests, 2);
    expect(find.text('Customer authentication is required.'), findsOneWidget);
  });

  testWidgets(
    'checkout stays unavailable without customer-owned cart support',
    (tester) async {
      CustomerApi.instance = _api((request) async {
        if (request.url.path == '/api/v1/me/addresses') {
          return _jsonResponse({
            'error': {
              'code': 'AUTHENTICATION_REQUIRED',
              'message': 'Customer authentication is required.',
            },
          }, statusCode: 401);
        }
        return _jsonResponse({
          'data': {
            'items': <Object>[],
            'currency': 'INR',
            'itemSubtotalMinor': '0',
            'deliveryFeeMinor': '0',
            'discountMinor': '0',
            'totalMinor': '0',
          },
        });
      });
      await _authenticate();

      await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
      await _pumpFor(tester);

      expect(
        find.text(
          'Checkout is unavailable until customer cart ownership is supported.',
        ),
        findsOneWidget,
      );
      expect(find.text('Saved Addresses'), findsNothing);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Customer authentication is required.'), findsNothing);
    },
  );
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

Map<String, Object?> _address({
  required String id,
  required String label,
  required String formattedAddress,
}) {
  return {
    'id': id,
    'label': label,
    'address_snapshot': {'formattedAddress': formattedAddress},
  };
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

Future<void> _pumpFor(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
