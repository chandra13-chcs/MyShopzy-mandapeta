import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/parcel/data/parcel_location_service.dart';
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
        'pickupLatitude': 16.87,
        'pickupLongitude': 81.93,
        'dropLatitude': 16.88,
        'dropLongitude': 81.94,
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
        pickupLatitude: 16.87,
        pickupLongitude: 81.93,
        dropLatitude: 16.88,
        dropLongitude: 81.94,
      ),
      const ApiParcelBookingRequest(
        pickupLocation: 'Pickup',
        dropLocation: 'Drop',
        parcelType: 'Documents',
        weightKg: 20.001,
        pickupLatitude: 16.87,
        pickupLongitude: 81.93,
        dropLatitude: 16.88,
        dropLongitude: 81.94,
      ),
      const ApiParcelBookingRequest(
        pickupLocation: 'Pickup',
        dropLocation: 'Drop',
        parcelType: 'Documents',
        weightKg: 1.0001,
        pickupLatitude: 16.87,
        pickupLongitude: 81.93,
        dropLatitude: 16.88,
        dropLongitude: 81.94,
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

    await expectLater(
      api.createParcelBooking(
        const ApiParcelBookingRequest(
          pickupLocation: 'Pickup',
          dropLocation: 'Drop',
          parcelType: 'Documents',
          weightKg: 1,
        ),
      ),
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

  test('unknown parcel submission outcome cannot be blindly retried', () async {
    var requestCount = 0;
    final api = CustomerApi(
      baseUrl: 'https://shop.example',
      timeout: const Duration(milliseconds: 1),
      httpClient: MockClient((request) async {
        requestCount++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _jsonResponse({'data': _bookingJson()}, statusCode: 201);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.createParcelBooking(_validRequest),
      throwsA(
        isA<CustomerApiException>().having(
          (error) => error.code,
          'code',
          'REQUEST_TIMEOUT',
        ),
      ),
    );
    expect(api.parcelOutcomeUnknown, isTrue);
    await expectLater(
      api.createParcelBooking(_validRequest),
      throwsA(
        isA<CustomerApiException>().having(
          (error) => error.code,
          'code',
          'PARCEL_OUTCOME_UNKNOWN',
        ),
      ),
    );
    expect(requestCount, 1);
  });

  testWidgets('booking form validates locations and the 20 kg limit', (
    tester,
  ) async {
    var requestSent = false;
    CustomerApi.instance = _api((request) async {
      requestSent = true;
      return _jsonResponse({'data': _bookingJson()}, statusCode: 201);
    });

    await _pumpParcelPage(tester);
    expect(
      find.byKey(const ValueKey('parcel-page-promotion-banner')),
      findsOneWidget,
    );
    final parcelBanner = tester.widget<Image>(
      find.byKey(const ValueKey('parcel-page-promotion-banner')),
    );
    expect(
      parcelBanner.image,
      isA<ResizeImage>().having(
        (image) => image.imageProvider,
        'imageProvider',
        isA<AssetImage>().having(
          (image) => image.assetName,
          'assetName',
          'assets/myshopzy_banners/parellu.jpeg',
        ),
      ),
    );
    await _enterParcelText(tester, 'Enter pickup location', 'Pickup Road');
    await _enterParcelText(tester, 'Enter drop location', 'Drop Street');
    await _enterParcelText(tester, 'Enter parcel weight', '20.001');
    await _tapContinue(tester);

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
      if (request.url.path == '/api/v1/me/addresses') {
        return _savedAddressResponse();
      }
      if (request.url.path == '/api/v1/delivery/serviceability') {
        return _jsonResponse({
          'data': {
            'isDeliverable': true,
            'message': 'Delivery is available at this location.',
          },
        });
      }
      if (request.method == 'POST') return postResponse.future;
      return _jsonResponse({'data': _bookingJson(appendUpdatedAt: true)});
    });

    await _pumpParcelPage(tester);
    await _chooseSavedAddress(tester, 'parcel-pickup-saved-address');
    await _chooseSavedAddress(tester, 'parcel-drop-saved-address');
    await _enterParcelText(tester, 'Enter parcel weight', '1.25');
    await _tapContinue(tester);

    expect(find.text('Enter a pickup location.'), findsNothing);
    expect(find.text('Enter a drop location.'), findsNothing);
    expect(
      find.text('Weight must be greater than 0 kg and no more than 20 kg.'),
      findsNothing,
    );
    expect(find.text('Parcel Summary'), findsOneWidget);
    await tester.tap(find.text('Submit Parcel Request'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    postResponse.complete(
      _jsonResponse({'data': _bookingJson()}, statusCode: 201),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Parcel Request Details'), findsOneWidget);
    expect(find.text(_bookingId), findsOneWidget);
    final parcelRequests = requests
        .where((request) => request.url.path.startsWith('/api/v1/me/parcels'))
        .toList();
    expect(parcelRequests.map((request) => request.method), ['POST', 'GET']);
    expect(parcelRequests.last.url.path, '/api/v1/me/parcels/$_bookingId');
    expect(
      jsonDecode(parcelRequests.first.body),
      containsPair('pickupLatitude', 16.87),
    );
    expect(
      jsonDecode(parcelRequests.first.body),
      containsPair('dropLongitude', 81.93),
    );
  });

  testWidgets('manual text without map locations cannot submit a parcel', (
    tester,
  ) async {
    var requestCount = 0;
    CustomerApi.instance = _api((request) async {
      requestCount++;
      return _jsonResponse({'data': _bookingJson()}, statusCode: 201);
    });

    await _pumpParcelPage(tester);
    await _enterParcelText(tester, 'Enter pickup location', 'Pickup Road');
    await _enterParcelText(tester, 'Enter drop location', 'Drop Street');
    await _enterParcelText(tester, 'Enter parcel weight', '1');
    await _tapContinue(tester);
    await tester.tap(find.text('Submit Parcel Request'));
    await tester.pump();

    expect(find.textContaining('verify the road route'), findsOneWidget);
    expect(requestCount, 0);
    expect(find.text('Parcel Request Details'), findsNothing);
  });

  testWidgets('saved pickup and drop addresses feed postal coverage checks', (
    tester,
  ) async {
    final requests = <http.Request>[];
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/me/addresses') {
        return _jsonResponse({
          'data': [
            {
              'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
              'label': 'Home',
              'address_snapshot': {
                'formattedAddress': '10 Main Road, Sample City',
                'latitude': 16.87,
                'longitude': 81.93,
                'pincode': '533308',
              },
            },
          ],
        });
      }
      if (request.url.path == '/api/v1/delivery/serviceability') {
        return _jsonResponse({
          'data': {
            'isDeliverable': true,
            'message': 'Delivery is available at this location.',
          },
        });
      }
      return _jsonResponse({'data': _bookingJson()});
    });

    await _pumpParcelPage(tester);
    await _chooseSavedAddress(tester, 'parcel-pickup-saved-address');
    await _chooseSavedAddress(tester, 'parcel-drop-saved-address');
    await _enterParcelText(tester, 'Enter parcel weight', '1');
    await _tapContinue(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Both postal areas are listed for delivery.'),
      findsOneWidget,
    );
    final checks = requests
        .where(
          (request) => request.url.path == '/api/v1/delivery/serviceability',
        )
        .toList();
    expect(checks, hasLength(2));
    expect(jsonDecode(checks.first.body), {
      'latitude': 16.87,
      'longitude': 81.93,
      'pincode': '533308',
    });
    expect(
      find.textContaining('Submission separately checks the road route'),
      findsOneWidget,
    );
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('No parcel requests yet'), findsOneWidget);
  });

  testWidgets(
    'history loads later pages using the server pagination contract',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <http.Request>[];
      CustomerApi.instance = _api((request) async {
        requests.add(request);
        final offset = request.url.queryParameters['offset'];
        return _jsonResponse({
          'data': offset == '0'
              ? List.generate(20, (_) => _bookingJson())
              : [_bookingJson()],
          'pagination': {'limit': 20, 'offset': int.parse(offset ?? '0')},
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParcelHistoryPage()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests.first.url.queryParameters['offset'], '0');
      await tester.scrollUntilVisible(
        find.text('Load more parcel requests'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load more parcel requests'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(requests, hasLength(2));
      expect(requests.last.url.queryParameters, {
        'limit': '20',
        'offset': '20',
      });
      expect(find.text('Load more parcel requests'), findsNothing);
      expect(find.textContaining('Request record: requested'), findsWidgets);
    },
  );

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
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Parcel history is temporarily unavailable.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry parcel history'));
    await tester.pump(const Duration(milliseconds: 500));

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
    CustomerApi.instance = _api((request) async {
      if (request.url.path == '/api/v1/me/addresses') {
        return _savedAddressResponse();
      }
      if (request.url.path == '/api/v1/delivery/serviceability') {
        return _jsonResponse({
          'data': {
            'isDeliverable': true,
            'message': 'Delivery is available at this location.',
          },
        });
      }
      return _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required to submit a parcel.',
        },
      }, statusCode: 401);
    });

    await _pumpParcelPage(tester);
    await _chooseSavedAddress(tester, 'parcel-pickup-saved-address');
    await _chooseSavedAddress(tester, 'parcel-drop-saved-address');
    await _enterParcelText(tester, 'Enter parcel weight', '1');
    await _tapContinue(tester);
    await tester.tap(find.text('Submit Parcel Request'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Customer authentication is required to submit a parcel.'),
      findsOneWidget,
    );
    expect(find.text('Parcel Request Details'), findsNothing);
  });

  testWidgets('unconfigured parcel mode is labeled and does not fake success', (
    tester,
  ) async {
    await _pumpParcelPage(tester);
    expect(find.textContaining('Backend not configured'), findsOneWidget);

    await _enterParcelText(tester, 'Enter pickup location', 'Pickup Road');
    await _enterParcelText(tester, 'Enter drop location', 'Drop Street');
    await _enterParcelText(tester, 'Enter parcel weight', '1');
    await _tapContinue(tester);
    await tester.tap(find.text('Submit Parcel Request'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('parcel request was not submitted'),
      findsOneWidget,
    );
    expect(find.text('Parcel Request Details'), findsNothing);
  });
}

Future<void> _chooseSavedAddress(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    button,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Home').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpParcelPage(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ParcelPage(
        locationService: ParcelLocationService(
          isLocationServiceEnabled: () async => false,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _enterParcelText(
  WidgetTester tester,
  String hint,
  String value,
) async {
  await tester.scrollUntilVisible(
    find.text(hint),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 500));
  final field = find.ancestor(
    of: find.text(hint),
    matching: find.byType(TextFormField),
  );
  await tester.enterText(field.first, value);
  expect(tester.widget<TextFormField>(field.first).controller?.text, value);
}

Future<void> _tapContinue(WidgetTester tester) async {
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

const _validRequest = ApiParcelBookingRequest(
  pickupLocation: 'Pickup Road',
  dropLocation: 'Drop Street',
  parcelType: 'Documents',
  weightKg: 1.25,
  pickupLatitude: 16.87,
  pickupLongitude: 81.93,
  dropLatitude: 16.88,
  dropLongitude: 81.94,
);

http.Response _savedAddressResponse() => _jsonResponse({
  'data': [
    {
      'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'label': 'Home',
      'address_snapshot': {
        'formattedAddress': '10 Main Road, Sample City',
        'latitude': 16.87,
        'longitude': 81.93,
        'pincode': '533308',
      },
    },
  ],
});

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
