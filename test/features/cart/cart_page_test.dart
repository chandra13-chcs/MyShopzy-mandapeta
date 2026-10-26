import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  tearDown(() {
    CartStore.instance.clear();
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('cart access is blocked without a customer session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CartPage()));

    expect(find.text('Sign in to access your cart.'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
    expect(CartStore.instance.items, isEmpty);
  });

  testWidgets('authenticated cart remains unavailable without owner storage', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/auth/otp/verify') {
          return _jsonResponse({
            'data': {
              'accessToken': 'test-session',
              'tokenType': 'Bearer',
              'expiresIn': 300,
            },
          });
        }
        expect(request.headers['authorization'], 'Bearer test-session');
        return _jsonResponse({
          'error': {
            'code': 'CART_OWNERSHIP_UNAVAILABLE',
            'message': 'Customer cart ownership is unavailable until the database supports customer-owned carts.',
          },
        }, statusCode: 503);
      }),
    );
    await CustomerApi.instance.verifyOtp(
      phoneNumber: '9876543210',
      otp: '123456',
    );

    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Customer cart ownership is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Checkout'), findsNothing);
    expect(CartStore.instance.items, isEmpty);
    expect(
      requests.where((request) => request.url.path == '/api/v1/carts'),
      hasLength(1),
    );
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
