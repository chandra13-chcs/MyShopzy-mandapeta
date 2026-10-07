import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/orders/data/demo_refund_store.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/presentation/order_details_page.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';
import 'package:myshopzy/features/orders/presentation/orders_page.dart';

void main() {
  test('OrderRecord rechecks cancellation eligibility and reason', () {
    final packedOrder = _order(OrderTrackingStatus.packed);
    expect(packedOrder.cancelByCustomer('Changed my mind'), isFalse);
    expect(packedOrder.orderTab, OrdersTab.ongoing);

    final preparingOrder = _order(OrderTrackingStatus.preparing);
    expect(preparingOrder.cancelByCustomer('  '), isFalse);
    expect(preparingOrder.cancelByCustomer(' Changed my mind '), isTrue);
    expect(preparingOrder.status, 'Cancelled');
    expect(preparingOrder.orderTab, OrdersTab.cancelled);
    expect(preparingOrder.trackingStatus, isNull);
    expect(preparingOrder.cancellationReason, 'Changed my mind');
  });

  testWidgets('cancellation is visible only before Packed', (tester) async {
    for (final status in [
      OrderTrackingStatus.orderPlaced,
      OrderTrackingStatus.orderConfirmed,
      OrderTrackingStatus.preparing,
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: OrderDetailsPage(order: _order(status))),
      );
      expect(find.text('Cancel Order'), findsOneWidget);
    }

    for (final status in [
      OrderTrackingStatus.packed,
      OrderTrackingStatus.findingDeliveryPartner,
      OrderTrackingStatus.riderAssigned,
      OrderTrackingStatus.pickedUp,
      OrderTrackingStatus.onTheWay,
      OrderTrackingStatus.arriving,
      OrderTrackingStatus.delivered,
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: OrderDetailsPage(order: _order(status))),
      );
      expect(find.text('Cancel Order'), findsNothing);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailsPage(
          order: _order(null, orderTab: OrdersTab.cancelled),
        ),
      ),
    );
    expect(find.text('Cancel Order'), findsNothing);
  });

  testWidgets('confirmation requires a reason, including details for Other', (
    tester,
  ) async {
    final order = _order(OrderTrackingStatus.preparing);
    await tester.pumpWidget(_testHome(order));
    await tester.tap(find.text('Open order'));
    await tester.pumpAndSettle();
    await _openCancellationDialog(tester);

    final confirmButton = find.widgetWithText(
      FilledButton,
      'Confirm cancellation',
    );
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Other'));
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Schedule changed');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
  });

  testWidgets(
    'cancelling returns to Cancelled, stores reason, and removes tracking',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
      await tester.ensureVisible(find.text('View Details').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Details').last);
      await tester.pumpAndSettle();

      await _openCancellationDialog(tester);
      await tester.tap(find.text('Changed my mind'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm cancellation'));
      await tester.pumpAndSettle();

      expect(DemoRefundStore.refundForOrderId('MSZ-DEMO-1043'), isNotNull);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Order ID: MSZ-DEMO-1043'), findsOneWidget);

      final cancelledOrderDetailsButton = find.descendant(
        of: find.ancestor(
          of: find.text('Order ID: MSZ-DEMO-1043'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.padding == const EdgeInsets.all(16),
          ),
        ),
        matching: find.text('View Details'),
      );
      await tester.ensureVisible(cancelledOrderDetailsButton);
      await tester.pumpAndSettle();
      await tester.tap(cancelledOrderDetailsButton);
      await tester.pumpAndSettle();
      expect(find.text('Cancel Order'), findsNothing);
      expect(find.text('Track Order'), findsNothing);
      expect(find.text('Changed my mind'), findsOneWidget);

      await tester.ensureVisible(find.text('View Receipt'));
      await tester.tap(find.text('View Receipt'));
      await tester.pumpAndSettle();
      expect(find.text('Order Status'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Cancellation Reason'), findsOneWidget);

      OrdersPage.updateDemoOrderTab('MSZ-DEMO-1043', OrdersTab.ongoing);
    },
  );
}

Future<void> _openCancellationDialog(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Cancel Order'));
  await tester.tap(find.text('Cancel Order'));
  await tester.pumpAndSettle();
  expect(find.text('Cancel order?'), findsOneWidget);
}

Widget _testHome(OrderRecord order) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => OrderDetailsPage(order: order),
            ),
          ),
          child: const Text('Open order'),
        ),
      ),
    ),
  );
}

OrderRecord _order(OrderTrackingStatus? trackingStatus, {OrdersTab? orderTab}) {
  final tab =
      orderTab ??
      (trackingStatus == OrderTrackingStatus.delivered
          ? OrdersTab.delivered
          : OrdersTab.ongoing);
  return OrderRecord(
    storeName: 'Cancellation Test Store',
    icon: Icons.storefront_outlined,
    orderId: 'MSZ-CANCEL-TEST',
    dateTime: 'Today',
    itemSummary: '1 item · Sample',
    totalInPaise: 1000,
    status: trackingStatus?.name ?? 'Cancelled',
    statusMessage: 'Demo order status',
    orderTab: tab,
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
    trackingStatus: trackingStatus,
  );
}
