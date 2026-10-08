import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';
import 'package:myshopzy/features/orders/models/order_record.dart';
import 'package:myshopzy/features/orders/presentation/order_details_page.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';
import 'package:myshopzy/features/orders/presentation/orders_page.dart';
import 'package:myshopzy/features/product_details/data/product_availability_store.dart';
import 'package:myshopzy/features/reviews/presentation/write_review_page.dart';

void main() {
  testWidgets('renders order ID, item quantities, and calculated totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _testOrder())),
    );

    expect(find.text('MSZ-TEST-1001'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('2 × ₹3'), findsOneWidget);
    expect(find.text('₹6'), findsNWidgets(2));
    expect(find.text('Item total'), findsOneWidget);
    expect(find.text('Grand total'), findsOneWidget);
    expect(find.text('₹9'), findsOneWidget);
  });

  testWidgets('ongoing order opens existing tracking page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _testOrder())),
    );

    await tester.ensureVisible(find.text('Track Order'));
    await tester.tap(find.text('Track Order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderTrackingPage), findsOneWidget);
    expect(find.text('MSZ-TEST-1001'), findsOneWidget);
  });

  testWidgets('receipt shows order information and download demo feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _testOrder())),
    );

    await tester.ensureVisible(find.text('View Receipt'));
    await tester.tap(find.text('View Receipt'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderReceiptPage), findsOneWidget);
    expect(find.text('MYSHOPZY'), findsOneWidget);
    expect(find.text('MSZ-TEST-1001'), findsOneWidget);
    expect(find.text('Apple × 2'), findsOneWidget);
    expect(find.text('Home · Demo Address'), findsOneWidget);

    await tester.tap(find.text('Download Receipt'));
    await tester.pump();
    expect(
      find.text(
        'Receipt download will be available in the production version.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('order details navigation does not modify CartStore', (
    tester,
  ) async {
    final order = _testOrder();
    final cart = CartStore.instance;
    final beforeTotal = cart.totalQuantity;
    final beforeQuantity = cart.quantityFor(
      productId: 'order-detail-only',
      serviceType: 'restaurant',
      merchantId: 'demo-merchant',
    );

    await tester.pumpWidget(MaterialApp(home: OrderDetailsPage(order: order)));

    expect(cart.totalQuantity, beforeTotal);
    expect(
      cart.quantityFor(
        productId: 'order-detail-only',
        serviceType: 'restaurant',
        merchantId: 'demo-merchant',
      ),
      beforeQuantity,
    );
  });

  testWidgets('OrdersPage View Details opens OrderDetailsPage', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsPage), findsOneWidget);
    expect(find.text('MSZ-DEMO-1042'), findsOneWidget);
    expect(find.text('On the way'), findsWidgets);
  });

  testWidgets('delivered and cancelled orders do not offer tracking', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

    await tester.tap(find.text('Delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsWidgets);
    expect(find.text('Track Order'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Track Order'), findsNothing);
  });

  testWidgets('delivered orders can review an item; cancelled orders cannot', (
    tester,
  ) async {
    final deliveredOrder = _testOrder()..orderTab = OrdersTab.delivered;
    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: deliveredOrder)),
    );

    expect(find.text('Review products'), findsOneWidget);
    await tester.ensureVisible(find.text('Review products'));
    await tester.tap(find.text('Review products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple').last);
    await tester.pumpAndSettle();
    expect(find.byType(WriteReviewPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final cancelledOrder = _testOrder()..orderTab = OrdersTab.cancelled;
    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: cancelledOrder)),
    );
    expect(find.text('Review products'), findsNothing);
    expect(find.text('Buy Again'), findsNothing);
  });

  testWidgets('Buy Again reuses cart lines and restores order quantities', (
    tester,
  ) async {
    final cart = CartStore.instance;
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();
    cart.addItem(
      productId: 'reorder-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
      name: 'Bread',
      description: 'Fresh loaf',
      priceInPaise: 5000,
      icon: Icons.bakery_dining_rounded,
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _deliveredOrder())),
    );
    await tester.ensureVisible(find.text('Buy Again'));
    await tester.tap(find.text('Buy Again'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsOneWidget);
    expect(cart.items, hasLength(1));
    expect(
      cart.quantityFor(
        productId: 'reorder-bread',
        serviceType: 'bakery',
        merchantId: 'demo-bakery',
      ),
      3,
    );
    expect(find.text('2 items added to your cart.'), findsOneWidget);
    cart.clear();
  });

  testWidgets('Buy Again skips unavailable products and explains why', (
    tester,
  ) async {
    final cart = CartStore.instance;
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();
    ProductAvailabilityStore.instance.setAvailability(
      productId: 'unavailable-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
      isAvailable: false,
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _partiallyUnavailableOrder())),
    );
    await tester.ensureVisible(find.text('Buy Again'));
    await tester.tap(find.text('Buy Again'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsOneWidget);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.name, 'Available Bread');
    expect(
      find.text('1 item added to your cart. Out of stock: Unavailable Bread.'),
      findsOneWidget,
    );
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();
  });

  testWidgets('Buy Again blocks a cart containing another merchant', (
    tester,
  ) async {
    final cart = CartStore.instance;
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();
    cart.addItem(
      productId: 'other-store-item',
      serviceType: 'bakery',
      merchantId: 'another-bakery',
      name: 'Other item',
      description: '',
      priceInPaise: 1000,
      icon: Icons.bakery_dining_rounded,
    );
    expect(
      cart.canAddItem(serviceType: 'bakery', merchantId: 'demo-bakery'),
      isFalse,
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _deliveredOrder())),
    );
    await tester.ensureVisible(find.text('Buy Again'));
    await tester.tap(find.text('Buy Again'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsNothing);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.productId, 'other-store-item');
    expect(
      find.text(
        'You can only order from one bakery at a time.',
      ),
      findsOneWidget,
    );
    cart.clear();
  });

  testWidgets('Buy Again stays on order details when nothing is available', (
    tester,
  ) async {
    final cart = CartStore.instance;
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();
    ProductAvailabilityStore.instance.setAvailability(
      productId: 'unavailable-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
      isAvailable: false,
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _unavailableOrder())),
    );
    await tester.ensureVisible(find.text('Buy Again'));
    await tester.tap(find.text('Buy Again'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsNothing);
    expect(cart.items, isEmpty);
    expect(find.text('Out of stock: Unavailable Bread.'), findsOneWidget);
    ProductAvailabilityStore.instance.clearOverrides();
  });

  testWidgets('Buy Again skips order lines from a different merchant', (
    tester,
  ) async {
    final cart = CartStore.instance;
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _mixedMerchantOrder())),
    );
    await tester.ensureVisible(find.text('Buy Again'));
    await tester.tap(find.text('Buy Again'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsOneWidget);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.name, 'Demo Bakery Bread');
    expect(
      find.text(
        '1 item added to your cart. Not added from another store: Other Store Bread.',
      ),
      findsOneWidget,
    );
    cart.clear();
  });

  testWidgets('Buy Again restores the recorded product variant', (
    tester,
  ) async {
    final cart = CartStore.instance;
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _variantDeliveredOrder())),
    );
    await tester.ensureVisible(find.text('Buy Again'));
    await tester.tap(find.text('Buy Again'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsOneWidget);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.productVariantId, '5-kg');
    expect(cart.items.single.variantLabel, '5 KG');
    expect(cart.items.single.priceInPaise, 31000);
    expect(
      cart.quantityFor(
        productId: 'slgs-ashirvad-atta',
        serviceType: 'local_store',
        merchantId: 'sri-lakshmi-general-store',
        productVariantId: '5-kg',
      ),
      1,
    );
    cart.clear();
  });

  testWidgets('Buy Again does not replace an unavailable recorded size', (
    tester,
  ) async {
    final cart = CartStore.instance;
    cart.clear();
    ProductAvailabilityStore.instance.clearOverrides();
    ProductAvailabilityStore.instance.setAvailability(
      productId: 'slgs-ashirvad-atta',
      serviceType: 'local_store',
      merchantId: 'sri-lakshmi-general-store',
      variantId: '5-kg',
      isAvailable: false,
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderDetailsPage(order: _variantDeliveredOrder())),
    );
    await tester.ensureVisible(find.text('Buy Again'));
    await tester.tap(find.text('Buy Again'));
    await tester.pumpAndSettle();

    expect(find.byType(CartPage), findsNothing);
    expect(cart.items, isEmpty);
    expect(find.text('Out of stock: Ashirvad Atta.'), findsOneWidget);
    ProductAvailabilityStore.instance.clearOverrides();
  });
}

OrderRecord _testOrder() => OrderRecord(
  storeName: 'Demo Merchant',
  icon: Icons.storefront_outlined,
  orderId: 'MSZ-TEST-1001',
  dateTime: 'Today, 1:00 PM',
  itemSummary: '2 items · Apples',
  totalInPaise: 900,
  status: 'On the way',
  statusMessage: 'Your order is on its way',
  orderTab: OrdersTab.ongoing,
  serviceType: 'Restaurants',
  items: [
    OrderLineItem(
      name: 'Apple',
      quantity: 2,
      unitPriceInPaise: 300,
      icon: Icons.apple_rounded,
    ),
  ],
  deliveryAddress: 'Home · Demo Address',
  paymentMethod: 'UPI',
  paymentStatus: 'Demo · not processed',
  deliveryChargeInPaise: 300,
  discountInPaise: 0,
  trackingStatus: OrderTrackingStatus.onTheWay,
  deliveryOtp: '4821',
);

OrderRecord _deliveredOrder() => OrderRecord(
  storeName: 'Demo Bakery',
  icon: Icons.bakery_dining_outlined,
  orderId: 'MSZ-TEST-DELIVERED',
  dateTime: 'Yesterday',
  itemSummary: '2 items · Bread',
  totalInPaise: 10000,
  status: 'Delivered',
  statusMessage: 'Demo order completed successfully',
  orderTab: OrdersTab.delivered,
  serviceType: 'Bakery',
  items: const [
    OrderLineItem(
      name: 'Bread',
      quantity: 2,
      unitPriceInPaise: 5000,
      icon: Icons.bakery_dining_rounded,
      description: 'Fresh loaf',
      productId: 'reorder-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
    ),
  ],
  deliveryAddress: 'Home · Demo Address',
  paymentMethod: 'UPI',
  paymentStatus: 'Demo · not processed',
  deliveryChargeInPaise: 0,
  discountInPaise: 0,
);

OrderRecord _partiallyUnavailableOrder() => OrderRecord(
  storeName: 'Demo Bakery',
  icon: Icons.bakery_dining_outlined,
  orderId: 'MSZ-TEST-PARTIAL',
  dateTime: 'Yesterday',
  itemSummary: '2 items · Bread',
  totalInPaise: 10000,
  status: 'Delivered',
  statusMessage: 'Demo order completed successfully',
  orderTab: OrdersTab.delivered,
  serviceType: 'Bakery',
  items: const [
    OrderLineItem(
      name: 'Unavailable Bread',
      quantity: 1,
      unitPriceInPaise: 5000,
      icon: Icons.bakery_dining_rounded,
      productId: 'unavailable-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
    ),
    OrderLineItem(
      name: 'Available Bread',
      quantity: 1,
      unitPriceInPaise: 5000,
      icon: Icons.bakery_dining_rounded,
      productId: 'available-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
    ),
  ],
  deliveryAddress: 'Home · Demo Address',
  paymentMethod: 'UPI',
  paymentStatus: 'Demo · not processed',
  deliveryChargeInPaise: 0,
  discountInPaise: 0,
);

OrderRecord _unavailableOrder() => OrderRecord(
  storeName: 'Demo Bakery',
  icon: Icons.bakery_dining_outlined,
  orderId: 'MSZ-TEST-UNAVAILABLE',
  dateTime: 'Yesterday',
  itemSummary: '1 item · Bread',
  totalInPaise: 5000,
  status: 'Delivered',
  statusMessage: 'Demo order completed successfully',
  orderTab: OrdersTab.delivered,
  serviceType: 'Bakery',
  items: const [
    OrderLineItem(
      name: 'Unavailable Bread',
      quantity: 1,
      unitPriceInPaise: 5000,
      icon: Icons.bakery_dining_rounded,
      productId: 'unavailable-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
    ),
  ],
  deliveryAddress: 'Home · Demo Address',
  paymentMethod: 'UPI',
  paymentStatus: 'Demo · not processed',
  deliveryChargeInPaise: 0,
  discountInPaise: 0,
);

OrderRecord _mixedMerchantOrder() => OrderRecord(
  storeName: 'Demo Bakery',
  icon: Icons.bakery_dining_outlined,
  orderId: 'MSZ-TEST-MIXED',
  dateTime: 'Yesterday',
  itemSummary: '2 items · Bread',
  totalInPaise: 10000,
  status: 'Delivered',
  statusMessage: 'Demo order completed successfully',
  orderTab: OrdersTab.delivered,
  serviceType: 'Bakery',
  items: const [
    OrderLineItem(
      name: 'Demo Bakery Bread',
      quantity: 1,
      unitPriceInPaise: 5000,
      icon: Icons.bakery_dining_rounded,
      productId: 'demo-bakery-bread',
      serviceType: 'bakery',
      merchantId: 'demo-bakery',
    ),
    OrderLineItem(
      name: 'Other Store Bread',
      quantity: 1,
      unitPriceInPaise: 5000,
      icon: Icons.bakery_dining_rounded,
      productId: 'other-store-bread',
      serviceType: 'bakery',
      merchantId: 'another-bakery',
    ),
  ],
  deliveryAddress: 'Home · Demo Address',
  paymentMethod: 'UPI',
  paymentStatus: 'Demo · not processed',
  deliveryChargeInPaise: 0,
  discountInPaise: 0,
);

OrderRecord _variantDeliveredOrder() => OrderRecord(
  storeName: 'Sri Lakshmi General Store',
  icon: Icons.storefront_outlined,
  orderId: 'MSZ-TEST-VARIANT',
  dateTime: 'Yesterday',
  itemSummary: '1 item · Ashirvad Atta',
  totalInPaise: 31000,
  status: 'Delivered',
  statusMessage: 'Demo order completed successfully',
  orderTab: OrdersTab.delivered,
  serviceType: 'Local Store',
  items: const [
    OrderLineItem(
      name: 'Ashirvad Atta',
      quantity: 1,
      unitPriceInPaise: 31000,
      icon: Icons.inventory_2_rounded,
      productId: 'slgs-ashirvad-atta',
      serviceType: 'local_store',
      merchantId: 'sri-lakshmi-general-store',
      productVariantId: '5-kg',
      variantLabel: '5 KG',
    ),
  ],
  deliveryAddress: 'Home · Demo Address',
  paymentMethod: 'UPI',
  paymentStatus: 'Demo · not processed',
  deliveryChargeInPaise: 0,
  discountInPaise: 0,
);
