import 'package:flutter/material.dart';

import '../../../app/main_navigation_shell.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/presentation/motion.dart';
import '../models/order_record.dart';
import 'order_details_page.dart';
import 'order_tracking_page.dart';

class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({required this.confirmedOrder, super.key});

  final OrderRecord confirmedOrder;

  OrderTrackingData _trackingData() => OrderTrackingData(
    orderId: confirmedOrder.orderId,
    storeName: confirmedOrder.storeName,
    items: confirmedOrder.itemSummary,
    total: confirmedOrder.total,
    status: confirmedOrder.trackingStatus ?? OrderTrackingStatus.orderPlaced,
    deliveryAddressLabel: confirmedOrder.deliveryAddressLabel,
    deliveryAddress: confirmedOrder.deliveryAddress,
    itemNames: confirmedOrder.items.map((item) => item.name).toList(),
    isDemo: !confirmedOrder.isBackendData,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('order-success-screen'),
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  key: const ValueKey('order-success-mark'),
                  tween: Tween<double>(
                    begin: reduceMotion(context) ? 1 : 0.55,
                    end: 1,
                  ),
                  duration: reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.white,
                      size: 82,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                const Text(
                  'Order placed for',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  confirmedOrder.deliveryAddressLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    confirmedOrder.deliveryAddress,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Order ID: ${confirmedOrder.orderId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    key: const ValueKey('order-success-track-order'),
                    onPressed: () => Navigator.of(context).push(
                      AppPageRoute<void>.builder(
                        builder: (context) =>
                            OrderTrackingPage(order: _trackingData()),
                      ),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Track order'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.tonal(
                    key: const ValueKey('order-success-view-details'),
                    onPressed: () => Navigator.of(context).push(
                      AppPageRoute<void>.builder(
                        builder: (context) =>
                            OrderDetailsPage(order: confirmedOrder),
                      ),
                    ),
                    child: const Text('View details'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    key: const ValueKey('order-success-return-home'),
                    onPressed: () =>
                        Navigator.of(context).pushAndRemoveUntil<void>(
                          AppPageRoute<void>.builder(
                            builder: (context) => const MainNavigationShell(),
                          ),
                          (route) => false,
                        ),
                    child: const Text('Return home'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    key: const ValueKey('order-success-continue-shopping'),
                    onPressed: () =>
                        Navigator.of(context).pushAndRemoveUntil<void>(
                          AppPageRoute<void>.builder(
                            builder: (context) => const MainNavigationShell(),
                          ),
                          (route) => false,
                        ),
                    child: const Text('Continue shopping'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
