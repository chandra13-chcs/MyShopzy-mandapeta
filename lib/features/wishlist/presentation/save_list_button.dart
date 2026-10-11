import 'package:flutter/material.dart';

import '../../../shared/data/customer_api.dart';
import '../../product_details/models/product_details_product.dart';
import '../data/wishlist_store.dart';

class SaveListButton extends StatelessWidget {
  const SaveListButton({
    required this.product,
    super.key,
    this.color = const Color(0xFF17251F),
    this.size = 17,
  });

  final ProductDetailsProduct product;
  final Color color;
  final double size;

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
                  try {
                    await store.toggleSavedProduct(product);
                  } on CustomerApiException catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                },
          icon: Icon(
            isSaved
                ? Icons.favorite_rounded
                : Icons.bookmark_border_rounded,
            color: isSaved ? const Color(0xFFB63E32) : color,
            size: size,
          ),
        );
      },
    );
  }
}
