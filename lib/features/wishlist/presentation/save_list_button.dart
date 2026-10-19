import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/data/customer_api.dart';
import '../../../shared/presentation/motion.dart';
import '../../product_details/models/product_details_product.dart';
import '../data/wishlist_store.dart';

class SaveListButton extends StatelessWidget {
  const SaveListButton({
    required this.product,
    super.key,
    this.color = const Color(0xFF17251F),
    this.size = 17,
    this.animateToggle = false,
  });

  final ProductDetailsProduct product;
  final Color color;
  final double size;
  final bool animateToggle;

  @override
  Widget build(BuildContext context) {
    final store = WishlistStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final isSaved = store.contains(product);
        final isPending = store.isPending(product);
        return IconButton(
          tooltip: isSaved ? 'Remove from wishlist' : 'Add to wishlist',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          onPressed: isPending
              ? null
              : () async {
                  if (animateToggle) HapticFeedback.selectionClick();
                  try {
                    await store.toggleSavedProduct(product);
                  } on CustomerApiException catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                },
          icon: AnimatedSwitcher(
            duration: animateToggle && !reduceMotion(context)
                ? kMotionFast
                : Duration.zero,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Icon(
              isSaved
                  ? Icons.favorite_rounded
                  : Icons.bookmark_border_rounded,
              key: ValueKey(isSaved),
              color: isSaved ? const Color(0xFFB63E32) : color,
              size: size,
            ),
          ),
        );
      },
    );
  }
}
