import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/coupons/presentation/coupons_page.dart';

import 'checkout_test_support.dart';

void main() {
  tearDown(tearDownCheckoutTest);

  testWidgets('demo coupons are not applied to server-priced checkout', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout(selectHomeAddress: true);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    final totalBeforeCoupon = _price(tester, 'checkout-total-value');
    final discountBeforeCoupon = _price(tester, 'coupon-discount-value');
    expect(totalBeforeCoupon, '₹1030');
    expect(discountBeforeCoupon, '−₹0');

    await _enterCoupon(tester, 'MYSHOPZY50');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Demo coupons are not included in the backend checkout quote.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('applied-coupon-code')), findsNothing);
    expect(_price(tester, 'coupon-discount-value'), discountBeforeCoupon);
    expect(_price(tester, 'checkout-total-value'), totalBeforeCoupon);
  });

  testWidgets('demo coupon page directs customers to Checkout', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CouponsPage()));

    await tester.tap(find.text('Use at Checkout').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Use MYSHOPZY50 during Checkout to validate it against your cart.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Place Order enables after address confirmation', (tester) async {
    await setUpAuthenticatedCheckout();
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    final placeOrder = find.widgetWithText(FilledButton, 'Place Order');
    expect(tester.widget<FilledButton>(placeOrder).onPressed, isNull);

    await tester.ensureVisible(find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(placeOrder).onPressed, isNotNull);
    expect(find.text('Order flow will be connected next.'), findsNothing);
  });

  testWidgets('unresolved current location cannot enable Place Order', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout();
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    final placeOrder = find.widgetWithText(FilledButton, 'Place Order');
    await tester.ensureVisible(find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Current Location'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(placeOrder).onPressed, isNull);
    expect(
      find.byKey(const ValueKey('checkout-address-validation')),
      findsOneWidget,
    );
  });
}

Future<void> _enterCoupon(WidgetTester tester, String value) async {
  final field = find.byKey(const ValueKey('coupon-code-field'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

String _price(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;
