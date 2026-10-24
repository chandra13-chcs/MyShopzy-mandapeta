import 'package:flutter/material.dart';

import '../../../shared/data/money_formatter.dart';

class OutstandingDuesBanner extends StatelessWidget {
  const OutstandingDuesBanner({
    required this.amountMinor,
    required this.orderId,
    this.onTap,
    super.key,
  });

  final int amountMinor;
  final String? orderId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final orderReference = orderId == null || orderId!.isEmpty
        ? 'your order'
        : 'order #$orderId';
    return Material(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF2D4A8)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF9A5C00),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You have ${formatMinorCurrency(amountMinor)} pending from $orderReference. Clear it to order again.',
                  style: const TextStyle(
                    color: Color(0xFF805000),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
