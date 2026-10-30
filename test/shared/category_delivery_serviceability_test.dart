import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/profile/data/selected_delivery_address_store.dart';
import 'package:myshopzy/features/profile/models/saved_address.dart';
import 'package:myshopzy/shared/data/customer_api.dart';
import 'package:myshopzy/shared/delivery/category_delivery_serviceability.dart';

void main() {
  final selectedAddress = SelectedDeliveryAddressStore.instance;

  setUp(() {
    CustomerApi.instance.close();
    selectedAddress.select(null);
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
    selectedAddress.select(null);
  });

  testWidgets('rechecks when the selected destination changes', (tester) async {
    final requests = <http.Request>[];
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final withinLimit = body['latitude'] == 16.91;
        return http.Response(
          jsonEncode({
            'data': {
              'category': 'grocery',
              'isDeliverable': withinLimit,
              'distanceMeters': withinLimit ? 10000 : 10001,
              'maximumDistanceMeters': 10000,
              'message': withinLimit
                  ? 'Delivery is available within 10 km.'
                  : 'Sorry, grocery delivery is available only within 10 km.',
            },
          }),
          200,
        );
      }),
    );
    selectedAddress.select(_address(latitude: 16.91, longitude: 81.91));

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryDeliveryGate(
          category: DeliveryCategory.grocery,
          child: Scaffold(body: Text('Grocery products')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Grocery products'), findsOneWidget);

    selectedAddress.select(_address(latitude: 16.92, longitude: 81.92));
    await tester.pumpAndSettle();

    expect(find.text('Groceries delivery is unavailable'), findsOneWidget);
    expect(find.textContaining('Limit: 10 km'), findsOneWidget);
    expect(requests, hasLength(2));
    expect(
      requests.map(
        (request) =>
            (jsonDecode(request.body) as Map<String, dynamic>)['latitude'],
      ),
      [16.91, 16.92],
    );
  });

  testWidgets('route failures fail closed with retry feedback', (tester) async {
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'ROUTING_UNAVAILABLE',
              'message':
                  'We could not verify the driving route. Please try again.',
            },
          }),
          503,
        ),
      ),
    );
    selectedAddress.select(_address(latitude: 17.01, longitude: 81.93));

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryDeliveryGate(
          category: DeliveryCategory.restaurant,
          child: Scaffold(body: Text('Restaurant catalogue')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restaurant catalogue'), findsNothing);
    expect(find.text('Could not check delivery availability'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('invalid or missing destination coordinates do not route', (
    tester,
  ) async {
    var requests = 0;
    CustomerApi.instance = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    selectedAddress.select(_address(latitude: null, longitude: null));

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryDeliveryGate(
          category: DeliveryCategory.bakery,
          child: Scaffold(body: Text('Bakery catalogue')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a valid delivery address'), findsOneWidget);
    expect(requests, 0);
  });
}

SavedAddress _address({required double? latitude, required double? longitude}) {
  return SavedAddress(
    id: 'test-address',
    label: 'Home',
    address: 'Mandapeta',
    icon: Icons.home_outlined,
    latitude: latitude,
    longitude: longitude,
    pincode: '533308',
  );
}
