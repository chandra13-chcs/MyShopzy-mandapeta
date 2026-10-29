import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/checkout/presentation/checkout_page.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/presentation/order_details_page.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';

import 'checkout_test_support.dart';

void main() {
  tearDown(tearDownCheckoutTest);

  testWidgets('quick instruction selection is visibly exclusive', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout();
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave at the door').first);
    await tester.pumpAndSettle();
    expect(_choice(tester, 'Leave at the door').selected, isTrue);
    expect(_choice(tester, 'Call me on arrival').selected, isFalse);

    await tester.tap(find.text('Call me on arrival').first);
    await tester.pumpAndSettle();
    expect(_choice(tester, 'Leave at the door').selected, isFalse);
    expect(_choice(tester, 'Call me on arrival').selected, isTrue);
  });

  testWidgets('custom instructions accept text up to 200 characters', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout();
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();
    final instruction = List.filled(200, 'A').join();

    await tester.enterText(
      find.byKey(const ValueKey('custom-delivery-instructions')),
      '$instruction extra',
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(
      find.byKey(const ValueKey('custom-delivery-instructions')),
    );
    expect(textField.controller!.text, instruction);
    expect(textField.maxLength, 200);
    expect(find.text('200/200'), findsOneWidget);
  });

  testWidgets('instructions are optional and can be cleared', (tester) async {
    await setUpAuthenticatedCheckout();
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();

    expect(find.text('Clear'), findsNothing);
    expect(
      find.byKey(const ValueKey('delivery-instruction-preview')),
      findsNothing,
    );

    await tester.tap(find.text('Hand it to me'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-delivery-instructions')),
      'Please ring the bell',
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsNothing);
    expect(
      find.byKey(const ValueKey('delivery-instruction-preview')),
      findsNothing,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('custom-delivery-instructions')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(_choice(tester, 'Hand it to me').selected, isFalse);
  });

  testWidgets('selected instruction survives Checkout address navigation', (
    tester,
  ) async {
    await setUpAuthenticatedCheckout();
    await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave at the door').first);
    await tester.enterText(
      find.byKey(const ValueKey('custom-delivery-instructions')),
      'Place beside the blue pot',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();

    expect(_choice(tester, 'Leave at the door').selected, isTrue);
    expect(find.text('Place beside the blue pot'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('custom-delivery-instructions')),
          )
          .controller!
          .text,
      'Place beside the blue pot',
    );
  });

  test('OrderRecord stores an optional delivery instruction', () {
    final order = _order(deliveryInstruction: 'Leave at the door\nRing bell');
    expect(order.deliveryInstruction, 'Leave at the door\nRing bell');
    expect(_order().deliveryInstruction, isNull);
  });

  testWidgets('Order Details shows and hides delivery instructions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailsPage(
          order: _order(deliveryInstruction: 'Call on arrival'),
        ),
      ),
    );
    expect(find.text('Delivery Instructions'), findsOneWidget);
    expect(find.text('Call on arrival'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _order())),
    );
    expect(find.text('Delivery Instructions'), findsNothing);
    expect(find.text('Call on arrival'), findsNothing);
  });
}

ChoiceChip _choice(WidgetTester tester, String label) {
  return tester.widget<ChoiceChip>(
    find.ancestor(
      of: find.text(label).first,
      matching: find.byType(ChoiceChip),
    ),
  );
}

OrderRecord _order({String? deliveryInstruction}) {
  return OrderRecord(
    storeName: 'Delivery Instruction Test Store',
    icon: Icons.storefront_outlined,
    orderId: 'DELIVERY-INSTRUCTION-TEST',
    dateTime: 'Today',
    itemSummary: '1 item · Sample',
    totalInPaise: 1000,
    status: 'On the way',
    statusMessage: 'Demo order status',
    orderTab: OrdersTab.ongoing,
    serviceType: 'Local Store',
    items: const [
      OrderLineItem(
        name: 'Sample',
        quantity: 1,
        unitPriceInPaise: 1000,
        icon: Icons.shopping_bag_outlined,
      ),
    ],
    deliveryAddress: 'Home · Demo Address',
    paymentMethod: 'UPI',
    paymentStatus: 'Demo · not processed',
    deliveryChargeInPaise: 0,
    discountInPaise: 0,
    trackingStatus: OrderTrackingStatus.onTheWay,
    deliveryInstruction: deliveryInstruction,
  );
}
