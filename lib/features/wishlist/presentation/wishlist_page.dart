import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../cart/data/cart_store.dart';
import '../../product_details/data/product_availability_store.dart';
import '../../product_details/presentation/product_availability_badge.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../data/wishlist_store.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;

  @override
  void initState() {
    super.initState();
    final wishlist = WishlistStore.instance;
    if (wishlist.isBackendMode) unawaited(wishlist.load());
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = WishlistStore.instance;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Wishlist',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: AnimatedBuilder(
        animation: wishlist,
        builder: (context, child) {
          final products = wishlist.products;
          if (wishlist.isBackendMode && wishlist.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (wishlist.isBackendMode && wishlist.error != null) {
            return _buildErrorState(wishlist);
          }
          if (products.isEmpty) return _buildEmptyState(wishlist.isBackendMode);
          return Column(
            children: [
              _sourceLabel(wishlist.isBackendMode),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _WishlistProductCard(product: products[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sourceLabel(bool backendMode) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Text(
          backendMode ? 'Backend wishlist' : 'Demo wishlist · saved on device',
          style: const TextStyle(color: _secondaryText, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildErrorState(WishlistStore wishlist) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: _secondaryText,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              wishlist.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: wishlist.isLoading ? null : wishlist.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool backendMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              backendMode
                  ? 'Backend wishlist'
                  : 'Demo wishlist · saved on device',
              style: const TextStyle(color: _secondaryText, fontSize: 11),
            ),
            const SizedBox(height: 14),
            const Icon(Icons.favorite_border_rounded, color: _green, size: 52),
            const SizedBox(height: 14),
            Text(
              'Your Wishlist is empty',
              style: const TextStyle(
                color: _mainText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Save items you love and find them here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondaryText, fontSize: 14),
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

  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
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
                      onPressed: WishlistStore.instance.isPending(product)
                          ? null
                          : () => _removeFromWishlist(context),
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
                        '${product.variants.isEmpty ? '' : 'From '}${_formatPrice(product.priceInPaise!)}',
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
                    child: Text(
                      product.variants.isEmpty
                          ? 'Add to Cart'
                          : 'Select Options',
                      style: const TextStyle(
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

  Future<void> _removeFromWishlist(BuildContext context) async {
    try {
      await WishlistStore.instance.removeSavedProduct(product);
    } on CustomerApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget _productImage(ProductDetailsProduct product) {
    final imageUrl = product.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _imagePlaceholder(product);
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _imagePlaceholder(product),
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
    if (product.variants.isNotEmpty) {
      _openDetails(context);
      return;
    }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} added to cart.')));
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
