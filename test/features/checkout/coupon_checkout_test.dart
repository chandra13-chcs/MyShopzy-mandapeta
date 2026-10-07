import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/coupons/presentation/coupons_page.dart';

void main() {
  final cart = CartStore.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  testWidgets('valid fixed discount applies and updates payable amount', (
    tester,
  ) async {
    _addCartItem(priceInPaise: 100000);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    await _enterCoupon(tester, 'MYSHOPZY50');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();

    expect(find.text('Coupon applied successfully.'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('applied-coupon-code')))
          .data,
      'MYSHOPZY50',
    );
    expect(find.text('Discount ₹50 · demo'), findsOneWidget);
    expect(_price(tester, 'coupon-discount-value'), '−₹50');
    expect(_price(tester, 'checkout-total-value'), '₹980');
  });

  testWidgets('minimum, invalid and empty code errors are clear', (
    tester,
  ) async {
    _addCartItem(priceInPaise: 29900);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    await _enterCoupon(tester, 'MYSHOPZY50');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();
    expect(find.text('Add ₹1 more to use this coupon.'), findsOneWidget);

    await _enterCoupon(tester, 'UNKNOWN');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();
    expect(find.text('Coupon code is not valid.'), findsOneWidget);

    await _enterCoupon(tester, '');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();
    expect(find.text('Coupon code is not valid.'), findsOneWidget);
  });

  testWidgets('percentage coupon recalculates on eligible subtotal', (
    tester,
  ) async {
    _addCartItem(priceInPaise: 100000);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    await _enterCoupon(tester, 'FIRSTORDER');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();

    expect(_price(tester, 'coupon-discount-value'), '−₹150');
    expect(_price(tester, 'checkout-total-value'), '₹880');

    cart.increaseQuantity(cart.items.single.key);
    await tester.pumpAndSettle();
    expect(_price(tester, 'coupon-discount-value'), '−₹300');
    expect(_price(tester, 'checkout-total-value'), '₹1730');
  });

  testWidgets('remove restores original payable amount', (tester) async {
    _addCartItem(priceInPaise: 100000);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await _enterCoupon(tester, 'MYSHOPZY50');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(_price(tester, 'coupon-discount-value'), '−₹0');
    expect(_price(tester, 'checkout-total-value'), '₹1030');
    expect(find.text('MYSHOPZY50'), findsNothing);
  });

  testWidgets('cannot replace an applied coupon without removing it', (
    tester,
  ) async {
    _addCartItem(priceInPaise: 100000);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await _enterCoupon(tester, 'MYSHOPZY50');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();

    await _enterCoupon(tester, 'WELCOME100');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Remove the applied coupon before using another.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('applied-coupon-code')))
          .data,
      'MYSHOPZY50',
    );
    expect(_price(tester, 'coupon-discount-value'), '−₹50');
  });

  testWidgets('cart changes recalculate and remove coupon below minimum', (
    tester,
  ) async {
    _addCartItem(priceInPaise: 30000, quantity: 2);
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await _enterCoupon(tester, 'WELCOME100');
    await tester.tap(find.byKey(const ValueKey('apply-coupon-button')));
    await tester.pumpAndSettle();
    expect(_price(tester, 'coupon-discount-value'), '−₹100');

    cart.decreaseQuantity(cart.items.single.key);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('applied-coupon-code')), findsNothing);
    expect(find.text('Add ₹200 more to use this coupon.'), findsOneWidget);
    expect(_price(tester, 'coupon-discount-value'), '−₹0');
    expect(_price(tester, 'checkout-total-value'), '₹330');
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
}

void _addCartItem({required int priceInPaise, int quantity = 1}) {
  for (var index = 0; index < quantity; index++) {
    CartStore.instance.addItem(
      productId: 'coupon-test-item',
      serviceType: 'local_store',
      merchantId: 'coupon-test-store',
      name: 'Coupon Test Item',
      description: 'Test item',
      priceInPaise: priceInPaise,
      icon: Icons.shopping_bag_outlined,
    );
  }
}

Future<void> _enterCoupon(WidgetTester tester, String value) async {
  await tester.enterText(
    find.byKey(const ValueKey('coupon-code-field')),
    value,
  );
  await tester.pumpAndSettle();
}

String _price(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;
