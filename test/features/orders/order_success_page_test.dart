import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/presentation/order_details_page.dart';
import 'package:myshopzy/features/orders/presentation/order_success_page.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  test('order API only marks an explicit verified successful payment', () {
    final baseOrder = {
      'orderId': 'ORDER-123',
      'status': 'placed',
      'currency': 'INR',
      'itemSubtotalMinor': 7000,
      'deliveryFeeMinor': 3000,
      'discountMinor': 0,
      'totalMinor': 10000,
      'items': 1,
    };

    expect(ApiOrderResult.fromJson(baseOrder).paymentVerified, isFalse);
    expect(
      ApiOrderResult.fromJson({
        ...baseOrder,
        'paymentStatus': 'pending',
        'paymentVerified': true,
      }).paymentVerified,
      isFalse,
    );
    expect(
      ApiOrderResult.fromJson({
        ...baseOrder,
        'paymentStatus': 'paid',
        'paymentVerified': true,
      }).paymentVerified,
      isTrue,
    );
  });

  test('verified success sound requires a verified backend payment', () {
    expect(_confirmedOrder().isVerifiedSuccessfulPayment, isFalse);
    expect(
      _confirmedOrder(paymentStatus: 'Paid').isVerifiedSuccessfulPayment,
      isFalse,
    );
    expect(
      _confirmedOrder(
        paymentStatus: 'Paid',
        paymentVerified: true,
      ).isVerifiedSuccessfulPayment,
      isFalse,
    );
    expect(
      _confirmedOrder(
        paymentStatus: 'Paid',
        paymentVerified: true,
        isBackendData: true,
      ).isVerifiedSuccessfulPayment,
      isTrue,
    );
    expect(
      _confirmedOrder(
        status: 'Cancelled',
        paymentStatus: 'Paid',
        paymentVerified: true,
        isBackendData: true,
      ).isVerifiedSuccessfulPayment,
      isFalse,
    );
  });

  testWidgets('success screen uses the confirmed record and opens details', (
    tester,
  ) async {
    final order = _confirmedOrder();
    await tester.pumpWidget(
      MaterialApp(home: OrderSuccessPage(confirmedOrder: order)),
    );

    expect(find.byKey(const ValueKey('order-success-mark')), findsOneWidget);
    expect(find.text('Order placed for'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
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

OrderRecord _confirmedOrder({
  String status = 'Order Placed',
  String paymentStatus = 'Pending',
  bool paymentVerified = false,
  bool isBackendData = false,
}) => OrderRecord(
  storeName: 'Demo Store',
  icon: Icons.storefront_outlined,
  orderId: 'ORDER-123',
  dateTime: 'Today',
  itemSummary: '1 item · Demo item',
  totalInPaise: 10000,
  status: status,
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
  paymentStatus: paymentStatus,
  paymentVerified: paymentVerified,
  deliveryChargeInPaise: 3000,
  discountInPaise: 0,
  trackingStatus: OrderTrackingStatus.orderPlaced,
  isBackendData: isBackendData,
);
