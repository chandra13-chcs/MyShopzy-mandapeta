import 'package:flutter/material.dart';

import '../../cart/presentation/cart_access_button.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../../wishlist/presentation/save_list_button.dart';

enum ProduceType { fruit, vegetable }

class ProduceCategory {
  const ProduceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
  });

  final String id;
  final String name;
  final ProduceType type;
  final IconData icon;
}

class ProduceProduct {
  const ProduceProduct({
    required this.id,
    required this.categoryId,
    required this.type,
    required this.name,
    required this.packSize,
    required this.price,
    required this.mrp,
    required this.discount,
    required this.rating,
    required this.available,
    this.imageUrl,
  });

  final String id;
  final String categoryId;
  final ProduceType type;
  final String name;
  final String? imageUrl;
  final String packSize;
  final double price;
  final double mrp;
  final int discount;
  final double rating;
  final bool available;
}

const commonProduceCategories = [
  ProduceCategory(
    id: 'apples',
    name: 'Apples',
    type: ProduceType.fruit,
    icon: Icons.apple_rounded,
  ),
  ProduceCategory(
    id: 'bananas',
    name: 'Bananas',
    type: ProduceType.fruit,
    icon: Icons.spa_rounded,
  ),
  ProduceCategory(
    id: 'oranges',
    name: 'Oranges',
    type: ProduceType.fruit,
    icon: Icons.circle_rounded,
  ),
  ProduceCategory(
    id: 'mangoes',
    name: 'Mangoes',
    type: ProduceType.fruit,
    icon: Icons.energy_savings_leaf_rounded,
  ),
  ProduceCategory(
    id: 'grapes',
    name: 'Grapes',
    type: ProduceType.fruit,
    icon: Icons.grain_rounded,
  ),
  ProduceCategory(
    id: 'pomegranate',
    name: 'Pomegranate',
    type: ProduceType.fruit,
    icon: Icons.circle_rounded,
  ),
  ProduceCategory(
    id: 'watermelon',
    name: 'Watermelon',
    type: ProduceType.fruit,
    icon: Icons.circle_rounded,
  ),
  ProduceCategory(
    id: 'papaya',
    name: 'Papaya',
    type: ProduceType.fruit,
    icon: Icons.spa_rounded,
  ),
  ProduceCategory(
    id: 'guava',
    name: 'Guava',
    type: ProduceType.fruit,
    icon: Icons.eco_rounded,
  ),
  ProduceCategory(
    id: 'leafy-vegetables',
    name: 'Leafy Vegetables',
    type: ProduceType.vegetable,
    icon: Icons.grass_rounded,
  ),
  ProduceCategory(
    id: 'root-vegetables',
    name: 'Root Vegetables',
    type: ProduceType.vegetable,
    icon: Icons.grass_rounded,
  ),
  ProduceCategory(
    id: 'tomatoes',
    name: 'Tomatoes',
    type: ProduceType.vegetable,
    icon: Icons.circle_rounded,
  ),
  ProduceCategory(
    id: 'onions',
    name: 'Onions',
    type: ProduceType.vegetable,
    icon: Icons.circle_rounded,
  ),
  ProduceCategory(
    id: 'potatoes',
    name: 'Potatoes',
    type: ProduceType.vegetable,
    icon: Icons.grain_rounded,
  ),
  ProduceCategory(
    id: 'brinjal',
    name: 'Brinjal',
    type: ProduceType.vegetable,
    icon: Icons.egg_rounded,
  ),
  ProduceCategory(
    id: 'carrot',
    name: 'Carrot',
    type: ProduceType.vegetable,
    icon: Icons.grass_rounded,
  ),
  ProduceCategory(
    id: 'beans',
    name: 'Beans',
    type: ProduceType.vegetable,
    icon: Icons.eco_rounded,
  ),
  ProduceCategory(
    id: 'cabbage',
    name: 'Cabbage',
    type: ProduceType.vegetable,
    icon: Icons.filter_vintage_rounded,
  ),
  ProduceCategory(
    id: 'cauliflower',
    name: 'Cauliflower',
    type: ProduceType.vegetable,
    icon: Icons.local_florist_rounded,
  ),
];

const sampleProduceProducts = [
  ProduceProduct(
    id: 'shimla-apples',
    categoryId: 'apples',
    type: ProduceType.fruit,
    name: 'Shimla Apples',
    packSize: '4 pcs',
    price: 139,
    mrp: 160,
    discount: 13,
    rating: 4.5,
    available: true,
  ),
  ProduceProduct(
    id: 'kashmir-apples',
    categoryId: 'apples',
    type: ProduceType.fruit,
    name: 'Kashmir Apples',
    packSize: '500 g',
    price: 119,
    mrp: 140,
    discount: 15,
    rating: 4.6,
    available: true,
  ),
  ProduceProduct(
    id: 'robusta-bananas',
    categoryId: 'bananas',
    type: ProduceType.fruit,
    name: 'Robusta Bananas',
    packSize: '6 pcs',
    price: 45,
    mrp: 52,
    discount: 13,
    rating: 4.4,
    available: true,
  ),
  ProduceProduct(
    id: 'sweet-oranges',
    categoryId: 'oranges',
    type: ProduceType.fruit,
    name: 'Sweet Oranges',
    packSize: '500 g',
    price: 69,
    mrp: 80,
    discount: 14,
    rating: 4.3,
    available: true,
  ),
  ProduceProduct(
    id: 'banganapalli-mangoes',
    categoryId: 'mangoes',
    type: ProduceType.fruit,
    name: 'Banganapalli Mangoes',
    packSize: '1 kg',
    price: 129,
    mrp: 150,
    discount: 14,
    rating: 4.7,
    available: true,
  ),
  ProduceProduct(
    id: 'green-grapes',
    categoryId: 'grapes',
    type: ProduceType.fruit,
    name: 'Green Grapes',
    packSize: '500 g',
    price: 75,
    mrp: 90,
    discount: 17,
    rating: 4.4,
    available: true,
  ),
  ProduceProduct(
    id: 'pomegranate',
    categoryId: 'pomegranate',
    type: ProduceType.fruit,
    name: 'Fresh Pomegranate',
    packSize: '2 pcs',
    price: 99,
    mrp: 120,
    discount: 18,
    rating: 4.5,
    available: true,
  ),
  ProduceProduct(
    id: 'watermelon',
    categoryId: 'watermelon',
    type: ProduceType.fruit,
    name: 'Fresh Watermelon',
    packSize: '1 pc',
    price: 89,
    mrp: 105,
    discount: 15,
    rating: 4.3,
    available: true,
  ),
  ProduceProduct(
    id: 'papaya',
    categoryId: 'papaya',
    type: ProduceType.fruit,
    name: 'Ripe Papaya',
    packSize: '1 pc',
    price: 59,
    mrp: 70,
    discount: 16,
    rating: 4.2,
    available: true,
  ),
  ProduceProduct(
    id: 'guava',
    categoryId: 'guava',
    type: ProduceType.fruit,
    name: 'Fresh Guava',
    packSize: '500 g',
    price: 49,
    mrp: 60,
    discount: 18,
    rating: 4.1,
    available: true,
  ),
  ProduceProduct(
    id: 'spinach',
    categoryId: 'leafy-vegetables',
    type: ProduceType.vegetable,
    name: 'Fresh Spinach',
    packSize: '1 bunch',
    price: 25,
    mrp: 30,
    discount: 17,
    rating: 4.3,
    available: true,
  ),
  ProduceProduct(
    id: 'amaranth-leaves',
    categoryId: 'leafy-vegetables',
    type: ProduceType.vegetable,
    name: 'Amaranth Leaves',
    packSize: '1 bunch',
    price: 22,
    mrp: 28,
    discount: 21,
    rating: 4.2,
    available: true,
  ),
  ProduceProduct(
    id: 'mixed-root-vegetables',
    categoryId: 'root-vegetables',
    type: ProduceType.vegetable,
    name: 'Mixed Root Vegetables',
    packSize: '500 g',
    price: 59,
    mrp: 70,
    discount: 16,
    rating: 4.1,
    available: true,
  ),
  ProduceProduct(
    id: 'red-tomatoes',
    categoryId: 'tomatoes',
    type: ProduceType.vegetable,
    name: 'Farm Fresh Tomatoes',
    packSize: '500 g',
    price: 29,
    mrp: 35,
    discount: 17,
    rating: 4.3,
    available: true,
  ),
  ProduceProduct(
    id: 'onions',
    categoryId: 'onions',
    type: ProduceType.vegetable,
    name: 'Regular Onions',
    packSize: '1 kg',
    price: 39,
    mrp: 48,
    discount: 19,
    rating: 4.4,
    available: true,
  ),
  ProduceProduct(
    id: 'potatoes',
    categoryId: 'potatoes',
    type: ProduceType.vegetable,
    name: 'Fresh Potatoes',
    packSize: '1 kg',
    price: 35,
    mrp: 42,
    discount: 17,
    rating: 4.2,
    available: true,
  ),
  ProduceProduct(
    id: 'brinjal',
    categoryId: 'brinjal',
    type: ProduceType.vegetable,
    name: 'Purple Brinjal',
    packSize: '500 g',
    price: 35,
    mrp: 42,
    discount: 17,
    rating: 4.1,
    available: true,
  ),
  ProduceProduct(
    id: 'carrot',
    categoryId: 'carrot',
    type: ProduceType.vegetable,
    name: 'Ooty Carrots',
    packSize: '500 g',
    price: 49,
    mrp: 58,
    discount: 16,
    rating: 4.4,
    available: true,
  ),
  ProduceProduct(
    id: 'beans',
    categoryId: 'beans',
    type: ProduceType.vegetable,
    name: 'Green Beans',
    packSize: '250 g',
    price: 32,
    mrp: 39,
    discount: 18,
    rating: 4.2,
    available: true,
  ),
  ProduceProduct(
    id: 'cabbage',
    categoryId: 'cabbage',
    type: ProduceType.vegetable,
    name: 'Fresh Cabbage',
    packSize: '1 pc',
    price: 35,
    mrp: 42,
    discount: 17,
    rating: 4.1,
    available: true,
  ),
  ProduceProduct(
    id: 'cauliflower',
    categoryId: 'cauliflower',
    type: ProduceType.vegetable,
    name: 'Cauliflower',
    packSize: '1 pc',
    price: 45,
    mrp: 55,
    discount: 18,
    rating: 4.3,
    available: true,
  ),
];

class ProduceCatalogPage extends StatefulWidget {
  const ProduceCatalogPage({
    required this.type,
    super.key,
    this.categories = commonProduceCategories,
    this.products = sampleProduceProducts,
  });

  final ProduceType type;
  final List<ProduceCategory> categories;
  final List<ProduceProduct> products;

  @override
  State<ProduceCatalogPage> createState() => _ProduceCatalogPageState();
}

class _ProduceCatalogPageState extends State<ProduceCatalogPage> {
  static const _ink = Color(0xFF17251F);
  static const _muted = Color(0xFF727A74);
  static const _green = Color(0xFF16834A);

  late String _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    final categories = widget.categories
        .where((category) => category.type == widget.type)
        .toList();
    _selectedCategoryId = categories.isEmpty ? '' : categories.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories
        .where((category) => category.type == widget.type)
        .toList();
    final visibleProducts = widget.products
        .where(
          (product) =>
              product.type == widget.type &&
              product.categoryId == _selectedCategoryId,
        )
        .toList();
    final selectedCategories = categories.where(
      (category) => category.id == _selectedCategoryId,
    );
    final categoryName = selectedCategories.isEmpty
        ? 'Products'
        : selectedCategories.first.name;
    final title = widget.type == ProduceType.fruit ? 'Fruits' : 'Vegetables';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, title),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 82,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 7, bottom: 10),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final selected = category.id == _selectedCategoryId;
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedCategoryId = category.id),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(7, 5, 7, 10),
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 62,
                                  height: 65,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFE9F1E7)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFFBBD4B7)
                                          : const Color(0xFFE9ECE7),
                                    ),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: selected
                                        ? _green
                                        : const Color(0xFF8B948C),
                                    size: 27,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  category.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected ? _ink : _muted,
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(9, 8, 12, 18),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _ProduceProductCard(
                                product: visibleProducts[index],
                                placeholderIndex: index,
                                relatedProducts: visibleProducts
                                    .where(
                                      (related) =>
                                          related.categoryId ==
                                              visibleProducts[index]
                                                  .categoryId &&
                                          related.id !=
                                              visibleProducts[index].id,
                                    )
                                    .toList(),
                              ),
                              childCount: visibleProducts.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 9,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 288,
                                ),
                          ),
                        ),
                        if (visibleProducts.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  'No $categoryName available right now.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 9, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.25,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded, color: _ink, size: 24),
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          ),
        ],
      ),
    );
  }
}

class _ProduceProductCard extends StatelessWidget {
  const _ProduceProductCard({
    required this.product,
    required this.placeholderIndex,
    required this.relatedProducts,
  });

  final ProduceProduct product;
  final int placeholderIndex;
  final List<ProduceProduct> relatedProducts;

  static const _ink = Color(0xFF17251F);
  static const _muted = Color(0xFF727A74);
  static const _imageColors = [
    [Color(0xFFE9D6B5), Color(0xFFD1B58A)],
    [Color(0xFFE1EAD8), Color(0xFFB9C8A8)],
    [Color(0xFFF0DFD2), Color(0xFFD2B4A0)],
    [Color(0xFFE3E6F1), Color(0xFFB7BED5)],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _openDetails(context),
                  child: _buildImage(),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.93),
                      shape: BoxShape.circle,
                    ),
                    child: SaveListButton(
                      product: ProductDetailsProduct(
                        id: product.id,
                        serviceType: 'vegetables_fruits',
                        categoryId: product.categoryId,
                        name: product.name,
                        imageUrl: product.imageUrl,
                        priceInPaise: (product.price * 100).round(),
                        mrpInPaise: (product.mrp * 100).round(),
                        discountPercent: product.discount,
                        quantityLabel: product.packSize,
                        rating: product.rating,
                        available: product.available,
                        icon: product.type == ProduceType.fruit
                            ? Icons.eco_rounded
                            : Icons.grass_rounded,
                        isVegetarian: true,
                      ),
                      size: 15,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: CartProductControl(
                    available: product.available,
                    productId: product.id,
                    serviceType: 'vegetables_fruits',
                    categoryId: product.categoryId,
                    name: product.name,
                    description: '${product.packSize} · ${product.type.name}',
                    priceInPaise: (product.price * 100).round(),
                    imageUrl: product.imageUrl,
                    icon: product.type == ProduceType.fruit
                        ? Icons.eco_rounded
                        : Icons.grass_rounded,
                    width: 96,
                    height: 31,
                    unavailableLabel: 'OUT OF STOCK',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E9E3)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            product.packSize,
            style: const TextStyle(
              color: _ink,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '₹${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            if (product.mrp > product.price)
              Text(
                '₹${product.mrp.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        if (product.discount > 0) ...[
          const SizedBox(height: 2),
          Text(
            '${product.discount}% OFF',
            style: const TextStyle(
              color: Color(0xFF16834A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 2),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDetails(context),
          child: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFF28A36A), size: 12),
            const SizedBox(width: 2),
            Text(
              product.rating.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF328760),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImage() {
    final imageUrl = product.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final colors = _imageColors[placeholderIndex % _imageColors.length];
    final icon = product.type == ProduceType.fruit
        ? Icons.eco_rounded
        : Icons.grass_rounded;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.86),
          size: 43,
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailsPage(
          product: ProductDetailsProduct(
            id: product.id,
            serviceType: 'vegetables_fruits',
            categoryId: product.categoryId,
            name: product.name,
            imageUrl: product.imageUrl,
            priceInPaise: (product.price * 100).round(),
            mrpInPaise: (product.mrp * 100).round(),
            discountPercent: product.discount,
            quantityLabel: product.packSize,
            rating: product.rating,
            available: product.available,
            icon: product.type == ProduceType.fruit
                ? Icons.eco_rounded
                : Icons.grass_rounded,
            isVegetarian: true,
            relatedProducts: relatedProducts
                .map(
                  (related) => ProductDetailsProduct(
                    id: related.id,
                    serviceType: 'vegetables_fruits',
                    categoryId: related.categoryId,
                    name: related.name,
                    imageUrl: related.imageUrl,
                    priceInPaise: (related.price * 100).round(),
                    mrpInPaise: (related.mrp * 100).round(),
                    discountPercent: related.discount,
                    quantityLabel: related.packSize,
                    rating: related.rating,
                    available: related.available,
                    icon: related.type == ProduceType.fruit
                        ? Icons.eco_rounded
                        : Icons.grass_rounded,
                    isVegetarian: true,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
