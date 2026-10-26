import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  tearDown(() {
    CartStore.instance.clear();
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets(
    'checkout requires a customer session and cannot place an order',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));

      expect(find.text('Sign in to access checkout.'), findsOneWidget);
      expect(find.text('Place Order'), findsNothing);
      expect(find.text('Order Success'), findsNothing);
      expect(CartStore.instance.items, isEmpty);
    },
  );
}
