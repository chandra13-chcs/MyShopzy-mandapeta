import 'package:flutter/material.dart';

import '../data/product_availability_store.dart';

class ProductAvailabilityBadge extends StatelessWidget {
  const ProductAvailabilityBadge({
    required this.productId,
    required this.serviceType,
    required this.defaultAvailable,
    super.key,
    this.merchantId,
    this.compact = false,
  });

  final String productId;
  final String serviceType;
  final String? merchantId;
  final bool defaultAvailable;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProductAvailabilityStore.instance,
      builder: (context, child) {
        final available = ProductAvailabilityStore.instance.isAvailable(
          productId: productId,
          serviceType: serviceType,
          merchantId: merchantId,
          defaultAvailable: defaultAvailable,
        );
        if (available) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2F1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            'OUT OF STOCK',
            style: TextStyle(
              color: const Color(0xFFA85B5B),
              fontSize: compact ? 6 : 8,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}
