import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../home/presentation/home_page.dart';
import '../models/order_record.dart';
import 'order_details_page.dart';

/// Present only after order placement returns a genuinely confirmed record.
/// Future confirmation audio must be best-effort and must not gate this screen.
class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({required this.confirmedOrder, super.key});

  final OrderRecord confirmedOrder;

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
                Container(
                  key: const ValueKey('order-success-mark'),
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.white,
                    size: 62,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Order placed successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.primaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  confirmedOrder.isBackendData
                      ? 'Your order has been placed.'
                      : 'Your order from ${confirmedOrder.storeName} is confirmed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7EAE8)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Order ID: ${confirmedOrder.orderId}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        confirmedOrder.deliveryAddress,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    key: const ValueKey('order-success-view-details'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => confirmedOrder.isBackendData
                            ? BackendOrderDetailsPage(order: confirmedOrder)
                            : OrderDetailsPage(order: confirmedOrder),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View Order Details'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    key: const ValueKey('order-success-return-home'),
                    onPressed: () => Navigator.of(context)
                        .pushAndRemoveUntil<void>(
                          MaterialPageRoute<void>(
                            builder: (context) => const HomePage(),
                          ),
                          (route) => false,
                        ),
                    child: const Text('Return to Home'),
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
