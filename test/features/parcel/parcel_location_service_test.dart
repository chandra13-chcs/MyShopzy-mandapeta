import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myshopzy/features/parcel/data/parcel_location_service.dart';
import 'package:myshopzy/features/parcel/presentation/parcel_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  setUp(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('requests foreground permission and fills the detected address', (
    tester,
  ) async {
    var requestedPermission = false;
    var geocodedCoordinates = <double>[];
    final locationService = ParcelLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        requestedPermission = true;
        return LocationPermission.whileInUse;
      },
      getCurrentPosition: () async => _position,
      reverseGeocode: (latitude, longitude) async {
        geocodedCoordinates = [latitude, longitude];
        return const [
          Placemark(
            name: '12 Market Road',
            locality: 'Sample City',
            administrativeArea: 'Andhra Pradesh',
            country: 'India',
          ),
        ];
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: ParcelPage(locationService: locationService)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('Enter pickup location'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(requestedPermission, isTrue);
    expect(geocodedCoordinates, [_position.latitude, _position.longitude]);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      '12 Market Road, Sample City, Andhra Pradesh, India',
    );
    expect(
      find.text('Pickup address detected. You can edit it.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a clear message when foreground permission is denied', (
    tester,
  ) async {
    var requestedPosition = false;
    var permissionRequests = 0;
    final locationService = ParcelLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        permissionRequests++;
        return permissionRequests == 1
            ? LocationPermission.denied
            : LocationPermission.whileInUse;
      },
      getCurrentPosition: () async {
        requestedPosition = true;
        return _position;
      },
      reverseGeocode: (_, _) async => const [
        Placemark(locality: 'Sample City'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ParcelPage(locationService: locationService)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('Enter pickup location'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(requestedPosition, isFalse);
    expect(
      find.text(
        'Location permission was denied. Allow location access or enter the pickup address manually.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('parcel-use-current-location')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      isEmpty,
    );

    final retryButton = find.byKey(
      const ValueKey('parcel-use-current-location'),
    );
    await tester.ensureVisible(retryButton);
    await tester.pump();
    await tester.tap(retryButton);
    await tester.pump(const Duration(milliseconds: 500));
    expect(requestedPosition, isTrue);
    expect(permissionRequests, 2);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'Sample City',
    );
  });

  testWidgets('manual pickup edits are kept when automatic location resolves', (
    tester,
  ) async {
    final address = Completer<List<Placemark>>();
    final locationService = ParcelLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async => LocationPermission.whileInUse,
      getCurrentPosition: () async => _position,
      reverseGeocode: (_, _) => address.future,
    );

    await tester.pumpWidget(
      MaterialApp(home: ParcelPage(locationService: locationService)),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Enter pickup location'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    final pickupField = find.byType(TextFormField).first;
    await tester.enterText(pickupField, 'Manually entered pickup');
    address.complete(const [Placemark(locality: 'Detected locality')]);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<TextFormField>(pickupField).controller?.text,
      'Manually entered pickup',
    );
    expect(
      find.text(
        'Location detected. Your manually entered pickup address was kept.',
      ),
      findsOneWidget,
    );
  });
}

final _position = Position(
  longitude: 81.95,
  latitude: 16.87,
  timestamp: DateTime.utc(2026, 10, 21),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
