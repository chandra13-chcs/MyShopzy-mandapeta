import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';
import '../utils/theme_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/success_check.dart';
import 'earnings_screen.dart';
import 'home_screen.dart';

class DeliverySuccessScreen extends StatefulWidget {
  const DeliverySuccessScreen({
    super.key,
    required this.order,
    required this.onComplete,
  });

  final Order order;
  final Future<String?> Function() onComplete;

  @override
  State<DeliverySuccessScreen> createState() => _DeliverySuccessScreenState();
}

class _DeliverySuccessScreenState extends State<DeliverySuccessScreen> {
  Timer? _autoContinueTimer;
  String _stage = 'otp_verified';
  String? _error;
  DateTime? _deliveredAt;
  bool _attemptRunning = false;
  bool _completionSucceeded = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_startPhotoVerification());
  }

  Future<void> _startPhotoVerification() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _stage = 'verifying_photo';
      _error = null;
    });
    await _completeDelivery();
  }

  Future<void> _completeDelivery() async {
    if (_attemptRunning || _completionSucceeded) return;
    setState(() {
      _attemptRunning = true;
      _error = null;
      _stage = 'verifying_photo';
    });
    final errorKey = await widget.onComplete();
    if (!mounted) return;
    setState(() {
      _attemptRunning = false;
      if (errorKey != null) {
        _error = T.t(errorKey);
        return;
      }
      _completionSucceeded = true;
      _stage = 'delivery_completed';
      _deliveredAt = DateTime.now();
    });
    if (_completionSucceeded) {
      if (!kIsWeb) unawaited(HapticFeedback.mediumImpact());
      _autoContinueTimer = Timer(
        const Duration(seconds: 6),
        _goHome,
      );
    }
  }

  void _goHome() {
    if (!mounted || _navigating) return;
    _navigating = true;
    _autoContinueTimer?.cancel();
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _viewEarnings() {
    if (!mounted || _navigating) return;
    _navigating = true;
    _autoContinueTimer?.cancel();
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(T.t('nav_earnings'))),
          body: const EarningsScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RiderController>();
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _completionSucceeded) _goHome();
      },
      child: Scaffold(
        backgroundColor: tint(context, Colors.green),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _completionSucceeded
                ? _completedContent(context, controller)
                : _verificationContent(context),
          ),
        ),
      ),
    );
  }

  Widget _verificationContent(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: T.t(_stage),
                child: SuccessCheck(
                  size: 144,
                  onDone: () {},
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  T.t(_stage),
                  key: ValueKey(_stage),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (_stage == 'verifying_photo' && _error == null) ...[
                const SizedBox(height: 18),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: T.t('try_again'),
                  onPressed: _attemptRunning ? null : _completeDelivery,
                ),
              ],
            ],
          ),
        ),
      );

  Widget _completedContent(
    BuildContext context,
    RiderController controller,
  ) {
    final order = widget.order;
    final pickupName =
        order.shopName.isNotEmpty ? order.shopName : order.shopAddress;
    final dropName = order.customerName.isNotEmpty
        ? order.customerName
        : order.customerAddress;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: SuccessCheck(
            size: 120,
            onDone: () {},
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: T.t('delivery_completed'),
          child: Text(
            T.t('delivery_completed'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(T.t('great_job'), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  T.t('order_summary'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _summaryRow(context, T.t('order_id'), order.id),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(
                        T.t(order.type == OrderType.food ? 'food' : 'parcel')),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _placeColumn(
                        T.t('pickup'),
                        pickupName,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Expanded(
                      child: _placeColumn(
                        T.t('drop'),
                        dropName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _summaryRow(
                  context,
                  T.t('distance'),
                  '${order.distanceKm.toStringAsFixed(1)} ${T.t('km')}',
                ),
                _summaryRow(
                  context,
                  T.t('delivered_at'),
                  _deliveredAt == null
                      ? ''
                      : '${fmtDate(_deliveredAt!)}, ${fmtTime(_deliveredAt!)}',
                ),
                const Divider(height: 22),
                Text(
                  '${T.t('you_earned')}: ${money(order.earning)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                if (order.tip > 0)
                  Text('${T.t('incl_tip')}: ${money(order.tip)}'),
                if (order.payment == PaymentType.cod) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tint(context, Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tintBorder(context, Colors.orange),
                      ),
                    ),
                    child: Text(
                      '${T.t('collect_cash_customer')}: ${money(order.codAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _statColumn(
                    T.t('today_deliveries'),
                    '${controller.todayDeliveries.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statColumn(
                    T.t('today_earnings'),
                    money(controller.todayEarnings),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: T.t('back_to_home'),
          onPressed: _goHome,
        ),
        TextButton(
          onPressed: _viewEarnings,
          child: Text(T.t('view_earnings')),
        ),
      ],
    );
  }

  Widget _placeColumn(String label, String name) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );

  Widget _summaryRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _statColumn(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );
}
