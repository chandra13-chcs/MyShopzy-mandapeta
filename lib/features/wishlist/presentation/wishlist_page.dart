import 'package:flutter/material.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  static const _demoProducts = [
    _WishlistProduct(
      name: 'Paneer Tikka Wrap',
      description: 'Smoky paneer, crisp vegetables and mint chutney',
      price: '₹189',
      mrp: '₹229',
      icon: Icons.restaurant_rounded,
      discount: '18% OFF',
    ),
    _WishlistProduct(
      name: 'Butter Croissant',
      description: 'Flaky, freshly baked and golden',
      price: '₹95',
      mrp: '₹120',
      icon: Icons.bakery_dining_rounded,
      discount: '21% OFF',
    ),
    _WishlistProduct(
      name: 'Fresh Fruit Basket',
      description: 'Seasonal apples, bananas and oranges',
      price: '₹349',
      icon: Icons.shopping_basket_outlined,
    ),
  ];

  late final List<_WishlistProduct> _products = [..._demoProducts];

  @override
  Widget build(BuildContext context) {
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
      body: _products.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              itemCount: _products.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildProductCard(_products[index]),
            ),
    );
  }

  Widget _buildProductCard(_WishlistProduct product) {
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
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(product.icon, color: _green, size: 32),
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
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: _mainText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
                      onPressed: () {
                        setState(() {
                          _products.remove(product);
                        });
                      },
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: _green,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                Text(
                  product.description,
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      product.price,
                      style: const TextStyle(
                        color: _mainText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.mrp != null) ...[
                      const SizedBox(width: 7),
                      Text(
                        product.mrp!,
                        style: const TextStyle(
                          color: _secondaryText,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      if (product.discount != null) ...[
                        const SizedBox(width: 7),
                        Text(
                          product.discount!,
                          style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cart functionality will be available soon',
                          ),
                        ),
                      );
                    },
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

class _WishlistProduct {
  const _WishlistProduct({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    this.mrp,
    this.discount,
  });

  final String name;
  final String description;
  final String price;
  final String? mrp;
  final String? discount;
  final IconData icon;
}
