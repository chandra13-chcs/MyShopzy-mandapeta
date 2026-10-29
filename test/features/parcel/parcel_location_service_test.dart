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
    CustomerApi.instance = CustomerApi(
      baseUrl: '',
      enableDevelopmentPreview: true,
    );
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('requests permission only after tapping and fills the address', (
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

    await _pumpParcelPage(tester, locationService);
    await tester.scrollUntilVisible(
      find.text('Enter pickup location'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(requestedPermission, isFalse);
    expect(geocodedCoordinates, isEmpty);
    final useLocation = find.byKey(
      const ValueKey('parcel-use-current-location'),
    );
    await tester.scrollUntilVisible(
      useLocation,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(useLocation);
    await tester.pump(const Duration(milliseconds: 500));

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

    await _pumpParcelPage(tester, locationService);
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
    await tester.scrollUntilVisible(
      retryButton,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(retryButton);
    await tester.pump(const Duration(milliseconds: 500));
    expect(requestedPosition, isFalse);
    expect(permissionRequests, 1);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      isEmpty,
    );

    await tester.tap(retryButton);
    await tester.pump(const Duration(milliseconds: 500));
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

    await _pumpParcelPage(tester, locationService);
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
        'Location detected. Your manually selected pickup address was kept.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('geocoding failure keeps a friendly manual-entry fallback', (
    tester,
  ) async {
    var permissionRequests = 0;
    final locationService = ParcelLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async {
        permissionRequests++;
        return LocationPermission.whileInUse;
      },
      getCurrentPosition: () async => _position,
      reverseGeocode: (_, _) async => const [],
    );

    await _pumpParcelPage(tester, locationService);

    expect(permissionRequests, 0);
    expect(
      find.text(
        'Your location was found, but no readable address was returned. Enter the pickup address manually.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.textContaining('16.87'), findsNothing);
    expect(find.textContaining('81.95'), findsNothing);
  });

  testWidgets('opens location settings and refreshes after returning', (
    tester,
  ) async {
    var locationEnabled = false;
    var openedSettings = false;
    var requestedPosition = false;
    final locationService = ParcelLocationService(
      isLocationServiceEnabled: () async => locationEnabled,
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async => LocationPermission.whileInUse,
      getCurrentPosition: () async {
        requestedPosition = true;
        return _position;
      },
      reverseGeocode: (_, _) async => const [
        Placemark(locality: 'Sample City'),
      ],
      openLocationSettings: () async {
        openedSettings = true;
        return true;
      },
    );

    await _pumpParcelPage(tester, locationService);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('parcel-location-settings')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(requestedPosition, isFalse);
    expect(find.text('Enable location services'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('parcel-location-settings')));
    expect(openedSettings, isTrue);

    locationEnabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(requestedPosition, isTrue);
    expect(find.text('Sample City'), findsOneWidget);
  });

  testWidgets(
    'permanently denied permission opens app settings and refreshes',
    (tester) async {
      var permission = LocationPermission.deniedForever;
      var permissionRequests = 0;
      var openedSettings = false;
      final locationService = ParcelLocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => permission,
        requestPermission: () async {
          permissionRequests++;
          return LocationPermission.whileInUse;
        },
        getCurrentPosition: () async => _position,
        reverseGeocode: (_, _) async => const [
          Placemark(locality: 'Sample City'),
        ],
        openAppSettings: () async {
          openedSettings = true;
          return true;
        },
      );

      await _pumpParcelPage(tester, locationService);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('parcel-location-settings')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Open app settings'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('parcel-location-settings')));
      expect(openedSettings, isTrue);

      permission = LocationPermission.whileInUse;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));

      expect(permissionRequests, 0);
      expect(find.text('Sample City'), findsOneWidget);
    },
  );
}

Future<void> _pumpParcelPage(
  WidgetTester tester,
  ParcelLocationService locationService,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: ParcelPage(locationService: locationService)),
  );
  await tester.pump(const Duration(milliseconds: 500));
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
