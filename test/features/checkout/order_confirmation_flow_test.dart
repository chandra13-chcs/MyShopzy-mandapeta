import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/orders/presentation/order_success_page.dart';

void main() {
  final cart = CartStore.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  testWidgets(
    'demo Place Order does not confirm, navigate, or clear cart on repeated taps',
    (tester) async {
      cart.addItem(
        productId: 'order-confirmation-test-item',
        serviceType: 'local_store',
        merchantId: 'order-confirmation-test-store',
        name: 'Test item',
        description: '',
        priceInPaise: 12000,
        icon: Icons.shopping_bag_outlined,
      );
      await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

      final placeOrder = find.widgetWithText(FilledButton, 'Place Order');
      expect(tester.widget<FilledButton>(placeOrder).onPressed, isNull);

      await tester.ensureVisible(find.text('Change'));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(placeOrder).onPressed, isNotNull);
      await tester.ensureVisible(placeOrder);
      await tester.tap(placeOrder);
      await tester.tap(placeOrder);
      await tester.pumpAndSettle();

      expect(find.text('Order flow will be connected next.'), findsOneWidget);
      expect(find.byType(OrderSuccessPage), findsNothing);
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(cart.totalQuantity, 1);
      expect(cart.subtotalInPaise, 12000);
    },
  );
}
