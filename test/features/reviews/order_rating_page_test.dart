import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';
import 'package:myshopzy/features/reviews/presentation/order_rating_page.dart';

void main() {
  testWidgets('delivery and purchased-product star ratings can be selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OrderRatingPage(order: _order())),
    );

    await tester.tap(find.byKey(const ValueKey('delivery-rating-star-4')));
    await tester.tap(find.byKey(const ValueKey('product-0-rating-star-3')));
    await tester.pump();

    final deliveryStar = tester.widget<IconButton>(
      find.byKey(const ValueKey('delivery-rating-star-4')),
    );
    final productStar = tester.widget<IconButton>(
      find.byKey(const ValueKey('product-0-rating-star-3')),
    );
    expect((deliveryStar.icon as Icon).color, const Color(0xFFFFD51E));
    expect((productStar.icon as Icon).color, const Color(0xFFFFD51E));
  });

  testWidgets('delivery score is validated and comments remain optional', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OrderRatingPage(order: _order())),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('order-rating-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('order-rating-submit')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('order-rating-validation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('order-rating-not-saved')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('delivery-rating-star-5')));
    await tester.tap(find.byKey(const ValueKey('order-rating-submit')));
    await tester.pump();

    expect(find.byKey(const ValueKey('order-rating-validation')), findsNothing);
    expect(
      find.byKey(const ValueKey('order-rating-not-saved')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('order-rating-comment')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('Rating submitted'), findsNothing);
  });

  testWidgets('non-delivered orders cannot open the rating form', (
    tester,
  ) async {
    final order = _order()..orderTab = OrdersTab.ongoing;
    await tester.pumpWidget(MaterialApp(home: OrderRatingPage(order: order)));

    expect(
      find.text('Ratings are available after an order is delivered.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('order-rating-submit')), findsNothing);
  });
}

OrderRecord _order() => OrderRecord(
  storeName: 'Existing Store',
  icon: Icons.storefront_outlined,
  orderId: 'MSZ-EXISTING-ORDER',
  dateTime: 'Today',
  itemSummary: '1 item · Existing product',
  totalInPaise: 10000,
  status: 'Delivered',
  statusMessage: 'Existing order delivered',
  orderTab: OrdersTab.delivered,
  serviceType: 'Local Store',
  items: const [
    OrderLineItem(
      name: 'Existing purchased product',
      quantity: 1,
      unitPriceInPaise: 10000,
      icon: Icons.shopping_bag_outlined,
      productId: 'existing-product-id',
      serviceType: 'local_store',
      merchantId: 'existing-store-id',
    ),
  ],
  deliveryAddress: 'Saved address',
  paymentMethod: 'Cash on Delivery',
  paymentStatus: 'Paid',
  deliveryChargeInPaise: 0,
  discountInPaise: 0,
  trackingStatus: OrderTrackingStatus.delivered,
);
