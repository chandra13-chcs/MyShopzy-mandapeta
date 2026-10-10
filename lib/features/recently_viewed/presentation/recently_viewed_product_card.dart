import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/presentation/dietary_badge.dart';
import '../../../shared/presentation/press_scale_feedback.dart';
import '../../product_details/presentation/product_availability_badge.dart';
import '../../product_details/presentation/product_details_page.dart';

class RecentlyViewedProductCard extends StatelessWidget {
  const RecentlyViewedProductCard({
    required this.product,
    super.key,
    this.width,
  });

  final ProductDetailsProduct product;
  final double? width;

  static const _ink = AppTheme.primaryText;
  static const _green = AppTheme.primaryGreen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: PressScaleFeedback(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => ProductDetailsPage(product: product),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEBEEE9)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.55,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProductImage(product: product),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: ProductAvailabilityBadge(
                            productId: product.id,
                            serviceType: product.serviceType,
                            merchantId: product.merchantId,
                            defaultAvailable: product.available,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (product.isVegetarian != null) ...[
                          const SizedBox(height: 4),
                          DietaryBadge(isVegetarian: product.isVegetarian!),
                        ],
                        if (product.priceInPaise != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatPrice(product.priceInPaise!),
                            style: const TextStyle(
                              color: _green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(int priceInPaise) {
    final rupees = priceInPaise ~/ 100;
    final paise = priceInPaise % 100;
    return paise == 0
        ? '₹$rupees'
        : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});

  final ProductDetailsProduct product;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url == null || url.isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFEAF1E8),
      child: Icon(
        product.icon,
        color: const Color(0xFF17251F).withValues(alpha: 0.65),
        size: 34,
      ),
    );
  }
}
