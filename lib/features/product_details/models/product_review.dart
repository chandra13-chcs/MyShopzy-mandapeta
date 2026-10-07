class ProductReview {
  const ProductReview({
    required this.reviewId,
    required this.productId,
    required this.serviceType,
    required this.reviewerName,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    required this.isVerifiedPurchase,
    required this.helpfulCount,
    this.merchantId,
  });

  final String reviewId;
  final String productId;
  final String serviceType;
  final String? merchantId;
  final String reviewerName;
  final int rating;
  final String reviewText;
  final DateTime createdAt;
  final bool isVerifiedPurchase;
  final int helpfulCount;

  ProductReview copyWith({int? helpfulCount}) {
    return ProductReview(
      reviewId: reviewId,
      productId: productId,
      serviceType: serviceType,
      merchantId: merchantId,
      reviewerName: reviewerName,
      rating: rating,
      reviewText: reviewText,
      createdAt: createdAt,
      isVerifiedPurchase: isVerifiedPurchase,
      helpfulCount: helpfulCount ?? this.helpfulCount,
    );
  }
}

class ProductReviewSummary {
  const ProductReviewSummary({
    required this.ratingCount,
    required this.averageRating,
    required this.countByRating,
  });

  factory ProductReviewSummary.fromReviews(List<ProductReview> reviews) {
    final counts = List<int>.filled(5, 0);
    var total = 0;
    for (final review in reviews) {
      if (review.rating < 1 || review.rating > 5) continue;
      counts[review.rating - 1]++;
      total += review.rating;
    }
    return ProductReviewSummary(
      ratingCount: counts.fold(0, (count, value) => count + value),
      averageRating: counts.fold(0, (count, value) => count + value) == 0
          ? 0
          : total / counts.fold(0, (count, value) => count + value),
      countByRating: List<int>.unmodifiable(counts),
    );
  }

  final int ratingCount;
  final double averageRating;
  final List<int> countByRating;

  int countFor(int rating) => countByRating[rating - 1];
}
