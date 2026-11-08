import 'package:flutter/material.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../utils/format.dart';
import '../utils/theme_colors.dart';
import 'delivery_map.dart';

/// Feature 3: the "new order" popup with a countdown ring and
/// Accept / Reject buttons.
class IncomingOrderCard extends StatefulWidget {
  final Order order;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onMute;
  final bool alertRinging;
  final bool busy; // true while the server is confirming Accept

  const IncomingOrderCard({
    super.key,
    required this.order,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onAccept,
    required this.onReject,
    required this.onMute,
    required this.alertRinging,
    this.busy = false,
  });

  @override
  State<IncomingOrderCard> createState() => _IncomingOrderCardState();
}

class _IncomingOrderCardState extends State<IncomingOrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    if (widget.alertRinging) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant IncomingOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alertRinging && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.alertRinging && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isCod = order.payment == PaymentType.cod;
    final isFood = order.type == OrderType.food;
    final typeColor = isFood ? Colors.deepOrange : Colors.blue;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: widget.alertRinging
                ? Colors.red.withValues(alpha: 0.35 + _pulse.value * 0.65)
                : Colors.transparent,
            width: widget.alertRinging ? 2 : 0,
          ),
        ),
        child: child,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(T.t('new_order'),
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                                isFood ? Icons.restaurant : Icons.inventory_2,
                                size: 16,
                                color: typeColor),
                            label: Text(T.t(isFood ? 'food' : 'parcel')),
                            backgroundColor: tint(context, typeColor),
                            side: BorderSide.none,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (widget.secondsLeft / widget.totalSeconds)
                                .clamp(0.0, 1.0),
                            color: widget.secondsLeft <= 10
                                ? Colors.red
                                : const Color(0xFFD9480F),
                          ),
                          Text('${widget.secondsLeft}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (widget.alertRinging)
                      IconButton(
                        tooltip: T.t('mute'),
                        onPressed: widget.busy ? null : widget.onMute,
                        icon: const Icon(Icons.volume_off_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _row(Icons.store, T.t('pickup'),
                    '${order.shopName}\n${order.shopAddress}'),
                const SizedBox(height: 8),
                _row(Icons.location_on, T.t('drop'), order.customerAddress),
                const SizedBox(height: 8),
                DeliveryMap(
                  order: order,
                  headingToShop: false,
                  height: 140,
                  showRider: false,
                  interactive: false,
                  showRecenter: false,
                ),
                const SizedBox(height: 8),
                if (isFood) ...[
                  Text(T.t('pickup_distance').replaceAll('{distance}',
                      order.pickupDistanceKm?.toStringAsFixed(1) ?? '-')),
                  Text(T.t('drop_distance').replaceAll(
                      '{distance}', order.distanceKm.toStringAsFixed(1))),
                ] else
                  Text(T.t('parcel_distance').replaceAll(
                      '{distance}', order.distanceKm.toStringAsFixed(1))),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('~${order.etaMinutes} ${T.t('eta_min')}'),
                    Text('${T.t('you_earn')} ${money(order.earning)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                if (order.tip > 0)
                  Text('${T.t('incl_tip')} ${money(order.tip)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(
                  isCod
                      ? '${T.t('collect_cash')}: ${money(order.codAmount)}'
                      : T.t('paid_online'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCod ? Colors.red.shade400 : Colors.grey),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(T.t('view_route')),
                  onPressed: () => openRoute(context, order.shopLat,
                      order.shopLng, order.customerLat, order.customerLng),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.busy ? null : widget.onReject,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: Text(T.t('reject')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.busy ? null : widget.onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD9480F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: widget.busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(T.t('accept'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(text),
              ],
            ),
          ),
        ],
      );
}
