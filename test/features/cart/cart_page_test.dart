import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';

void main() {
  final cart = CartStore.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  testWidgets('empty cart hides checkout and offers a clear empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CartPage()));

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Continue Shopping'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsNothing);
  });

  testWidgets('cart subtotal and quantity controls stay synchronized', (
    tester,
  ) async {
    cart.addItem(
      productId: 'cart-page-item',
      serviceType: 'local_store',
      merchantId: 'cart-page-store',
      name: 'Cart page item',
      description: 'Test item',
      priceInPaise: 15400,
      icon: Icons.shopping_bag_outlined,
    );
    await tester.pumpWidget(const MaterialApp(home: CartPage()));

    expect(find.text('₹154'), findsNWidgets(3));
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    expect(find.text('₹308'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pumpAndSettle();
    expect(find.text('₹154'), findsNWidgets(3));

    await tester.tap(find.byTooltip('Remove item'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsNothing);
  });
}
