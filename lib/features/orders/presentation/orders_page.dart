import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/presentation/motion.dart';
import '../../../shared/presentation/offline_error_state.dart';
import '../../../shared/presentation/press_scale_feedback.dart';
import '../models/order_record.dart';
import 'order_details_page.dart';
import 'order_tracking_page.dart';

export '../models/order_record.dart' show OrdersTab;

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, this.initialTab = OrdersTab.ongoing});

  final OrdersTab initialTab;

  static ValueNotifier<int> get ongoingOrderCount =>
      _OrdersPageState.ongoingOrderCount;

  static void updateDemoOrderTab(String orderId, OrdersTab tab) =>
      _OrdersPageState.updateDemoOrderTab(orderId, tab);

  static void refreshOrderCounts() => _OrdersPageState.refreshOrderCounts();

  static void addDemoOrder(OrderRecord order) =>
      _OrdersPageState.addDemoOrder(order);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = Color(0xFF59615C);
  static const _cancelledStatus = Color(0xFF914747);
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
      storeName: 'Sunrise Dairy & Grocery',
      icon: Icons.storefront_outlined,
      orderId: 'MSZ-DEMO-1043',
      dateTime: 'Today, 7:35 PM',
      itemSummary: '2 items · Milk, Brown Bread',
      totalInPaise: 17500,
      status: 'Order Placed',
      statusMessage: 'We have received your demo order',
      orderTab: OrdersTab.ongoing,
      serviceType: 'Local Store',
      items: const [
        OrderLineItem(
          name: 'Farm Fresh Milk',
          quantity: 1,
          unitPriceInPaise: 9000,
          icon: Icons.local_drink_rounded,
        ),
        OrderLineItem(
          name: 'Brown Bread',
          quantity: 1,
          unitPriceInPaise: 5500,
          icon: Icons.bakery_dining_rounded,
        ),
      ],
      deliveryAddress: 'Home · 12 Green Park Road, Ravulapalem · demo address',
      paymentMethod: 'UPI',
      paymentStatus: 'Demo · not processed',
      deliveryChargeInPaise: 3000,
      discountInPaise: 0,
      trackingStatus: OrderTrackingStatus.orderPlaced,
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

  List<OrderRecord> _backendOrders = [];
  bool _ordersLoading = false;
  String? _ordersError;
  bool _ordersOfflineError = false;

  bool get _backendMode => CustomerApi.instance.isConfigured;

  @override
  void initState() {
    super.initState();
    if (_backendMode) unawaited(_loadOrders());
  }

  Future<void> _loadOrders() async {
    setState(() {
      _ordersLoading = true;
      _ordersError = null;
      _ordersOfflineError = false;
    });
    try {
      final orders = await CustomerApi.instance.getOrders();
      if (mounted) {
        setState(() {
          _backendOrders = orders.map(_toOrderRecord).toList(growable: false);
        });
      }
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          _backendOrders = [];
          _ordersError = error.message;
          _ordersOfflineError = isOfflineApiError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _ordersLoading = false);
    }
  }

  OrderRecord _toOrderRecord(ApiCustomerOrder order) {
    final status = order.status.toLowerCase();
    final tab = switch (status) {
      'delivered' => OrdersTab.delivered,
      'cancelled' || 'rejected' || 'delivery_failed' => OrdersTab.cancelled,
      _ => OrdersTab.ongoing,
    };
    final trackingStatus = orderTrackingStatusFromApi(order.status);
    return OrderRecord(
      storeName: order.shopName,
      icon: Icons.storefront_outlined,
      orderId: order.id,
      dateTime: order.placedAt,
      itemSummary:
          '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
      totalInPaise: order.totalMinor,
      status: order.status,
      statusMessage: '',
      orderTab: tab,
      serviceType: '',
      items: const [],
      deliveryAddress: '',
      paymentMethod: '',
      paymentStatus: '',
      deliveryChargeInPaise: order.deliveryFeeMinor,
      discountInPaise: order.discountMinor,
      isBackendData: true,
      itemCount: order.itemCount,
      trackingStatus: trackingStatus,
      cancellationEligible: order.cancellationEligible,
      cancellationDeadlineAt: order.cancellationDeadlineAt,
      serverNow: order.serverNow,
    );
  }

  List<OrderRecord> _backendOrdersForTab(OrdersTab tab) =>
      _backendOrders.where((order) => order.orderTab == tab).toList();

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
        order.cancellationReason = null;
      case OrdersTab.delivered:
        order.status = 'Delivered';
        order.statusMessage = 'Demo order completed successfully';
        order.trackingStatus = OrderTrackingStatus.delivered;
        order.cancellationReason = null;
      case OrdersTab.cancelled:
        order.status = 'Cancelled';
        order.statusMessage = 'This demo order was cancelled';
        order.trackingStatus = null;
    }
    refreshOrderCounts();
  }

  static void refreshOrderCounts() {
    ongoingOrderCount.value = _countOrdersForTab(OrdersTab.ongoing);
  }

  static void addDemoOrder(OrderRecord order) {
    _demoOrders.insert(0, order);
    refreshOrderCounts();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: AppTheme.white,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'My Orders',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          bottom: TabBar(
            labelColor: AppTheme.brandYellow,
            unselectedLabelColor: AppTheme.white,
            indicatorColor: AppTheme.brandYellow,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              for (var index = 0; index < _tabs.length; index++)
                Tab(
                  text: _backendMode && index == OrdersTab.cancelled.index
                      ? 'Cancelled / Rejected'
                      : _tabs[index],
                ),
            ],
          ),
        ),
        body: _backendMode
            ? _buildBackendOrderBody(context)
            : ValueListenableBuilder<int>(
                valueListenable: ongoingOrderCount,
                builder: (context, count, child) => Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Text(
                          'Demo order history · sample data',
                          style: TextStyle(color: _secondaryText, fontSize: 11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final tab in OrdersTab.values)
                            _buildOrderList(context, _ordersForTab(tab)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBackendOrderBody(BuildContext context) {
    if (_ordersLoading) {
      return const AnimatedContentSwitcher(
        child: KeyedSubtree(
          key: ValueKey('orders-loading'),
          child: _OrdersSkeletonList(),
        ),
      );
    }
    if (_ordersError != null) {
      if (_ordersOfflineError) {
        return OfflineErrorState(onRetry: _loadOrders);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _ordersError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _secondaryText),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _ordersLoading ? null : _loadOrders,
                child: const Text('Retry orders'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Backend order history',
              style: TextStyle(color: _secondaryText, fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              for (final tab in OrdersTab.values)
                _buildOrderList(
                  context,
                  _backendOrdersForTab(tab),
                  onRefresh: _loadOrders,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    List<OrderRecord> orders, {
    Future<void> Function()? onRefresh,
  }) {
    if (orders.isEmpty) {
      final emptyState = const Center(
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
      if (onRefresh == null) return emptyState;
      return RefreshIndicator(
        color: const Color(0xFF016034),
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: emptyState,
            ),
          ],
        ),
      );
    }

    final orderList = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => fadeSlideItem(
        itemKey: 'order-${orders[index].orderId}',
        index: index,
        child: PressScaleFeedback(
          child: _buildOrderCard(context, orders[index]),
        ),
      ),
    );
    return onRefresh == null
        ? orderList
        : RefreshIndicator(
            color: const Color(0xFF016034),
            onRefresh: onRefresh,
            child: orderList,
          );
  }

  Widget _buildOrderCard(BuildContext context, OrderRecord order) {
    final isCancelled = order.status == 'Cancelled';
    final statusColor = isCancelled ? _cancelledStatus : _green;
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
          if (order.statusMessage.isNotEmpty)
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
                onPressed: () => _openOrderDetails(context, order),
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

  Future<void> _openOrderDetails(
    BuildContext context,
    OrderRecord order,
  ) async {
    if (order.isBackendData) {
      final cancelled = await Navigator.of(context).push<bool>(
        AppPageRoute<bool>.builder(
          builder: (context) => BackendOrderDetailsPage(order: order),
        ),
      );
      if (cancelled == true && context.mounted) {
        await _loadOrders();
        if (context.mounted) {
          DefaultTabController.of(context).animateTo(OrdersTab.cancelled.index);
        }
      }
      return;
    }
    final cancelled = await Navigator.of(context).push<bool>(
      AppPageRoute<bool>.builder(
        builder: (context) => OrderDetailsPage(order: order),
      ),
    );
    if (cancelled != true || !context.mounted) return;
    refreshOrderCounts();
    DefaultTabController.of(context).animateTo(OrdersTab.cancelled.index);
  }
}

class _OrdersSkeletonList extends StatelessWidget {
  const _OrdersSkeletonList();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
    children: [
      for (var index = 0; index < 3; index++) ...[
        const SkeletonBox(height: 180, radius: 20),
        const SizedBox(height: 14),
      ],
    ],
  );
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
