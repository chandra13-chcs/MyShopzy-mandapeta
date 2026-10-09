import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../product_details/data/demo_product_reviews.dart';
import '../../product_details/models/product_details_product.dart';
import '../../product_details/models/product_review.dart';
import 'review_widgets.dart';
import 'write_review_page.dart';

enum _ReviewSort { relevant, highest, lowest }

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({required this.product, super.key});

  final ProductDetailsProduct product;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  static const _background = AppTheme.lightBackground;
  static const _ink = AppTheme.primaryText;
  static const _green = AppTheme.primaryGreen;
  static const _border = Color(0xFFE5E9E3);

  var _sort = _ReviewSort.relevant;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final reviewStore = DemoProductReviews.instance;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Ratings & Reviews',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: reviewStore,
          builder: (context, child) {
            final reviews = reviewStore.reviewsFor(
              productId: product.id,
              serviceType: product.serviceType,
              merchantId: product.merchantId,
            );
            final summary = ProductReviewSummary.fromReviews(reviews);
            final sortedReviews = [...reviews]..sort(_compareReviews);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local demo reviews · visible only in this demo',
                        style: TextStyle(
                          color: Color(0xFF727A74),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                summary.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              ReviewStars(
                                rating: summary.averageRating.round(),
                                size: 15,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${summary.ratingCount} ${summary.ratingCount == 1 ? 'review' : 'reviews'}',
                                style: const TextStyle(
                                  color: Color(0xFF727A74),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              children: [
                                for (
                                  var rating = 5;
                                  rating >= 1;
                                  rating--
                                )
                                  RatingBreakdownRow(
                                    rating: rating,
                                    count: summary.countFor(rating),
                                    total: summary.ratingCount,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Customer reviews',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    DropdownButton<_ReviewSort>(
                      value: _sort,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _ReviewSort.relevant,
                          child: Text('Most Relevant'),
                        ),
                        DropdownMenuItem(
                          value: _ReviewSort.highest,
                          child: Text('Highest'),
                        ),
                        DropdownMenuItem(
                          value: _ReviewSort.lowest,
                          child: Text('Lowest'),
                        ),
                      ],
                      onChanged: (sort) {
                        if (sort != null) setState(() => _sort = sort);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sortedReviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No reviews yet.')),
                  )
                else
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        for (var index = 0; index < sortedReviews.length; index++)
                          Column(
                            children: [
                              if (index > 0)
                                const Divider(height: 18, color: _border),
                              CustomerReviewCard(
                                review: sortedReviews[index],
                                onHelpful: () => reviewStore.markHelpful(
                                  productId: product.id,
                                  serviceType: product.serviceType,
                                  merchantId: product.merchantId,
                                  reviewId: sortedReviews[index].reviewId,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => WriteReviewPage(product: product),
                    ),
                  ),
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
              ],
            );
          },
        ),
      ),
    );
  }

  int _compareReviews(ProductReview left, ProductReview right) {
    switch (_sort) {
      case _ReviewSort.relevant:
        final helpfulComparison = right.helpfulCount.compareTo(
          left.helpfulCount,
        );
        return helpfulComparison != 0
            ? helpfulComparison
            : right.createdAt.compareTo(left.createdAt);
      case _ReviewSort.highest:
        final ratingComparison = right.rating.compareTo(left.rating);
        return ratingComparison != 0
            ? ratingComparison
            : right.createdAt.compareTo(left.createdAt);
      case _ReviewSort.lowest:
        final ratingComparison = left.rating.compareTo(right.rating);
        return ratingComparison != 0
            ? ratingComparison
            : right.createdAt.compareTo(left.createdAt);
    }
  }
}
