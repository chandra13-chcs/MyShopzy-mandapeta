import 'package:flutter/material.dart';

import '../../../app/config/delivery_offer_config.dart';
import '../../../app/theme/app_theme.dart';
import '../../cart/data/cart_store.dart';

class FreeDeliveryOfferBanner extends StatefulWidget {
  const FreeDeliveryOfferBanner({super.key});

  @override
  State<FreeDeliveryOfferBanner> createState() =>
      _FreeDeliveryOfferBannerState();
}

class _FreeDeliveryOfferBannerState extends State<FreeDeliveryOfferBanner> {
  static const _bannerColor = Color(0xFFE8FAFA);
  var _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final cartStore = CartStore.instance;
    return AnimatedBuilder(
      animation: cartStore,
      builder: (context, child) {
        final offerStatus = DeliveryOfferConfig.messageForSubtotal(
          cartStore.subtotalInPaise,
        );
        return Container(
          key: const ValueKey('free-delivery-offer-banner'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          color: _bannerColor,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label:
                      'FREE DELIVERY on orders above '
                      '${DeliveryOfferConfig.thresholdLabel}. $offerStatus',
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(
                          text: 'FREE DELIVERY',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text:
                              ' on orders above '
                              '${DeliveryOfferConfig.thresholdLabel}',
                        ),
                      ],
                    ),
                    key: const ValueKey('free-delivery-offer-message'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('free-delivery-offer-dismiss'),
                tooltip: 'Dismiss free delivery offer',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => setState(() => _isDismissed = true),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.darkGreen,
                  size: 19,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FreeDeliveryProgressStrip extends StatelessWidget {
  const FreeDeliveryProgressStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final cartStore = CartStore.instance;
    return AnimatedBuilder(
      animation: cartStore,
      builder: (context, child) {
        final eligibleSubtotalInPaise = cartStore.subtotalInPaise;
        final remainingInPaise = DeliveryOfferConfig.remainingInPaise(
          eligibleSubtotalInPaise,
        );
        final progress =
            (eligibleSubtotalInPaise / DeliveryOfferConfig.thresholdInPaise)
                .clamp(0.0, 1.0);
        final isUnlocked = remainingInPaise == 0;

        return Semantics(
          liveRegion: true,
          label: DeliveryOfferConfig.messageForSubtotal(
            eligibleSubtotalInPaise,
          ),
          child: Container(
            key: const ValueKey('free-delivery-progress-strip'),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5EA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD8E9D9)),
            ),
            child: Row(
              children: [
                Icon(
                  isUnlocked
                      ? Icons.check_circle_rounded
                      : Icons.delivery_dining_rounded,
                  color: AppTheme.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DeliveryOfferConfig.messageForSubtotal(
                          eligibleSubtotalInPaise,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.white,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DeliveryOfferConfig.thresholdLabel,
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
