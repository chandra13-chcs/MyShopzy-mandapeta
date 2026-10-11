import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/parcel/presentation/parcel_history_page.dart';
import 'package:myshopzy/features/parcel/presentation/parcel_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

const _bookingId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  setUp(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  test(
    'CustomerApi submits valid booking and reads history and details',
    () async {
      final requests = <http.Request>[];
      final api = _api((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return _jsonResponse({'data': _bookingJson()}, statusCode: 201);
        }
        if (request.url.path == '/api/v1/me/parcels') {
          return _jsonResponse({
            'data': [_bookingJson()],
            'pagination': {'limit': 20, 'offset': 0},
          });
        }
        return _jsonResponse({'data': _bookingJson(appendUpdatedAt: true)});
      });
      addTearDown(api.close);

      final created = await api.createParcelBooking(_validRequest);
      final history = await api.getParcelBookings();
      final details = await api.getParcelBookingDetails(_bookingId);

      expect(created.id, _bookingId);
      expect(created.weightKg, 1.25);
      expect(created.instructions, '');
      expect(history.single.status, 'requested');
      expect(details.updatedAt, '2026-10-11T06:00:00.000Z');
      expect(requests.map((request) => request.method), ['POST', 'GET', 'GET']);
      expect(requests[0].url.path, '/api/v1/me/parcels');
      expect(jsonDecode(requests[0].body), {
        'pickupLocation': 'Pickup Road',
        'dropLocation': 'Drop Street',
        'parcelType': 'Documents',
        'weightKg': 1.25,
        'instructions': '',
      });
      expect(requests[1].url.queryParameters, {'limit': '20', 'offset': '0'});
      expect(requests[2].url.path, '/api/v1/me/parcels/$_bookingId');
    },
  );

  test('CustomerApi rejects invalid booking before making a request', () async {
    var requestSent = false;
    final api = _api((request) async {
      requestSent = true;
      return _jsonResponse({'data': _bookingJson()}, statusCode: 201);
    });
    addTearDown(api.close);

    for (final invalidRequest in [
      const ApiParcelBookingRequest(
        pickupLocation: '',
        dropLocation: 'Drop',
        parcelType: 'Documents',
        weightKg: 1,
      ),
      const ApiParcelBookingRequest(
        pickupLocation: 'Pickup',
        dropLocation: 'Drop',
        parcelType: 'Documents',
        weightKg: 20.001,
      ),
      const ApiParcelBookingRequest(
        pickupLocation: 'Pickup',
        dropLocation: 'Drop',
        parcelType: 'Documents',
        weightKg: 1.0001,
      ),
    ]) {
      await expectLater(
        api.createParcelBooking(invalidRequest),
        throwsA(
          isA<CustomerApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_REQUEST',
          ),
        ),
      );
    }
    expect(requestSent, isFalse);
  });

  testWidgets('booking form validates locations and the 20 kg limit', (
    tester,
  ) async {
    var requestSent = false;
    CustomerApi.instance = _api((request) async {
      requestSent = true;
      return _jsonResponse({'data': _bookingJson()}, statusCode: 201);
    });

    await tester.pumpWidget(const MaterialApp(home: ParcelPage()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Pickup Road');
    await tester.enterText(find.byType(TextFormField).at(1), 'Drop Street');
    await tester.enterText(find.byType(TextFormField).at(2), '20.001');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Weight must be greater than 0 kg and no more than 20 kg.'),
      findsOneWidget,
    );
    expect(find.text('Parcel Summary'), findsNothing);
    expect(requestSent, isFalse);
  });

  testWidgets('booking submission shows loading and opens API details', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final postResponse = Completer<http.Response>();
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.method == 'POST') return postResponse.future;
      return _jsonResponse({'data': _bookingJson(appendUpdatedAt: true)});
    });

    await tester.pumpWidget(const MaterialApp(home: ParcelPage()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Pickup Road');
    await tester.enterText(find.byType(TextFormField).at(1), 'Drop Street');
    await tester.enterText(find.byType(TextFormField).at(2), '1.25');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Parcel Request'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    postResponse.complete(
      _jsonResponse({'data': _bookingJson()}, statusCode: 201),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parcel Request Details'), findsOneWidget);
    expect(find.text(_bookingId), findsOneWidget);
    expect(requests.map((request) => request.method), ['POST', 'GET']);
    expect(requests.last.url.path, '/api/v1/me/parcels/$_bookingId');
  });

  testWidgets('history shows loading then an honest empty state', (
    tester,
  ) async {
    final historyResponse = Completer<http.Response>();
    CustomerApi.instance = _api((request) => historyResponse.future);

    await tester.pumpWidget(const MaterialApp(home: ParcelHistoryPage()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    historyResponse.complete(
      _jsonResponse({
        'data': <Object>[],
        'pagination': {'limit': 20, 'offset': 0},
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('No parcel requests yet'), findsOneWidget);
  });

  testWidgets('history reports API errors, retries, and handles 401 honestly', (
    tester,
  ) async {
    var requestCount = 0;
    CustomerApi.instance = _api((request) async {
      requestCount++;
      if (requestCount == 1) {
        return _jsonResponse({
          'error': {
            'code': 'DATABASE_UNAVAILABLE',
            'message': 'Parcel history is temporarily unavailable.',
          },
        }, statusCode: 503);
      }
      return _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required for parcel history.',
        },
      }, statusCode: 401);
    });

    await tester.pumpWidget(const MaterialApp(home: ParcelHistoryPage()));
    await tester.pumpAndSettle();
    expect(
      find.text('Parcel history is temporarily unavailable.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry parcel history'));
    await tester.pumpAndSettle();

    expect(
      find.text('Customer authentication is required for parcel history.'),
      findsOneWidget,
    );
    expect(find.text('Retry parcel history'), findsOneWidget);
    expect(requestCount, 2);
  });

  testWidgets('submission shows 401 and never reports a submitted request', (
    tester,
  ) async {
    CustomerApi.instance = _api(
      (request) async => _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required to submit a parcel.',
        },
      }, statusCode: 401),
    );

    await tester.pumpWidget(const MaterialApp(home: ParcelPage()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Pickup Road');
    await tester.enterText(find.byType(TextFormField).at(1), 'Drop Street');
    await tester.enterText(find.byType(TextFormField).at(2), '1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Parcel Request'));
    await tester.pumpAndSettle();

    expect(
      find.text('Customer authentication is required to submit a parcel.'),
      findsOneWidget,
    );
    expect(find.text('Parcel Request Details'), findsNothing);
  });

  testWidgets('unconfigured parcel mode is labeled and does not fake success', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ParcelPage()));
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Pickup Road');
    await tester.enterText(find.byType(TextFormField).at(1), 'Drop Street');
    await tester.enterText(find.byType(TextFormField).at(2), '1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Parcel Request'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('parcel request was not submitted'),
      findsOneWidget,
    );
    expect(find.text('Parcel Request Details'), findsNothing);
  });
}

const _validRequest = ApiParcelBookingRequest(
  pickupLocation: 'Pickup Road',
  dropLocation: 'Drop Street',
  parcelType: 'Documents',
  weightKg: 1.25,
);

CustomerApi _api(Future<http.Response> Function(http.Request) handler) {
  return CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient(handler),
  );
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode);
}

Map<String, Object?> _bookingJson({bool appendUpdatedAt = false}) => {
  'id': _bookingId,
  'pickup_location': 'Pickup Road',
  'drop_location': 'Drop Street',
  'parcel_type': 'Documents',
  'weight_grams': 1250,
  'instructions': '',
  'status': 'requested',
  'created_at': '2026-10-11T06:00:00.000Z',
  if (appendUpdatedAt) 'updated_at': '2026-10-11T06:00:00.000Z',
};
