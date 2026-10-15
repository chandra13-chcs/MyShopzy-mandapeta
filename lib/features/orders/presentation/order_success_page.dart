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
                  width: 136,
                  height: 136,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1557E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.white,
                    size: 82,
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
