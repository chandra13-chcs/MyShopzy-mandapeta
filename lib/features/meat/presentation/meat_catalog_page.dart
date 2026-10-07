import 'package:flutter/material.dart';

import '../../cart/presentation/cart_access_button.dart';
import '../../product_details/presentation/product_details_page.dart';

enum MeatType { chicken, mutton }

class MeatCategory {
  const MeatCategory({
    required this.id,
    required this.name,
    required this.type,
    this.imageUrl,
    this.icon = Icons.set_meal_rounded,
  });

  final String id;
  final String name;
  final MeatType type;
  final String? imageUrl;
  final IconData icon;
}

class MeatPartner {
  const MeatPartner({
    required this.id,
    required this.name,
    required this.location,
    required this.distance,
    required this.rating,
    required this.status,
  });

  final String id;
  final String name;
  final String location;
  final String distance;
  final double rating;
  final String status;
}

class MeatProduct {
  const MeatProduct({
    required this.id,
    required this.partnerId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.weight,
    required this.price,
    required this.available,
    required this.type,
    this.imageUrl,
  });

  final String id;
  final String partnerId;
  final String categoryId;
  final String name;
  final String description;
  final String? imageUrl;
  final String weight;
  final double price;
  final bool available;
  final MeatType type;
}

const sampleMeatPartners = [
  MeatPartner(
    id: 'mandapeta-fresh-meats',
    name: 'Mandapeta Fresh Meats',
    location: 'Mandapeta',
    distance: '2.4 km',
    rating: 4.7,
    status: 'Open',
  ),
  MeatPartner(
    id: 'godavari-meat-house',
    name: 'Godavari Meat House',
    location: 'Mandapeta',
    distance: '4.1 km',
    rating: 4.5,
    status: 'Open',
  ),
];

class MeatCatalogPage extends StatelessWidget {
  const MeatCatalogPage({
    required this.title,
    required this.type,
    required this.categories,
    required this.products,
    super.key,
    this.partners = sampleMeatPartners,
  });

  final String title;
  final MeatType type;
  final List<MeatCategory> categories;
  final List<MeatProduct> products;
  final List<MeatPartner> partners;

  static const _ink = Color(0xFF17251F);
  static const _muted = Color(0xFF727A74);
  static const _green = Color(0xFF16834A);
  static const _page = Color(0xFFF7F8F5);

  @override
  Widget build(BuildContext context) {
    final filteredCategories = categories
        .where(
          (category) =>
              category.type == type &&
              products.any((product) => product.categoryId == category.id),
        )
        .toList();

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  const Text(
                    'Fresh cuts from local shops',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPartnerCard(),
                  const SizedBox(height: 16),
                  for (
                    var index = 0;
                    index < filteredCategories.length;
                    index++
                  ) ...[
                    _buildCategorySection(
                      filteredCategories[index],
                      products
                          .where(
                            (product) =>
                                product.categoryId ==
                                filteredCategories[index].id,
                          )
                          .toList(),
                    ),
                    if (index < filteredCategories.length - 1)
                      const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE8EBE6)),
                  minimumSize: const Size(42, 42),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: _green,
                          size: 14,
                        ),
                        SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'Mandapeta, Andhra Pradesh',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3E9),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '25 km',
                  style: TextStyle(
                    color: _green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE5E9E3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: _muted, size: 21),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search ${title.toLowerCase()} products...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard() {
    final activePartnerCount = partners
        .where((partner) => partner.status.toLowerCase() == 'open')
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8EBE6)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: const Color(0xFFF2E7DE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF855A42),
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activePartnerCount local meat shops',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Serving your neighbourhood',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    MeatCategory category,
    List<MeatProduct> categoryProducts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(1, 7, 1, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${categoryProducts.length} item${categoryProducts.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        for (var index = 0; index < categoryProducts.length; index++) ...[
          _MeatProductCard(
            product: categoryProducts[index],
            partner: _partnerFor(categoryProducts[index].partnerId),
            relatedProducts: categoryProducts
                .where(
                  (related) =>
                      related.partnerId == categoryProducts[index].partnerId &&
                      related.categoryId ==
                          categoryProducts[index].categoryId &&
                      related.id != categoryProducts[index].id,
                )
                .toList(),
          ),
          if (index < categoryProducts.length - 1)
            const Divider(
              height: 1,
              color: Color(0xFFE7EAE5),
              indent: 2,
              endIndent: 2,
            ),
        ],
        const SizedBox(height: 7),
      ],
    );
  }

  MeatPartner? _partnerFor(String partnerId) {
    for (final partner in partners) {
      if (partner.id == partnerId) return partner;
    }
    return null;
  }
}

class _MeatProductCard extends StatelessWidget {
  const _MeatProductCard({
    required this.product,
    required this.partner,
    required this.relatedProducts,
  });

  final MeatProduct product;
  final MeatPartner? partner;
  final List<MeatProduct> relatedProducts;

  static const _ink = Color(0xFF17251F);
  static const _muted = Color(0xFF727A74);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDetails(context),
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MeatIndicator(),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                    if (partner != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            color: _muted,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              partner!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFE4A323),
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            partner!.rating.toStringAsFixed(1),
                            style: const TextStyle(color: _muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
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
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2EF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            product.weight,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!product.available) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Currently unavailable',
                        style: TextStyle(
                          color: Color(0xFF9A554A),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 104,
            height: 112,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => _openDetails(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildProductImage(),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  left: 11,
                  right: 11,
                  child: CartProductControl(
                    available: product.available,
                    productId: product.id,
                    serviceType: 'meat',
                    merchantId: product.partnerId,
                    categoryId: product.categoryId,
                    name: product.name,
                    description:
                        '${product.description} · ${product.weight}'
                        '${partner == null ? '' : ' · ${partner!.name}'}',
                    priceInPaise: (product.price * 100).round(),
                    imageUrl: product.imageUrl,
                    icon: Icons.set_meal_rounded,
                    width: 82,
                    height: 33,
                    unavailableLabel: 'OUT OF STOCK',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    final imageUrl = product.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final colors = product.type == MeatType.chicken
        ? const [Color(0xFFEFE0CE), Color(0xFFD8B99C)]
        : const [Color(0xFFEADBD5), Color(0xFFC99E91)];
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(
        Icons.set_meal_rounded,
        size: 39,
        color: Colors.white.withValues(alpha: 0.95),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ProductDetailsPage(product: _toDetails(product, relatedProducts)),
      ),
    );
  }

  ProductDetailsProduct _toDetails(
    MeatProduct item,
    List<MeatProduct> related,
  ) {
    return ProductDetailsProduct(
      id: item.id,
      serviceType: 'meat',
      merchantId: item.partnerId,
      merchantName: partner?.name,
      categoryId: item.categoryId,
      name: item.name,
      description: item.description,
      imageUrl: item.imageUrl,
      priceInPaise: (item.price * 100).round(),
      quantityLabel: item.weight,
      available: item.available,
      icon: Icons.set_meal_rounded,
      isVegetarian: false,
      relatedProducts: related.map((relatedItem) {
        return ProductDetailsProduct(
          id: relatedItem.id,
          serviceType: 'meat',
          merchantId: relatedItem.partnerId,
          merchantName: partner?.name,
          categoryId: relatedItem.categoryId,
          name: relatedItem.name,
          description: relatedItem.description,
          imageUrl: relatedItem.imageUrl,
          priceInPaise: (relatedItem.price * 100).round(),
          quantityLabel: relatedItem.weight,
          available: relatedItem.available,
          icon: Icons.set_meal_rounded,
          isVegetarian: false,
        );
      }).toList(),
    );
  }
}

class _MeatIndicator extends StatelessWidget {
  const _MeatIndicator();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB63E32);
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
