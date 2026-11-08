import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../screens/active_delivery_screen.dart';
import '../services/rider_controller.dart';
import '../utils/nav.dart';
import '../widgets/primary_button.dart';
import 'incoming_order_card.dart';

/// Drawn ABOVE every screen (it is placed in MaterialApp.builder), so a
/// rider on any pushed screen still sees:
///  - the new-order popup (with a spinner while the server confirms Accept)
///  - the "order cancelled" notice when the customer/shop cancels
class IncomingOrderOverlay extends StatelessWidget {
  const IncomingOrderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderController>();

    final cancelled = c.cancelled;
    if (cancelled != null) {
      return _scrim(_CancelledCard(
          order: cancelled, afterPickup: c.cancelledAfterPickup));
    }

    final order = c.incoming;
    if (order == null) return const SizedBox.shrink();
    return _scrim(
      IncomingOrderCard(
        order: order,
        secondsLeft: c.secondsLeft,
        totalSeconds: RiderController.acceptSeconds,
        busy: c.accepting,
        alertRinging: c.alertRinging,
        onMute: () async {
          await c.muteIncomingAlert();
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(T.t('alert_muted'))));
          }
        },
        onAccept: () async {
          final err = await c.accept();
          if (err != null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(T.t(err))));
            }
            return;
          }
          if (c.active != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const ActiveDeliveryScreen()),
            );
          }
        },
        onReject: c.reject,
      ),
    );
  }

  Widget _scrim(Widget child) => Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
}

/// Shown when the customer or shop cancels an order the rider accepted.
class _CancelledCard extends StatelessWidget {
  final Order order;
  final bool afterPickup;
  const _CancelledCard({required this.order, required this.afterPickup});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(T.t('order_cancelled'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${order.id} · ${order.shopName}'),
            const SizedBox(height: 8),
            Text(T.t('cancelled_body'), textAlign: TextAlign.center),
            if (afterPickup) ...[
              const SizedBox(height: 8),
              Text(T.t('cancelled_picked'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: T.t('ok'),
              onPressed: () {
                context.read<RiderController>().acknowledgeCancelled();
                // Leave the delivery / proof screens and go back to Home.
                navigatorKey.currentState?.popUntil((r) => r.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}
