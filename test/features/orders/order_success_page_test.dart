import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/presentation/order_details_page.dart';
import 'package:myshopzy/features/orders/presentation/order_success_page.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';

void main() {
  testWidgets('success screen uses the confirmed record and opens details', (
    tester,
  ) async {
    final order = _confirmedOrder();
    await tester.pumpWidget(
      MaterialApp(home: OrderSuccessPage(confirmedOrder: order)),
    );

    expect(find.byKey(const ValueKey('order-success-mark')), findsOneWidget);
    expect(find.text('Order placed successfully'), findsOneWidget);
    expect(find.text('Order ID: ORDER-123'), findsOneWidget);
    expect(find.text('Home · Demo Address'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('order-success-view-details')));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsPage), findsOneWidget);
    expect(find.text('ORDER-123'), findsOneWidget);
  });

  testWidgets('return home removes the success route and opens HomePage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OrderSuccessPage(confirmedOrder: _confirmedOrder())),
    );

    await tester.tap(find.byKey(const ValueKey('order-success-return-home')));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byKey(const ValueKey('order-success-screen')), findsNothing);
  });
}

OrderRecord _confirmedOrder() => OrderRecord(
  storeName: 'Demo Store',
  icon: Icons.storefront_outlined,
  orderId: 'ORDER-123',
  dateTime: 'Today',
  itemSummary: '1 item · Demo item',
  totalInPaise: 10000,
  status: 'Order Placed',
  statusMessage: 'Order accepted',
  orderTab: OrdersTab.ongoing,
  serviceType: 'Local Store',
  items: const [
    OrderLineItem(
      name: 'Demo item',
      quantity: 1,
      unitPriceInPaise: 7000,
      icon: Icons.shopping_bag_outlined,
    ),
  ],
  deliveryAddress: 'Home · Demo Address',
  paymentMethod: 'Cash on Delivery',
  paymentStatus: 'Pending',
  deliveryChargeInPaise: 3000,
  discountInPaise: 0,
  trackingStatus: OrderTrackingStatus.orderPlaced,
);
