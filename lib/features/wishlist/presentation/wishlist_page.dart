import 'package:flutter/material.dart';

import '../../cart/data/cart_store.dart';
import '../../product_details/data/product_availability_store.dart';
import '../../product_details/presentation/product_availability_badge.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../data/wishlist_store.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);

  @override
  Widget build(BuildContext context) {
    final wishlist = WishlistStore.instance;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        title: const Text(
          'Wishlist',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: AnimatedBuilder(
        animation: wishlist,
        builder: (context, child) {
          final products = wishlist.products;
          if (products.isEmpty) return _buildEmptyState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _WishlistProductCard(
              product: products[index],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              color: _green,
              size: 52,
            ),
            SizedBox(height: 14),
            Text(
              'Your Wishlist is empty',
              style: TextStyle(
                color: _mainText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Save items you love and find them here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistProductCard extends StatelessWidget {
  const _WishlistProductCard({required this.product});

  final ProductDetailsProduct product;

  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  @override
  Widget build(BuildContext context) {
    final merchant = product.merchantName ?? _serviceLabel(product.serviceType);
    final description = [
      product.brand,
      product.quantityLabel,
      product.description,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openDetails(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 74,
                height: 74,
                child: _productImage(product),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openDetails(context),
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            color: _mainText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Remove from wishlist',
                      onPressed: () => WishlistStore.instance.remove(product),
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: _green,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                Text(
                  merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _secondaryText,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (product.priceInPaise != null)
                      Text(
                        _formatPrice(product.priceInPaise!),
                        style: const TextStyle(
                          color: _mainText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(width: 6),
                    ProductAvailabilityBadge(
                      productId: product.id,
                      serviceType: product.serviceType,
                      merchantId: product.merchantId,
                      defaultAvailable: product.available,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => _addToCart(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productImage(ProductDetailsProduct product) {
    final imageUrl = product.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _imagePlaceholder(product);
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _imagePlaceholder(product),
    );
  }

  Widget _imagePlaceholder(ProductDetailsProduct product) {
    return Container(
      color: _lightGreen,
      child: Icon(product.icon, color: _green, size: 32),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailsPage(product: product),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final isAvailable = ProductAvailabilityStore.instance.isAvailable(
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.merchantId,
      defaultAvailable: product.available,
    );
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} is out of stock.')),
      );
      return;
    }
    final priceInPaise = product.priceInPaise;
    if (priceInPaise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price is unavailable for this product.')),
      );
      return;
    }
    final cart = CartStore.instance;
    final added = cart.addItem(
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.merchantId,
      serviceVariant: product.serviceVariant,
      categoryId: product.categoryId,
      name: product.name,
      description: [
        product.brand,
        product.quantityLabel,
        product.description,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · '),
      priceInPaise: priceInPaise,
      imageUrl: product.imageUrl,
      icon: product.icon,
    );
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cart.incompatibilityMessage(
                  serviceType: product.serviceType,
                  merchantId: product.merchantId,
                  serviceVariant: product.serviceVariant,
                ) ??
                'Please complete or clear your current order before adding '
                    'these items.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} added to cart.')),
    );
  }

  String _serviceLabel(String serviceType) {
    return switch (serviceType) {
      'restaurant' => 'Restaurant',
      'bakery' => 'Bakery',
      'local_store' => 'Local Store',
      'vegetables_fruits' => 'Fruits & Vegetables',
      'meat' => 'Meat',
      _ => serviceType,
    };
  }

  String _formatPrice(int priceInPaise) {
    final rupees = priceInPaise ~/ 100;
    final paise = priceInPaise % 100;
    return paise == 0
        ? '₹$rupees'
        : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }
}
