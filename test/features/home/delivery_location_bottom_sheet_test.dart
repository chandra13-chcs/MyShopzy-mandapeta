import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/parcel/data/parcel_location_service.dart';
import 'package:myshopzy/features/profile/models/saved_address.dart';
import 'package:myshopzy/features/profile/data/selected_delivery_address_store.dart';
import 'package:myshopzy/features/profile/presentation/saved_addresses_page.dart';

void main() {
  setUp(() => SelectedDeliveryAddressStore.instance.select(null));
  tearDown(() => SelectedDeliveryAddressStore.instance.select(null));

  testWidgets('home location selector shows saved demo addresses and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_homeApp(_locationService()));
    await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);

    expect(find.text('Location access is off'), findsOneWidget);
    expect(
      find.textContaining('Allow location access to find your delivery area'),
      findsOneWidget,
    );
    expect(find.text('Select Delivery Address'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('saved-delivery-address-home')),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('saved-delivery-address-home')),
        matching: find.byIcon(Icons.home_outlined),
      ),
      findsOneWidget,
    );
    for (final address in demoSavedAddresses) {
      expect(find.text('Demo address: ${address.address}'), findsOneWidget);
    }
    expect(find.text('VIEW ALL'), findsOneWidget);
    expect(find.text('Enter Location Manually'), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grant action starts the current location request', (
    tester,
  ) async {
    final position = Completer<Position>();
    final service = _locationService(
      permission: LocationPermission.whileInUse,
      getCurrentPosition: () => position.future,
    );
    await tester.pumpWidget(_homeApp(service));
    await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('location-permission-grant')));
    await tester.pump();

    expect(find.text('Finding your location...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    position.complete(_testPosition);
    await _pumpHome(tester);
    expect(find.text('Market Street, Ravulapalem'), findsOneWidget);
  });

  testWidgets(
    'selecting an existing address labels it as demo and unverified',
    (tester) async {
      await tester.pumpWidget(_homeApp(_locationService()));
      await _pumpHome(tester);

      await tester.tap(
        find.byKey(const ValueKey('home-delivery-address-selector')),
      );
      await _pumpHome(tester);
      await tester.tap(
        find.byKey(const ValueKey('saved-delivery-address-home')),
      );
      await _pumpHome(tester);

      expect(
        find.text('Home · Demo address: ${demoSavedAddresses.first.address}'),
        findsOneWidget,
      );
      expect(find.text('Delivery area confirmed'), findsNothing);
    },
  );

  testWidgets('view all opens the existing saved-address screen', (
    tester,
  ) async {
    await tester.pumpWidget(_homeApp(_locationService()));
    await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('location-view-all')));
    await _pumpHome(tester);

    expect(find.byType(SavedAddressesPage), findsOneWidget);
    expect(find.text('Saved Addresses'), findsOneWidget);
  });

  testWidgets('manual entry opens the existing checkout address form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_homeApp(_locationService()));
    await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('location-enter-manually')),
    );
    await tester.tap(find.byKey(const ValueKey('location-enter-manually')));
    await _pumpHome(tester);

    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(find.text('Add New Address'), findsOneWidget);
    expect(find.text('Full Address'), findsOneWidget);

    final addressField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Full Address',
    );
    await tester.enterText(addressField, '42 River Road, Ravulapalem');
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await _pumpHome(tester);
    await tester.tap(find.text('Save and Deliver Here'));
    await _pumpHome(tester);

    Navigator.of(tester.element(find.byType(CheckoutPage))).pop();
    await _pumpHome(tester);
    expect(find.text('Other · 42 River Road, Ravulapalem'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location sheet scrolls without overflow on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_homeApp(_locationService()));
    await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);

    expect(find.text('Location access is off'), findsOneWidget);
    expect(find.text('Select Delivery Address'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('location-enter-manually')),
    );
    expect(find.text('Enter Location Manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'granted permission is not requested again and shows an address',
    (tester) async {
      var permissionRequests = 0;
      final service = _locationService(
        permission: LocationPermission.whileInUse,
        requestPermission: () async {
          permissionRequests++;
          return LocationPermission.whileInUse;
        },
      );
      await tester.pumpWidget(_homeApp(service));
      await _pumpHome(tester);

      expect(find.text('Market Street, Ravulapalem'), findsOneWidget);
      expect(permissionRequests, 0);

      await tester.tap(
        find.byKey(const ValueKey('home-delivery-address-selector')),
      );
      await _pumpHome(tester);
      expect(find.text('Location access is on'), findsOneWidget);
      expect(permissionRequests, 0);
    },
  );

  testWidgets('permission denial leaves manual address selection available', (
    tester,
  ) async {
    var permissionRequests = 0;
    var positionRequests = 0;
    final service = _locationService(
      requestPermission: () async {
        permissionRequests++;
        return LocationPermission.denied;
      },
      getCurrentPosition: () async {
        positionRequests++;
        return _testPosition;
      },
    );
    await tester.pumpWidget(_homeApp(service));
    await _pumpHome(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);

    expect(permissionRequests, 0);
    expect(positionRequests, 0);
    expect(find.text('Location access is off'), findsOneWidget);
    expect(find.text('Enter Location Manually'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('location-permission-grant')));
    await _pumpHome(tester);
    expect(permissionRequests, 1);
    expect(positionRequests, 0);
    expect(find.textContaining('Allow location access'), findsOneWidget);
    expect(find.text('Enter Location Manually'), findsOneWidget);
  });

  testWidgets('granting permission fetches and reverse-geocodes location', (
    tester,
  ) async {
    var permission = LocationPermission.denied;
    var permissionRequests = 0;
    var positionRequests = 0;
    final service = _locationService(
      permissionGetter: () async => permission,
      requestPermission: () async {
        permissionRequests++;
        permission = LocationPermission.whileInUse;
        return permission;
      },
      getCurrentPosition: () async {
        positionRequests++;
        return _testPosition;
      },
      reverseGeocode: (_, _) async => const [
        Placemark(
          street: 'Market Street',
          locality: 'Ravulapalem',
          postalCode: '533308',
        ),
      ],
    );
    await tester.pumpWidget(_homeApp(service));
    await _pumpHome(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('location-permission-grant')));
    await _pumpHome(tester);

    expect(permissionRequests, 1);
    expect(positionRequests, 1);
    expect(find.text('Market Street, Ravulapalem'), findsOneWidget);
    expect(
      SelectedDeliveryAddressStore.instance.selectedAddress?.latitude,
      16.87,
    );
    expect(
      SelectedDeliveryAddressStore.instance.selectedAddress?.longitude,
      81.95,
    );
    expect(
      SelectedDeliveryAddressStore.instance.selectedAddress?.pincode,
      '533308',
    );
  });

  testWidgets('disabled GPS is presented separately from denied permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(
        _locationService(
          serviceEnabled: false,
          permission: LocationPermission.denied,
        ),
      ),
    );
    await _pumpHome(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);

    expect(find.text('Device location is off'), findsOneWidget);
    expect(find.text('Location access is off'), findsNothing);
    expect(find.text('ENABLE'), findsOneWidget);
  });

  testWidgets('geocoding failure uses a friendly fallback, not coordinates', (
    tester,
  ) async {
    final service = _locationService(
      permission: LocationPermission.whileInUse,
      reverseGeocode: (_, _) async => throw TypeError(),
    );
    await tester.pumpWidget(_homeApp(service));
    await _pumpHome(tester);

    expect(find.text('Choose your location'), findsOneWidget);
    expect(find.textContaining('81.950000'), findsNothing);
  });

  testWidgets('saved selection wins over an in-flight GPS lookup', (
    tester,
  ) async {
    final geocode = Completer<List<Placemark>>();
    final service = _locationService(
      permission: LocationPermission.whileInUse,
      reverseGeocode: (_, _) => geocode.future,
    );
    await tester.pumpWidget(_homeApp(service));
    await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('saved-delivery-address-home')));
    await _pumpHome(tester);
    geocode.complete(const [Placemark(street: 'Delayed GPS Street')]);
    await _pumpHome(tester);

    expect(
      find.text('Home · Demo address: ${demoSavedAddresses.first.address}'),
      findsOneWidget,
    );
    expect(find.text('Delayed GPS Street'), findsNothing);
  });

  testWidgets('manual entry keeps delayed GPS from changing the home label', (
    tester,
  ) async {
    final geocode = Completer<List<Placemark>>();
    final service = _locationService(
      permission: LocationPermission.whileInUse,
      reverseGeocode: (_, _) => geocode.future,
    );
    await tester.pumpWidget(_homeApp(service));
    await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('location-enter-manually')));
    await _pumpHome(tester);
    expect(find.byType(CheckoutPage), findsOneWidget);

    geocode.complete(const [Placemark(street: 'Delayed GPS Street')]);
    await _pumpHome(tester);
    final navigator = Navigator.of(tester.element(find.byType(CheckoutPage)));
    navigator.pop();
    navigator.pop();
    await _pumpHome(tester);

    expect(find.text('Choose your location'), findsOneWidget);
    expect(find.text('Delayed GPS Street'), findsNothing);
  });

  testWidgets('returning from app settings refreshes permission and location', (
    tester,
  ) async {
    var permission = LocationPermission.deniedForever;
    var openedSettings = false;
    final service = _locationService(
      permissionGetter: () async => permission,
      openAppSettings: () async {
        openedSettings = true;
        return true;
      },
    );
    await tester.pumpWidget(_homeApp(service));
    await _pumpHome(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await _pumpHome(tester);

    expect(find.text('Location access is permanently denied'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('location-permission-grant')));
    await _pumpHome(tester);
    expect(openedSettings, isTrue);

    permission = LocationPermission.whileInUse;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpHome(tester);
    expect(find.text('Market Street, Ravulapalem'), findsOneWidget);
  });
}

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

ParcelLocationService _locationService({
  bool serviceEnabled = true,
  LocationPermission permission = LocationPermission.denied,
  Future<LocationPermission> Function()? permissionGetter,
  Future<LocationPermission> Function()? requestPermission,
  Future<Position> Function()? getCurrentPosition,
  Future<List<Placemark>> Function(double, double)? reverseGeocode,
  Future<bool> Function()? openLocationSettings,
  Future<bool> Function()? openAppSettings,
}) => ParcelLocationService(
  isLocationServiceEnabled: () async => serviceEnabled,
  checkPermission: permissionGetter ?? () async => permission,
  requestPermission:
      requestPermission ?? () async => LocationPermission.whileInUse,
  getCurrentPosition: getCurrentPosition ?? () async => _testPosition,
  reverseGeocode:
      reverseGeocode ??
      (_, _) async => const [
        Placemark(street: 'Market Street', locality: 'Ravulapalem'),
      ],
  openLocationSettings: openLocationSettings ?? () async => true,
  openAppSettings: openAppSettings ?? () async => true,
);

Widget _homeApp(ParcelLocationService locationService) => MaterialApp(
  home: HomePage(locationService: locationService),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

final _testPosition = Position(
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
