import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/orders/data/demo_refund_store.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/models/refund_record.dart';
import 'package:myshopzy/features/orders/presentation/order_details_page.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';

void main() {
  setUp(DemoRefundStore.clear);

  testWidgets('cancelled UPI order shows local refund information', (
    tester,
  ) async {
    final order = _order('REFUND-UPI-1', paymentMethod: 'UPI');
    await tester.pumpWidget(_details(order));

    expect(find.text('Refund Status'), findsOneWidget);
    expect(find.text('₹25'), findsWidgets);
    expect(find.text('Refund ID · demo'), findsOneWidget);
    expect(find.text('DEMO-REF-REFUND-UPI-1'), findsOneWidget);
    expect(find.text('Refund Processing'), findsWidgets);
    expect(
      find.text(
        'Local demo status only. This does not confirm that a real refund was processed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelled card order shows its payment method', (tester) async {
    final order = _order('REFUND-CARD-1', paymentMethod: 'Card');
    await tester.pumpWidget(_details(order));

    expect(find.text('Payment method'), findsWidgets);
    expect(find.text('Card'), findsWidgets);
    expect(find.text('DEMO-REF-REFUND-CARD-1'), findsOneWidget);
  });

  testWidgets('cancelled COD order explains that no refund is required', (
    tester,
  ) async {
    await tester.pumpWidget(
      _details(_order('REFUND-COD-1', paymentMethod: 'Cash on Delivery')),
    );

    expect(find.text('Refund Status'), findsOneWidget);
    expect(find.text('No refund required'), findsOneWidget);
    expect(find.text('Payment was not collected online.'), findsOneWidget);
    expect(find.text('Refund ID · demo'), findsNothing);
  });

  testWidgets('each demo refund status renders its corresponding timeline', (
    tester,
  ) async {
    const cases = {
      DemoRefundStatus.refundInitiated: 'Refund Initiated',
      DemoRefundStatus.refundProcessing: 'Refund Processing',
      DemoRefundStatus.refundCompleted: 'Refund Completed',
      DemoRefundStatus.refundFailed: 'Refund Failed',
    };

    for (final entry in cases.entries) {
      final order = _order('REFUND-STATUS-${entry.key.name}');
      DemoRefundStore.saveDemoRecord(_refund(order.orderId, status: entry.key));
      await tester.pumpWidget(_details(order));
      expect(find.text(entry.value), findsWidgets);
      expect(find.text('Cancelled Order'), findsOneWidget);
      expect(find.text('Refund Initiated'), findsWidgets);
      if (entry.key == DemoRefundStatus.refundFailed) {
        expect(
          find.text('This is a local demo status. No refund was completed.'),
          findsOneWidget,
        );
        expect(find.text('Refund Completed'), findsNothing);
      }
    }
  });

  test('demo refund records are isolated by orderId', () {
    final first = _refund('ORDER-ONE');
    final second = _refund('ORDER-TWO');
    DemoRefundStore.saveDemoRecord(first);
    DemoRefundStore.saveDemoRecord(second);

    expect(DemoRefundStore.refundForOrderId('ORDER-ONE'), same(first));
    expect(DemoRefundStore.refundForOrderId('ORDER-TWO'), same(second));
    expect(DemoRefundStore.refundForOrderId('ORDER-THREE'), isNull);
  });

  testWidgets('non-cancelled online order does not show refund status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _details(
        _order(
          'REFUND-NOT-CANCELLED',
          orderTab: OrdersTab.ongoing,
          trackingStatus: OrderTrackingStatus.orderPlaced,
        ),
      ),
    );

    expect(find.text('Refund Status'), findsNothing);
    expect(find.text('No refund required'), findsNothing);
  });

  test('cancellation registers refund only for online payment', () {
    final onlineOrder = _order(
      'CANCEL-UPI',
      paymentMethod: 'UPI',
      orderTab: OrdersTab.ongoing,
      trackingStatus: OrderTrackingStatus.preparing,
    );
    expect(onlineOrder.cancelByCustomer('Changed my mind'), isTrue);
    DemoRefundStore.recordCancellation(onlineOrder);
    expect(DemoRefundStore.refundForOrderId('CANCEL-UPI'), isNotNull);

    final codOrder = _order(
      'CANCEL-COD',
      paymentMethod: 'COD',
      orderTab: OrdersTab.ongoing,
      trackingStatus: OrderTrackingStatus.preparing,
    );
    expect(codOrder.cancelByCustomer('Ordered by mistake'), isTrue);
    DemoRefundStore.recordCancellation(codOrder);
    expect(DemoRefundStore.refundForOrderId('CANCEL-COD'), isNull);
  });
}

Widget _details(OrderRecord order) =>
    MaterialApp(home: OrderDetailsPage(order: order));

DemoRefundRecord _refund(
  String orderId, {
  DemoRefundStatus status = DemoRefundStatus.refundProcessing,
}) {
  return DemoRefundRecord(
    orderId: orderId,
    refundId: 'DEMO-REF-$orderId',
    refundAmountInPaise: 2500,
    paymentMethod: 'UPI',
    status: status,
    initiatedAt: 'Today',
    expectedDate: '5–7 business days',
    failureReason: status == DemoRefundStatus.refundFailed
        ? 'This is a local demo status. No refund was completed.'
        : null,
  );
}

OrderRecord _order(
  String orderId, {
  String paymentMethod = 'UPI',
  OrdersTab orderTab = OrdersTab.cancelled,
  OrderTrackingStatus? trackingStatus,
}) {
  return OrderRecord(
    storeName: 'Refund Test Store',
    icon: Icons.storefront_outlined,
    orderId: orderId,
    dateTime: 'Today',
    itemSummary: '1 item · Sample',
    totalInPaise: 2500,
    status: orderTab == OrdersTab.cancelled ? 'Cancelled' : 'Order Placed',
    statusMessage: 'Demo order status',
    orderTab: orderTab,
    serviceType: 'Local Store',
    items: const [
      OrderLineItem(
        name: 'Sample',
        quantity: 1,
        unitPriceInPaise: 2500,
        icon: Icons.shopping_bag_outlined,
      ),
    ],
    deliveryAddress: 'Home · Demo Address',
    paymentMethod: paymentMethod,
    paymentStatus: 'Demo · not processed',
    deliveryChargeInPaise: 0,
    discountInPaise: 0,
    trackingStatus: trackingStatus,
  );
}
