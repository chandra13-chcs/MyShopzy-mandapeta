import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/orders/presentation/orders_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets(
    'order history requires a customer session and has no demo count',
    (tester) async {
      expect(OrdersPage.ongoingOrderCount.value, 0);
      await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

      expect(
        find.text('Sign in to access your order history.'),
        findsOneWidget,
      );
      expect(find.textContaining('MSZ-DEMO'), findsNothing);
      expect(OrdersPage.ongoingOrderCount.value, 0);
    },
  );
}
