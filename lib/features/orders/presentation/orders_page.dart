import 'package:flutter/material.dart';

import '../models/order_record.dart';
import 'order_details_page.dart';
import 'order_tracking_page.dart';

export '../models/order_record.dart' show OrdersTab;

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, this.initialTab = OrdersTab.ongoing});

  final OrdersTab initialTab;

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  static final List<OrderRecord> _demoOrders = [
    OrderRecord(
      storeName: 'Green Bowl Kitchen',
      icon: Icons.restaurant_outlined,
      orderId: 'MSZ-DEMO-1042',
      dateTime: 'Today, 7:20 PM',
      itemSummary: '2 items · Veggie Bowl, Fresh Lime Soda',
      totalInPaise: 34800,
      status: 'On the way',
      statusMessage: 'Your demo order is on its way',
      orderTab: OrdersTab.ongoing,
      serviceType: 'Restaurants',
      items: const [
        OrderLineItem(
          name: 'Veggie Bowl',
          description: 'Demo itemized price',
          quantity: 1,
          unitPriceInPaise: 25000,
          icon: Icons.restaurant_rounded,
        ),
        OrderLineItem(
          name: 'Fresh Lime Soda',
          description: 'Demo itemized price',
          quantity: 1,
          unitPriceInPaise: 6800,
          icon: Icons.local_drink_rounded,
        ),
      ],
      deliveryAddress: 'Home · 12 Green Park Road, Ravulapalem · demo address',
      paymentMethod: 'UPI',
      paymentStatus: 'Demo · not processed',
      deliveryChargeInPaise: 3000,
      discountInPaise: 0,
      trackingStatus: OrderTrackingStatus.onTheWay,
      deliveryOtp: '4821',
    ),
    OrderRecord(
      storeName: 'The Daily Bakery',
      icon: Icons.bakery_dining_outlined,
      orderId: 'MSZ-DEMO-0981',
      dateTime: 'Yesterday, 10:15 AM',
      itemSummary: '3 items · Sourdough, Croissant, Muffin',
      totalInPaise: 42500,
      status: 'Delivered',
      statusMessage: 'Demo order completed successfully',
      orderTab: OrdersTab.delivered,
      serviceType: 'Bakery',
      items: const [
        OrderLineItem(
          name: 'Sourdough',
          description: 'Demo itemized price',
          quantity: 1,
          unitPriceInPaise: 15000,
          icon: Icons.bakery_dining_rounded,
          productId: 'sourdough',
          serviceType: 'bakery',
          merchantId: 'sri-sai-bakery',
        ),
        OrderLineItem(
          name: 'Croissant',
          description: 'Demo itemized price',
          quantity: 1,
          unitPriceInPaise: 12000,
          icon: Icons.bakery_dining_rounded,
          productId: 'croissant',
          serviceType: 'bakery',
          merchantId: 'sri-sai-bakery',
        ),
        OrderLineItem(
          name: 'Muffin',
          description: 'Demo itemized price',
          quantity: 1,
          unitPriceInPaise: 12500,
          icon: Icons.bakery_dining_rounded,
          productId: 'muffin',
          serviceType: 'bakery',
          merchantId: 'sri-sai-bakery',
        ),
      ],
      deliveryAddress: 'Home · 12 Green Park Road, Ravulapalem · demo address',
      paymentMethod: 'UPI',
      paymentStatus: 'Demo · not processed',
      deliveryChargeInPaise: 3000,
      discountInPaise: 0,
      trackingStatus: OrderTrackingStatus.delivered,
    ),
    OrderRecord(
      storeName: 'Market Fresh Store',
      icon: Icons.storefront_outlined,
      orderId: 'MSZ-DEMO-0876',
      dateTime: '12 Sep 2026, 5:40 PM',
      itemSummary: '2 items · Apples, Bananas',
      totalInPaise: 21000,
      status: 'Cancelled',
      statusMessage: 'This demo order was cancelled',
      orderTab: OrdersTab.cancelled,
      serviceType: 'Local Store',
      items: const [
        OrderLineItem(
          name: 'Apples',
          description: 'Demo itemized price',
          quantity: 1,
          unitPriceInPaise: 10000,
          icon: Icons.apple_rounded,
        ),
        OrderLineItem(
          name: 'Bananas',
          description: 'Demo itemized price',
          quantity: 1,
          unitPriceInPaise: 8000,
          icon: Icons.eco_rounded,
        ),
      ],
      deliveryAddress: 'Home · 12 Green Park Road, Ravulapalem · demo address',
      paymentMethod: 'UPI',
      paymentStatus: 'Demo · not processed',
      deliveryChargeInPaise: 3000,
      discountInPaise: 0,
    ),
  ];

  static final ValueNotifier<int> ongoingOrderCount = ValueNotifier<int>(
    _countOrdersForTab(OrdersTab.ongoing),
  );

  static const _tabs = ['Ongoing', 'Delivered', 'Cancelled'];

  static int _countOrdersForTab(OrdersTab tab) =>
      _demoOrders.where((order) => order.orderTab == tab).length;

  static List<OrderRecord> _ordersForTab(OrdersTab tab) =>
      _demoOrders.where((order) => order.orderTab == tab).toList();

  static void updateDemoOrderTab(String orderId, OrdersTab tab) {
    final order = _demoOrders.firstWhere(
      (demoOrder) => demoOrder.orderId == orderId,
    );
    order.orderTab = tab;
    switch (tab) {
      case OrdersTab.ongoing:
        order.status = 'On the way';
        order.statusMessage = 'Your demo order is on its way';
        order.trackingStatus = OrderTrackingStatus.onTheWay;
      case OrdersTab.delivered:
        order.status = 'Delivered';
        order.statusMessage = 'Demo order completed successfully';
        order.trackingStatus = OrderTrackingStatus.delivered;
      case OrdersTab.cancelled:
        order.status = 'Cancelled';
        order.statusMessage = 'This demo order was cancelled';
        order.trackingStatus = null;
    }
    ongoingOrderCount.value = _countOrdersForTab(OrdersTab.ongoing);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _mainText,
          surfaceTintColor: _background,
          title: const Text(
            'My Orders',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          bottom: TabBar(
            labelColor: _green,
            unselectedLabelColor: _secondaryText,
            indicatorColor: _green,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [for (final tab in _tabs) Tab(text: tab)],
          ),
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: ongoingOrderCount,
          builder: (context, count, child) => TabBarView(
            children: [
              for (final tab in OrdersTab.values)
                _buildOrderList(context, _ordersForTab(tab)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, List<OrderRecord> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: _secondaryText,
                size: 48,
              ),
              SizedBox(height: 14),
              Text(
                'No orders yet',
                style: TextStyle(
                  color: _mainText,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Your orders will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondaryText, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _buildOrderCard(context, orders[index]),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderRecord order) {
    final isCancelled = order.status == 'Cancelled';
    final statusColor = isCancelled ? const Color(0xFFA85B5B) : _green;
    final statusBackground = isCancelled
        ? const Color(0xFFFFF2F1)
        : _lightGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(order.icon, color: _green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mainText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.dateTime,
                      style: const TextStyle(
                        color: _secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: order.status,
                foreground: statusColor,
                background: statusBackground,
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Text(
            'Order ID: ${order.orderId}',
            style: const TextStyle(color: _secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            order.itemSummary,
            style: const TextStyle(color: _mainText, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            order.statusMessage,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total  ${order.total}',
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => OrderDetailsPage(order: order),
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: _green),
                child: const Text(
                  'View Details',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
