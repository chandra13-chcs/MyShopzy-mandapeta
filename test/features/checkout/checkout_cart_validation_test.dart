import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';

void main() {
  final cart = CartStore.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  testWidgets('checkout shows an actionable empty-cart state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checkout-empty-cart-title')),
      findsOneWidget,
    );
    expect(find.text('Place Order'), findsNothing);
    expect(find.text('Return to Cart'), findsOneWidget);
    expect(find.text('Delivery Instructions'), findsOneWidget);
  });

  testWidgets('checkout explains why placing an order is unavailable', (
    tester,
  ) async {
    cart.addItem(
      productId: 'checkout-validation-item',
      serviceType: 'local_store',
      merchantId: 'checkout-validation-store',
      name: 'Validation item',
      description: '',
      priceInPaise: 15400,
      icon: Icons.shopping_bag_outlined,
    );
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    expect(
      find.byKey(const ValueKey('checkout-address-validation')),
      findsOneWidget,
    );
    expect(
      find.text('Select and confirm a delivery location to continue.'),
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

  testWidgets('checkout shows the selected variant and its line total', (
    tester,
  ) async {
    for (var index = 0; index < 2; index++) {
      cart.addItem(
        productId: 'checkout-variant-item',
        serviceType: 'local_store',
        merchantId: 'checkout-variant-store',
        productVariantId: 'checkout-500g',
        variantLabel: '500 g',
        name: 'Variant item',
        description: '',
        priceInPaise: 15400,
        icon: Icons.shopping_bag_outlined,
      );
    }

    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('₹308'), findsWidgets);
  });

  testWidgets('checkout keeps different variants of one product separate', (
    tester,
  ) async {
    cart.addItem(
      productId: 'checkout-multiple-variants',
      serviceType: 'local_store',
      merchantId: 'checkout-variant-store',
      productVariantId: 'checkout-500g',
      variantLabel: '500 g',
      name: 'Variant item',
      description: '',
      priceInPaise: 15400,
      icon: Icons.shopping_bag_outlined,
    );
    cart.addItem(
      productId: 'checkout-multiple-variants',
      serviceType: 'local_store',
      merchantId: 'checkout-variant-store',
      productVariantId: 'checkout-1kg',
      variantLabel: '1 kg',
      name: 'Variant item',
      description: '',
      priceInPaise: 28400,
      icon: Icons.shopping_bag_outlined,
    );

    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

    expect(cart.items, hasLength(2));
    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('₹154'), findsOneWidget);
    expect(find.text('₹284'), findsOneWidget);
  });
}
