import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/product_details/presentation/product_details_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  late CustomerApi api;

  tearDown(() {
    api.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('a backend 404 disables add using stale available list data', (
    tester,
  ) async {
    final requests = <http.Request>[];
    api = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'error': {'code': 'NOT_FOUND', 'message': 'Product not found.'},
          }),
          404,
        );
      }),
    );
    CustomerApi.instance = api;

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsPage(
          product: const ProductDetailsProduct(
            id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            serviceType: 'local_store',
            merchantId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            name: 'Previously Available Apples',
            description: 'Stale list response',
            icon: Icons.shopping_basket_outlined,
            available: true,
            priceInPaise: 12500,
            isBackendProduct: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests.single.url.path,
      '/api/v1/products/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    expect(
      find.text('This product is no longer available in the backend catalog.'),
      findsOneWidget,
    );
    expect(find.text('OUT OF STOCK'), findsOneWidget);
    expect(find.text('ADD'), findsNothing);
  });
}
