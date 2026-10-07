import 'package:flutter/material.dart';

import '../../cart/presentation/cart_access_button.dart';
import '../data/demo_product_reviews.dart';
import '../data/product_availability_store.dart';
import '../data/recently_viewed_store.dart';
import '../models/product_details_product.dart';
import '../models/product_review.dart';
import '../../reviews/presentation/reviews_page.dart';
import '../../reviews/presentation/review_widgets.dart';
import '../../reviews/presentation/write_review_page.dart';

export '../models/product_details_product.dart';

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({required this.product, super.key});

  final ProductDetailsProduct product;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  static const _ink = Color(0xFF17251F);
  static const _muted = Color(0xFF727A74);
  static const _green = Color(0xFF16834A);
  static const _page = Color(0xFFF7F8F5);
  static const _border = Color(0xFFE5E9E3);

  bool _isWishlisted = false;
  bool _isDescriptionExpanded = true;

  @override
  void initState() {
    super.initState();
    RecentlyViewedStore.instance.addViewedProduct(widget.product);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        foregroundColor: _ink,
        surfaceTintColor: _page,
        title: const Text(
          'Product Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isWishlisted = !_isWishlisted),
            tooltip: _isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
            icon: Icon(
              _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border,
              color: _isWishlisted ? const Color(0xFFB6534B) : _ink,
            ),
          ),
          IconButton(
            onPressed: () =>
                _showDemoMessage('Sharing is unavailable in this demo.'),
            tooltip: 'Share product',
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(product),
              const SizedBox(height: 18),
              _buildProductInformation(product),
              const SizedBox(height: 16),
              _buildPrice(product),
              const SizedBox(height: 16),
              if (product.description?.isNotEmpty ?? false) ...[
                _buildDescription(product.description!),
                const SizedBox(height: 16),
              ],
              if (product.rating != null) ...[
                _buildRating(product.rating!),
                const SizedBox(height: 16),
              ],
              if (product.merchantName != null) ...[
                _buildMerchant(product.merchantName!),
                const SizedBox(height: 16),
              ],
              _buildReviewsSection(product),
              const SizedBox(height: 16),
              if (product.relatedProducts.isNotEmpty)
                _buildRelatedProducts(product.relatedProducts),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: AnimatedBuilder(
            animation: ProductAvailabilityStore.instance,
            builder: (context, child) {
              final isAvailable = ProductAvailabilityStore.instance
                  .isAvailable(
                    productId: product.id,
                    serviceType: product.serviceType,
                    merchantId: product.merchantId,
                    defaultAvailable: product.available,
                  );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isAvailable) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Color(0xFF9A554A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (product.priceInPaise == null)
                    _unavailablePriceAction()
                  else
                    CartProductControl(
                      available: product.available,
                      productId: product.id,
                      serviceType: product.serviceType,
                      merchantId: product.merchantId,
                      categoryId: product.categoryId,
                      name: product.name,
                      description: _cartDescription(product),
                      priceInPaise: product.priceInPaise!,
                      imageUrl: product.imageUrl,
                      icon: product.icon,
                      width: double.infinity,
                      height: 48,
                      unavailableLabel: 'OUT OF STOCK',
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(ProductDetailsProduct product) {
    return Container(
      height: 270,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1E8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? Image.network(
              product.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildImagePlaceholder(product),
            )
          : _buildImagePlaceholder(product),
    );
  }

  Widget _buildImagePlaceholder(ProductDetailsProduct product) {
    final vegetarian = product.isVegetarian;
    final colors = vegetarian == false
        ? const [Color(0xFFF0DFD2), Color(0xFFD3B39B)]
        : const [Color(0xFFE2EEDB), Color(0xFFBDCFB3)];
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
          product.icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 82,
        ),
      ),
    );
  }

  Widget _buildProductInformation(ProductDetailsProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.isVegetarian != null) ...[
          _FoodTypeIndicator(isVegetarian: product.isVegetarian!),
          const SizedBox(height: 10),
        ],
        Text(
          product.name,
          style: const TextStyle(
            color: _ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        if (product.brand != null && product.brand!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            product.brand!,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (product.quantityLabel != null &&
            product.quantityLabel!.isNotEmpty) ...[
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Text(
              product.quantityLabel!,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrice(ProductDetailsProduct product) {
    if (product.priceInPaise == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Text(
            _formatPrice(product.priceInPaise!),
            style: const TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (product.mrpInPaise != null &&
              product.mrpInPaise! > product.priceInPaise!) ...[
            const SizedBox(width: 9),
            Text(
              _formatPrice(product.mrpInPaise!),
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
          const Spacer(),
          if (product.discountPercent != null && product.discountPercent! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F3E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${product.discountPercent}% OFF',
                style: const TextStyle(
                  color: _green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        onExpansionChanged: (expanded) =>
            setState(() => _isDescriptionExpanded = expanded),
        title: const Text(
          'About this product',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: Icon(
          _isDescriptionExpanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: _muted,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRating(double rating) {
    return _DetailsCard(
      title: 'Customer rating',
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFE4A323), size: 23),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchant(String merchantName) {
    return _DetailsCard(
      title: 'Sold by',
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: _green, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              merchantName,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts(List<ProductDetailsProduct> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Related Products',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 174,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                _RelatedProductCard(product: products[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(ProductDetailsProduct product) {
    final reviewStore = DemoProductReviews.instance;
    return AnimatedBuilder(
      animation: reviewStore,
      builder: (context, child) {
        final reviews = reviewStore.reviewsFor(
          productId: product.id,
          serviceType: product.serviceType,
          merchantId: product.merchantId,
        );
        final summary = ProductReviewSummary.fromReviews(reviews);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ratings & Reviews',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openReviews(product),
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('View all reviews'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local demo reviews · not shared',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  if (reviews.isEmpty)
                    const _NoReviewsYet()
                  else ...[
                    _RatingOverview(summary: summary),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: _border),
                    const SizedBox(height: 13),
                    for (var rating = 5; rating >= 1; rating--)
                      RatingBreakdownRow(
                        rating: rating,
                        count: summary.countFor(rating),
                        total: summary.ratingCount,
                      ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openWriteReview(product),
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: const Text('Write a Review'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _green),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  if (reviews.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (
                      var index = 0;
                      index < reviews.length && index < 2;
                      index++
                    ) ...[
                      if (index > 0)
                        const Divider(height: 22, color: _border),
                      CustomerReviewCard(
                        review: reviews[index],
                        onHelpful: () => reviewStore.markHelpful(
                          productId: product.id,
                          serviceType: product.serviceType,
                          merchantId: product.merchantId,
                          reviewId: reviews[index].reviewId,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openReviews(ProductDetailsProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReviewsPage(product: product),
      ),
    );
  }

  void _openWriteReview(ProductDetailsProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WriteReviewPage(product: product),
      ),
    );
  }

  Widget _unavailablePriceAction() {
    return const SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(onPressed: null, child: Text('PRICE UNAVAILABLE')),
    );
  }

  String _cartDescription(ProductDetailsProduct product) {
    return [
      product.brand,
      product.quantityLabel,
      product.description,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
  }

  String _formatPrice(int priceInPaise) {
    final rupees = priceInPaise ~/ 100;
    final paise = priceInPaise % 100;
    return paise == 0
        ? '₹$rupees'
        : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }

  void _showDemoMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NoReviewsYet extends StatelessWidget {
  const _NoReviewsYet();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, color: Color(0xFF8A948C), size: 34),
          SizedBox(height: 7),
          Text(
            'No reviews yet',
            style: TextStyle(
              color: Color(0xFF17251F),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Be the first to review this product',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF727A74), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RatingOverview extends StatelessWidget {
  const _RatingOverview({required this.summary});

  final ProductReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              summary.averageRating.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF17251F),
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            const ReviewStars(rating: 5, size: 15),
            const SizedBox(height: 4),
            Text(
              '${summary.ratingCount} ${summary.ratingCount == 1 ? 'rating' : 'ratings'}',
              style: const TextStyle(color: Color(0xFF727A74), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(width: 17),
        Expanded(
          child: Text(
            'Average from local demo reviews',
            style: const TextStyle(
              color: Color(0xFF727A74),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17251F),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RelatedProductCard extends StatelessWidget {
  const _RelatedProductCard({required this.product});

  final ProductDetailsProduct product;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
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
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      width: double.infinity,
                      child:
                          product.imageUrl == null || product.imageUrl!.isEmpty
                          ? ColoredBox(
                              color: const Color(0xFFEAF1E8),
                              child: Icon(
                                product.icon,
                                color: const Color(0xFF397447),
                                size: 35,
                              ),
                            )
                          : Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  ColoredBox(
                                    color: const Color(0xFFEAF1E8),
                                    child: Icon(
                                      product.icon,
                                      color: const Color(0xFF397447),
                                      size: 35,
                                    ),
                                  ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17251F),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (product.priceInPaise != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '₹${(product.priceInPaise! / 100).toStringAsFixed(product.priceInPaise! % 100 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                      color: Color(0xFF17251F),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodTypeIndicator extends StatelessWidget {
  const _FoodTypeIndicator({required this.isVegetarian});

  final bool isVegetarian;

  @override
  Widget build(BuildContext context) {
    final color = isVegetarian
        ? const Color(0xFF16834A)
        : const Color(0xFFB63E32);
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
