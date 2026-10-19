import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/presentation/offline_error_state.dart';
import 'live_order_map.dart';

enum OrderTrackingStatus {
  orderPlaced,
  orderConfirmed,
  preparing,
  packed,
  findingDeliveryPartner,
  riderAssigned,
  pickedUp,
  onTheWay,
  arriving,
  delivered,
}

class OrderTrackingData {
  const OrderTrackingData({
    required this.orderId,
    required this.storeName,
    required this.items,
    required this.total,
    this.status = OrderTrackingStatus.onTheWay,
    this.deliveryAddressLabel = 'Home',
    this.deliveryAddress = 'Address not provided',
    this.itemNames = const [],
    this.partnerName,
    this.etaMinutes,
    this.isDemo = true,
  });

  final String orderId;
  final String storeName;
  final String items;
  final String total;
  final OrderTrackingStatus status;
  final String deliveryAddressLabel;
  final String deliveryAddress;
  final List<String> itemNames;
  final String? partnerName;
  final int? etaMinutes;
  final bool isDemo;

  OrderTrackingData copyWith({
    String? storeName,
    String? items,
    String? total,
    OrderTrackingStatus? status,
    String? deliveryAddressLabel,
    String? deliveryAddress,
    List<String>? itemNames,
    String? partnerName,
  }) {
    return OrderTrackingData(
      orderId: orderId,
      storeName: storeName ?? this.storeName,
      items: items ?? this.items,
      total: total ?? this.total,
      status: status ?? this.status,
      deliveryAddressLabel: deliveryAddressLabel ?? this.deliveryAddressLabel,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      itemNames: itemNames ?? this.itemNames,
      partnerName: partnerName ?? this.partnerName,
      etaMinutes: etaMinutes,
      isDemo: isDemo,
    );
  }
}

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({
    required this.order,
    this.riderLocationStream,
    this.initialRiderLocation,
    this.initialCustomerLocation,
    super.key,
  });

  final OrderTrackingData order;
  final Stream<LatLng>? riderLocationStream;
  final LatLng? initialRiderLocation;
  final LatLng? initialCustomerLocation;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = Color(0xFF59615C);

  static const _timelineStatuses = [
    OrderTrackingStatus.orderPlaced,
    OrderTrackingStatus.orderConfirmed,
    OrderTrackingStatus.preparing,
    OrderTrackingStatus.packed,
    OrderTrackingStatus.findingDeliveryPartner,
    OrderTrackingStatus.riderAssigned,
    OrderTrackingStatus.pickedUp,
    OrderTrackingStatus.onTheWay,
    OrderTrackingStatus.arriving,
    OrderTrackingStatus.delivered,
  ];

  static const _timelineLabels = [
    'Order placed',
    'Order confirmed',
    'Preparing',
    'Packed',
    'Finding delivery partner',
    'Rider assigned',
    'Picked up',
    'On the way',
    'Arriving',
    'Delivered',
  ];

  late OrderTrackingData order;
  Timer? _refreshTimer;
  bool _refreshing = false;
  String? _refreshError;
  bool _refreshOfflineError = false;

  @override
  void initState() {
    super.initState();
    order = widget.order;
    if (!order.isDemo) {
      unawaited(_refreshStatus());
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_refreshStatus()),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_refreshing || !mounted) return;
    setState(() {
      _refreshing = true;
      _refreshError = null;
      _refreshOfflineError = false;
    });
    try {
      final detail = await CustomerApi.instance.getOrderDetails(order.orderId);
      if (!mounted) return;
      final address = detail.deliveryAddressSnapshot;
      final formattedAddress =
          address['formattedAddress'] ?? address['address'];
      final label = address['label'];
      setState(() {
        order = order.copyWith(
          storeName: detail.shopName,
          total: '₹${(detail.totalMinor / 100).toStringAsFixed(0)}',
          items:
              '${detail.items.length} '
              '${detail.items.length == 1 ? 'item' : 'items'}',
          itemNames: detail.items
              .map((item) => '${item.name} × ${item.quantity}')
              .toList(growable: false),
          deliveryAddress: formattedAddress is String
              ? formattedAddress
              : order.deliveryAddress,
          deliveryAddressLabel: label is String
              ? label
              : order.deliveryAddressLabel,
          status: _statusFromApi(detail.status) ?? order.status,
        );
      });
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          _refreshError = error.message;
          _refreshOfflineError = isOfflineApiError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  OrderTrackingStatus? _statusFromApi(String status) {
    return switch (status.toLowerCase().replaceAll(' ', '_')) {
      'placed' || 'order_placed' => OrderTrackingStatus.orderPlaced,
      'confirmed' || 'order_confirmed' => OrderTrackingStatus.orderConfirmed,
      'preparing' => OrderTrackingStatus.preparing,
      'packed' => OrderTrackingStatus.packed,
      'finding_delivery_partner' => OrderTrackingStatus.findingDeliveryPartner,
      'rider_assigned' => OrderTrackingStatus.riderAssigned,
      'picked_up' => OrderTrackingStatus.pickedUp,
      'on_the_way' || 'out_for_delivery' => OrderTrackingStatus.onTheWay,
      'arriving' => OrderTrackingStatus.arriving,
      'delivered' => OrderTrackingStatus.delivered,
      _ => null,
    };
  }

  String get _statusTitle => switch (order.status) {
    OrderTrackingStatus.orderPlaced ||
    OrderTrackingStatus.orderConfirmed ||
    OrderTrackingStatus.preparing ||
    OrderTrackingStatus.packed => 'Order getting packed!',
    OrderTrackingStatus.findingDeliveryPartner => 'Finding Delivery Partner',
    OrderTrackingStatus.riderAssigned ||
    OrderTrackingStatus.pickedUp ||
    OrderTrackingStatus.onTheWay ||
    OrderTrackingStatus.arriving => 'Out for delivery',
    OrderTrackingStatus.delivered => 'Delivered',
  };

  String get _statusMessage => switch (order.status) {
    OrderTrackingStatus.orderPlaced => 'We have received your order',
    OrderTrackingStatus.orderConfirmed => 'The store has confirmed your order',
    OrderTrackingStatus.preparing => 'The store is preparing your order',
    OrderTrackingStatus.packed => 'Your order has been packed',
    OrderTrackingStatus.findingDeliveryPartner =>
      'We are finding a delivery partner',
    OrderTrackingStatus.riderAssigned => 'A delivery partner has been assigned',
    OrderTrackingStatus.pickedUp => 'Your order has been picked up',
    OrderTrackingStatus.onTheWay => 'Your delivery partner is on the way',
    OrderTrackingStatus.arriving => 'Your delivery partner is arriving',
    OrderTrackingStatus.delivered => 'Your order has been delivered',
  };

  bool get _isDelivered => order.status == OrderTrackingStatus.delivered;
  bool get _isOutForDelivery => switch (order.status) {
    OrderTrackingStatus.riderAssigned ||
    OrderTrackingStatus.pickedUp ||
    OrderTrackingStatus.onTheWay ||
    OrderTrackingStatus.arriving => true,
    _ => false,
  };

  int get _etaMinutes => order.etaMinutes ?? (_isOutForDelivery ? 3 : 10);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!order.isDemo)
            IconButton(
              tooltip: 'Refresh tracking',
              onPressed: _refreshing ? null : _refreshStatus,
              icon: _refreshing
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        color: AppTheme.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(),
              if (_refreshError != null && _refreshOfflineError) ...[
                OfflineErrorState(onRetry: _refreshStatus, compact: true),
              ] else if (_refreshError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _refreshError!,
                        style: const TextStyle(
                          color: Color(0xFFA85B5B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _refreshing ? null : _refreshStatus,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _buildEtaCard(),
              const SizedBox(height: 16),
              LiveOrderMap(
                riderLocationStream: widget.riderLocationStream,
                initialRiderLocation: widget.initialRiderLocation,
                initialCustomerLocation: widget.initialCustomerLocation,
              ),
              const SizedBox(height: 16),
              _buildPartnerCard(context),
              const SizedBox(height: 16),
              _buildTimeline(),
              const SizedBox(height: 16),
              _buildDeliveryInformation(),
              const SizedBox(height: 16),
              _buildOrderDetails(),
              const SizedBox(height: 16),
              _buildItemList(),
              const SizedBox(height: 16),
              _buildOtpCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isDelivered
                  ? Icons.check_circle_outline_rounded
                  : Icons.delivery_dining_rounded,
              color: _green,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: _secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtaCard() {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            label: _isDelivered ? 'Order status' : 'Estimated delivery',
            value: _isDelivered ? 'Completed' : '$_etaMinutes mins',
            icon: _isDelivered
                ? Icons.task_alt_rounded
                : Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            label: 'Delivering to',
            value: order.deliveryAddressLabel,
            icon: Icons.home_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerCard(BuildContext context) {
    if (!_isOutForDelivery) return const SizedBox.shrink();
    return _SectionCard(
      title: 'Delivery Partner',
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.person_rounded, color: _green, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.partnerName ??
                      (order.isDemo ? 'Ravula Akash' : 'Delivery partner'),
                  style: TextStyle(
                    color: _mainText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Delivery Partner',
                  style: TextStyle(color: _secondaryText, fontSize: 12),
                ),
                SizedBox(height: 3),
                Text(
                  '+91 9XXXX XXXXX',
                  style: TextStyle(color: _secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text(
                '4.8 ★',
                style: TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_isDelivered)
                const Text(
                  'Completed',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else ...[
                _PartnerAction(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  onPressed: () => _showDemoMessage(context, 'Call'),
                ),
                const SizedBox(height: 6),
                _PartnerAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  onPressed: () => _showDemoMessage(context, 'Message'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final currentIndex = _timelineStatuses.indexOf(order.status);
    return _SectionCard(
      title: 'Order status',
      child: Column(
        children: [
          for (var index = 0; index < _timelineStatuses.length; index++)
            _TimelineStep(
              label: _timelineLabels[index],
              isComplete: _isDelivered || index < currentIndex,
              isCurrent: index == currentIndex && !_isDelivered,
              isLast: index == _timelineStatuses.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInformation() {
    return _SectionCard(
      title: 'Delivering to',
      child: Row(
        children: [
          const Icon(Icons.home_outlined, color: _green, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  order.deliveryAddressLabel,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  order.deliveryAddress,
                  style: const TextStyle(color: _secondaryText, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    final items = order.itemNames.isEmpty ? [order.items] : order.itemNames;
    return _SectionCard(
      title: 'Items in this order',
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: const Text(
            'View item list',
            style: TextStyle(
              color: _mainText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            for (final item in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shopping_bag_outlined, color: _green),
                title: Text(item),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return _SectionCard(
      title: 'Order details',
      child: Column(
        children: [
          _DetailRow(label: 'Order ID', value: order.orderId),
          const SizedBox(height: 10),
          _DetailRow(label: 'Store', value: order.storeName),
          const SizedBox(height: 10),
          _DetailRow(label: 'Items', value: order.items),
          const SizedBox(height: 10),
          _DetailRow(label: 'Total amount', value: order.total),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    return _SectionCard(
      title: 'Delivery OTP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isDelivered ? 'This demo delivery has been completed.' : 'Share this OTP with your delivery partner only when your order arrives.',
            style: const TextStyle(
              color: _secondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isDelivered ? 'Verified' : '4821',
              style: const TextStyle(
                color: _green,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Demo OTP · UI only',
            style: TextStyle(color: _secondaryText, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showDemoMessage(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is unavailable in this demo.')),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAE8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF59615C),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF202321),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF202321),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.isComplete,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isComplete;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isComplete || isCurrent
        ? AppTheme.primaryGreen
        : const Color(0xFFB8BFBA);
    return SizedBox(
      height: isLast ? 28 : 36,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Align(
              alignment: Alignment.topCenter,
              child: Icon(
                isComplete
                    ? Icons.check_circle_rounded
                    : isCurrent
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isComplete || isCurrent
                    ? const Color(0xFF202321)
                    : const Color(0xFF59615C),
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isCurrent)
            const Text(
              'CURRENT',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF59615C), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF202321),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerAction extends StatelessWidget {
  const _PartnerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryGreen,
        side: const BorderSide(color: Color(0xFFDCE9E2)),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
