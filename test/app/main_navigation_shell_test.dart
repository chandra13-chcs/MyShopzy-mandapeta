import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myshopzy/app/main_navigation_shell.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/profile/data/selected_delivery_address_store.dart';
import 'package:myshopzy/features/parcel/data/parcel_location_service.dart';
import 'package:myshopzy/shared/presentation/bottom_navigation_bar.dart';

void main() {
  final cart = CartStore.instance;

  setUp(() {
    cart.clear();
    SelectedDeliveryAddressStore.instance.select(null);
  });

  tearDown(() {
    cart.clear();
    SelectedDeliveryAddressStore.instance.select(null);
  });

  testWidgets('main tabs switch without replacing the bottom navigation bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MainNavigationShell()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );

    await tester.tap(find.text('Orders'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Orders')).style?.color,
      const Color(0xFFFFC900),
    );

    await tester.tap(find.text('Categories'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Fresh items'), findsOneWidget);
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Cart'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your cart is empty'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cart-continue-shopping')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cart'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('My Account'), findsOneWidget);
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );
    expect(find.byType(ShopzyBottomNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'location banner requests permission only after customer action',
    (tester) async {
      var permission = LocationPermission.denied;
      var permissionRequests = 0;
      final locationService = ParcelLocationService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => permission,
        requestPermission: () async {
          permissionRequests++;
          permission = LocationPermission.whileInUse;
          return permission;
        },
        getCurrentPosition: () async => _testPosition,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationShell(locationService: locationService),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.byKey(const ValueKey('location-permission-banner-action')),
        findsOneWidget,
      );
      expect(permissionRequests, 0);

      await tester.tap(
        find.byKey(const ValueKey('location-permission-banner-action')),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(permissionRequests, 1);
      expect(
        find.byKey(const ValueKey('location-permission-banner-action')),
        findsNothing,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 600));
      expect(permissionRequests, 1);
      expect(
        find.byKey(const ValueKey('location-permission-banner-action')),
        findsNothing,
      );
    },
  );

  testWidgets('unknown permission state does not trigger a permission dialog', (
    tester,
  ) async {
    var permissionRequests = 0;
    final locationService = ParcelLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async =>
          throw PlatformException(code: 'permission_status_unavailable'),
      requestPermission: () async {
        permissionRequests++;
        return LocationPermission.denied;
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: MainNavigationShell(locationService: locationService)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Check Location'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('location-permission-banner-action')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(permissionRequests, 0);
    expect(find.text('Choose address'), findsOneWidget);
  });

  testWidgets('continue shopping opens Home without changing cart contents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    cart.addItem(
      productId: 'continue-shopping-item',
      serviceType: 'local_store',
      merchantId: 'continue-shopping-store',
      name: 'Preserved item',
      description: '',
      priceInPaise: 12000,
      icon: Icons.shopping_bag_outlined,
    );
    final locationService = ParcelLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
    );

    await tester.pumpWidget(
      MaterialApp(home: MainNavigationShell(locationService: locationService)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Cart'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(
      find.byKey(const ValueKey('cart-continue-shopping')),
    );
    await tester.tap(find.byKey(const ValueKey('cart-continue-shopping')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );
    expect(cart.items.single.name, 'Preserved item');
    expect(cart.items.single.quantity, 1);
  });
}

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
