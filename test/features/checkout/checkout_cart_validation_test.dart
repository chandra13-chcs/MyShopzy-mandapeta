import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/profile/data/selected_delivery_address_store.dart';
import 'package:myshopzy/features/profile/models/saved_address.dart';

import 'checkout_test_support.dart';

void main() {
  final cart = CartStore.instance;

  setUp(() {
    cart.clear();
    SelectedDeliveryAddressStore.instance.select(null);
  });
  tearDown(tearDownCheckoutTest);

  testWidgets('checkout shows an actionable empty-cart state', (tester) async {
    await setUpAuthenticatedCheckout(cartItems: const []);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checkout-empty-cart-title')),
      findsOneWidget,
    );
    expect(find.text('Place Order'), findsNothing);
    expect(find.text('Continue Shopping'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checkout-continue-shopping')),
      findsOneWidget,
    );
  });

  testWidgets('checkout explains why placing an order is unavailable', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout();
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('checkout-address-validation')),
      findsOneWidget,
    );
    expect(
      find.text('Select or enter a complete delivery address to continue.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Place Order'),
    );
    expect(button.onPressed, isNull);

    cart.clear();
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Place Order'), findsNothing);
  });

  testWidgets('GPS-only fallback is not accepted as a delivery address', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout();
    SelectedDeliveryAddressStore.instance.select(
      const SavedAddress(
        id: 'current-location',
        label: 'Current location',
        address: 'Choose your location',
        icon: Icons.my_location_rounded,
        latitude: 16.87,
        longitude: 81.93,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('checkout-address-validation')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Place Order'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('checkout shows the selected variant and its line total', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout(
      cartItems: const [
        CheckoutCartItemFixture(
          productId: 'checkout-variant-item',
          variantId: 'checkout-500g',
          variantLabel: '500 g',
          name: 'Variant item',
          priceMinor: 15400,
          quantity: 2,
        ),
      ],
      selectHomeAddress: true,
    );

    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('₹308'), findsWidgets);
  });

  testWidgets('checkout keeps different variants of one product separate', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout(
      cartItems: const [
        CheckoutCartItemFixture(
          productId: 'checkout-multiple-variants',
          variantId: 'checkout-500g',
          variantLabel: '500 g',
          name: 'Variant item',
          priceMinor: 15400,
        ),
        CheckoutCartItemFixture(
          productId: 'checkout-multiple-variants',
          variantId: 'checkout-1kg',
          variantLabel: '1 kg',
          name: 'Variant item',
          priceMinor: 28400,
        ),
      ],
      selectHomeAddress: true,
    );

    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    expect(cart.items, hasLength(2));
    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('₹154'), findsOneWidget);
    expect(find.text('₹284'), findsOneWidget);
  });
}
