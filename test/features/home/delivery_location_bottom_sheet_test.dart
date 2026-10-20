import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/profile/models/saved_address.dart';
import 'package:myshopzy/features/profile/presentation/saved_addresses_page.dart';

void main() {
  testWidgets('home location selector shows saved demo addresses and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location Permission is Off'), findsOneWidget);
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
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location-permission-grant')));
    await tester.pump();

    expect(find.text('Finding your location...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'selecting an existing address labels it as demo and unverified',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('home-delivery-address-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('saved-delivery-address-home')),
      );
      await tester.pumpAndSettle();

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
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location-view-all')));
    await tester.pumpAndSettle();

    expect(find.byType(SavedAddressesPage), findsOneWidget);
    expect(find.text('Saved Addresses'), findsOneWidget);
  });

  testWidgets('manual entry opens the existing checkout address form', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location-enter-manually')));
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(find.text('Add New Address'), findsOneWidget);
    expect(find.text('Full Address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location sheet scrolls without overflow on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('home-delivery-address-selector')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location Permission is Off'), findsOneWidget);
    expect(find.text('Select Delivery Address'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('location-enter-manually')),
    );
    expect(find.text('Enter Location Manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
