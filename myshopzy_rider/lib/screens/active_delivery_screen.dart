import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';
import '../utils/theme_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/delivery_map.dart';
import 'delivery_proof_screen.dart';

/// Features 4 + 5: the 5-step delivery tracker, with call and
/// Google Maps buttons for the shop (before pickup) and the customer.
class ActiveDeliveryScreen extends StatelessWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderController>();
    final o = c.active;
    if (o == null) {
      return Scaffold(appBar: AppBar(title: Text(T.t('active_title'))));
    }
    final step = c.step;
    final heading = step.index < DeliveryStep.pickedUp.index;
    // Before pickup the rider heads to the shop, after pickup to the customer.
    final toShop = heading;
    final isCod = o.payment == PaymentType.cod;
    final isFood = o.type == OrderType.food;
    final orderTypeColor = isFood ? Colors.deepOrange : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text('${T.t('active_title')} · ${o.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency, color: Colors.red),
            tooltip: T.t('sos'),
            onPressed: () => callNumber(context, '112'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DeliveryMap(order: o, headingToShop: heading),
          const SizedBox(height: 12),
          _TripTimer(
              since: c.acceptedAt ?? DateTime.now(),
              expectedMinutes: o.etaMinutes + 15),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(isFood ? Icons.restaurant : Icons.inventory_2,
                        size: 16, color: orderTypeColor),
                    label: Text(T.t(isFood ? 'food' : 'parcel')),
                    backgroundColor: tint(context, orderTypeColor),
                    side: BorderSide.none,
                  ),
                  Text(
                      toShop
                          ? (isFood ? T.t('pickup') : T.t('pickup_point'))
                          : T.t('drop'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(toShop ? o.shopName : o.customerName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                          child:
                              Text(toShop ? o.shopAddress : o.customerAddress)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: T.t('copy_address'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  toShop ? o.shopAddress : o.customerAddress));
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(T.t('copied'))));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.call),
                          label: Text(
                              toShop ? T.t('call_shop') : T.t('call_customer')),
                          onPressed: () => callNumber(
                              context, toShop ? o.shopPhone : o.customerPhone),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.navigation),
                          label: Text(T.t('navigate')),
                          onPressed: () => toShop
                              ? openMaps(context, o.shopLat, o.shopLng)
                              : openMaps(context, o.customerLat, o.customerLng),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isFood
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(T.t('pickup_distance').replaceAll('{distance}',
                            o.pickupDistanceKm?.toStringAsFixed(1) ?? '-')),
                        Text(T.t('drop_distance').replaceAll(
                            '{distance}', o.distanceKm.toStringAsFixed(1))),
                      ],
                    )
                  : Text(T.t('parcel_distance').replaceAll(
                      '{distance}', o.distanceKm.toStringAsFixed(1))),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('items'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(o.items),
                  const SizedBox(height: 8),
                  Text(
                    isCod
                        ? '${T.t('collect_cash')}: ${money(o.codAmount)}'
                        : T.t('paid_online'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCod
                            ? Colors.red.shade400
                            : Colors.green.shade400),
                  ),
                  Text('${T.t('you_earn')}: ${money(o.earning)}'
                      '${o.tip > 0 ? '  (${T.t('incl_tip')} ${money(o.tip)})' : ''}'),
                  if (o.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(T.t('customer_note'),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(o.note,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final s in DeliveryStep.values) _StepRow(step: s, current: step),
          const SizedBox(height: 16),
          if (step == DeliveryStep.reachedCustomer)
            PrimaryButton(
              label: T.t('btn_reachedCustomer'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeliveryProofScreen()),
              ),
            )
          else if (step == DeliveryStep.reachedHotel)
            PrimaryButton(
              label: T.t('btn_${step.name}'),
              onPressed: () => _confirmPickup(context, c, o),
            )
          else
            PrimaryButton(
              label: T.t('btn_${step.name}'),
              onPressed: c.advanceStep,
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(T.t('report_problem')),
            onPressed: () => _reportProblem(context),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final DeliveryStep step;
  final DeliveryStep current;
  const _StepRow({required this.step, required this.current});

  @override
  Widget build(BuildContext context) {
    final done = step.index < current.index;
    final isNow = step == current;
    return ListTile(
      dense: true,
      leading: Icon(
        done
            ? Icons.check_circle
            : (isNow
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked),
        color: done
            ? Colors.green
            : (isNow ? const Color(0xFFD9480F) : Colors.grey),
      ),
      title: Text(T.t('step_${step.name}'),
          style: TextStyle(
              fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
              color: done || isNow ? null : Colors.grey)),
    );
  }
}

/// Bottom sheet with the reasons a rider can give for not finishing.
/// Choosing one releases the order and returns to Home.
void _reportProblem(BuildContext context) {
  final c = context.read<RiderController>();
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(T.t('report_problem'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          for (final k in const [
            'issue_shop_closed',
            'issue_no_answer',
            'issue_wrong_address',
            'issue_vehicle',
          ])
            ListTile(
              title: Text(T.t(k)),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await c.reportIssue(k);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    ),
  );
}

/// The rider ticks every item before leaving the shop, so nothing is
/// forgotten. Only when all are ticked can they confirm the pickup.
Future<void> _confirmPickup(
    BuildContext context, RiderController c, Order o) async {
  final items = o.items
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final checked = List<bool>.filled(items.length, false);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) => AlertDialog(
        title: Text(T.t('check_items')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked[i],
                  title: Text(items[i]),
                  onChanged: (v) => setInner(() => checked[i] = v ?? false),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(T.t('cancel'))),
          TextButton(
              onPressed: checked.every((e) => e)
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              child: Text(T.t('confirm'))),
        ],
      ),
    ),
  );
  if (ok == true) c.advanceStep();
}

/// Live "time since accepted" clock. Turns red when the rider is later
/// than the expected trip time (pickup + ride + a 15 minute allowance).
class _TripTimer extends StatefulWidget {
  final DateTime since;
  final int expectedMinutes;
  const _TripTimer({required this.since, required this.expectedMinutes});

  @override
  State<_TripTimer> createState() => _TripTimerState();
}

class _TripTimerState extends State<_TripTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = DateTime.now().difference(widget.since).inSeconds;
    final isLate = secs > widget.expectedMinutes * 60;
    final color = isLate ? Colors.red : Colors.green;
    return Card(
      color: tint(context, isLate ? Colors.red : Colors.green),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: color),
                const SizedBox(width: 8),
                Text('${T.t('trip_time')}: ${fmtClock(secs)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(
                    '${T.t('expected_time')}: ${widget.expectedMinutes} ${T.t('eta_min')}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (isLate)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(T.t('running_late'),
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
