import 'package:flutter/material.dart';

enum OrderTrackingStatus {
  orderPlaced,
  orderConfirmed,
  preparing,
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
  });

  final String orderId;
  final String storeName;
  final String items;
  final String total;
  final OrderTrackingStatus status;
}

class OrderTrackingPage extends StatelessWidget {
  const OrderTrackingPage({required this.order, super.key});

  final OrderTrackingData order;

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  static const _timelineStatuses = [
    OrderTrackingStatus.orderPlaced,
    OrderTrackingStatus.orderConfirmed,
    OrderTrackingStatus.preparing,
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
    'Finding delivery partner',
    'Rider assigned',
    'Picked up',
    'On the way',
    'Arriving',
    'Delivered',
  ];

  String get _statusTitle => switch (order.status) {
    OrderTrackingStatus.orderPlaced => 'Order Placed',
    OrderTrackingStatus.orderConfirmed => 'Order Confirmed',
    OrderTrackingStatus.preparing => 'Preparing',
    OrderTrackingStatus.findingDeliveryPartner => 'Finding Delivery Partner',
    OrderTrackingStatus.riderAssigned => 'Rider Assigned',
    OrderTrackingStatus.pickedUp => 'Picked Up',
    OrderTrackingStatus.onTheWay => 'On the way',
    OrderTrackingStatus.arriving => 'Arriving',
    OrderTrackingStatus.delivered => 'Delivered',
  };

  String get _statusMessage => switch (order.status) {
    OrderTrackingStatus.orderPlaced => 'We have received your order',
    OrderTrackingStatus.orderConfirmed => 'The store has confirmed your order',
    OrderTrackingStatus.preparing => 'The store is preparing your order',
    OrderTrackingStatus.findingDeliveryPartner =>
      'We are finding a delivery partner',
    OrderTrackingStatus.riderAssigned =>
      'A delivery partner has been assigned',
    OrderTrackingStatus.pickedUp => 'Your order has been picked up',
    OrderTrackingStatus.onTheWay =>
      'Your delivery partner is on the way',
    OrderTrackingStatus.arriving => 'Your delivery partner is arriving',
    OrderTrackingStatus.delivered => 'Your order has been delivered',
  };

  bool get _isDelivered => order.status == OrderTrackingStatus.delivered;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(),
              const SizedBox(height: 16),
              _buildEtaCard(),
              const SizedBox(height: 16),
              _buildMapPlaceholder(),
              const SizedBox(height: 16),
              _buildPartnerCard(context),
              const SizedBox(height: 16),
              _buildTimeline(),
              const SizedBox(height: 16),
              _buildDeliveryInformation(),
              const SizedBox(height: 16),
              _buildOrderDetails(),
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
            label: _isDelivered ? 'Order status' : 'Arriving in',
            value: _isDelivered ? 'Completed' : '18 mins',
            icon: _isDelivered
                ? Icons.task_alt_rounded
                : Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            label: _isDelivered ? 'Tracking' : 'Distance',
            value: _isDelivered ? 'Inactive' : '1.8 km away',
            icon: _isDelivered
                ? Icons.location_off_outlined
                : Icons.near_me_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DemoMapPainter()),
          ),
          Positioned(
            left: 15,
            top: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                'DEMO MAP',
                style: TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          if (!_isDelivered) ...[
            const Positioned(
              left: 82,
              top: 100,
              child: _MapMarker(
                icon: Icons.delivery_dining_rounded,
                label: 'Rider',
                color: _green,
              ),
            ),
            const Positioned(
              right: 57,
              bottom: 41,
              child: _MapMarker(
                icon: Icons.location_on_rounded,
                label: 'You',
                color: Color(0xFFB6534B),
              ),
            ),
          ] else
            const Center(
              child: Icon(Icons.check_circle_rounded, color: _green, size: 42),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              color: Colors.white.withValues(alpha: 0.94),
              child: Text(
                _isDelivered
                    ? 'Delivery completed · static demo map'
                    : 'Live tracking map · Rider location will appear here',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(BuildContext context) {
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
            child: const Icon(
              Icons.person_rounded,
              color: _green,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ravi Kumar',
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
    return const _SectionCard(
      title: 'Delivering to',
      child: Row(
        children: [
          Icon(Icons.home_outlined, color: _green, size: 24),
          SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Home',
                style: TextStyle(
                  color: _mainText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Demo address',
                style: TextStyle(color: _secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
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
            _isDelivered
                ? 'This demo delivery has been completed.'
                : 'Share this OTP with your delivery partner only when your order arrives.',
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
          Icon(icon, color: const Color(0xFF2C7C65), size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF777C79),
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
        ? const Color(0xFF2C7C65)
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
                    : const Color(0xFF777C79),
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isCurrent)
            const Text(
              'CURRENT',
              style: TextStyle(
                color: Color(0xFF2C7C65),
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
            style: const TextStyle(color: Color(0xFF777C79), fontSize: 12),
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
        foregroundColor: const Color(0xFF2C7C65),
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

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF202321),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFD5E1D2)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(-10, size.height * 0.28)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.48,
        size.width * 0.63,
        size.height * 0.12,
        size.width + 10,
        size.height * 0.37,
      );
    canvas.drawPath(path, roadPaint);

    final secondaryRoadPaint = Paint()
      ..color = const Color(0xFFDCE7D9)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final secondaryPath = Path()
      ..moveTo(size.width * 0.35, -10)
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.3,
        size.width * 0.23,
        size.height * 0.7,
        size.width * 0.45,
        size.height + 10,
      );
    canvas.drawPath(secondaryPath, secondaryRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
