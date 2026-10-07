import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/product_details/data/demo_product_reviews.dart';
import 'package:myshopzy/features/product_details/models/product_review.dart';

void main() {
  group('ProductReviewSummary', () {
    test('calculates average and rating breakdown', () {
      final now = DateTime(2026, 10, 7);
      final reviews = [
        _review('1', 5, now),
        _review('2', 4, now),
        _review('3', 4, now),
        _review('4', 2, now),
      ];

      final summary = ProductReviewSummary.fromReviews(reviews);

      expect(summary.ratingCount, 4);
      expect(summary.averageRating, 3.75);
      expect(summary.countFor(5), 1);
      expect(summary.countFor(4), 2);
      expect(summary.countFor(3), 0);
      expect(summary.countFor(2), 1);
      expect(summary.countFor(1), 0);
    });

    test('returns zero average for no reviews', () {
      final summary = ProductReviewSummary.fromReviews(const []);

      expect(summary.ratingCount, 0);
      expect(summary.averageRating, 0);
      expect(summary.countByRating, [0, 0, 0, 0, 0]);
    });
  });

  group('DemoProductReviews', () {
    test('adds a local review and updates its rating summary', () {
      final reviews = DemoProductReviews();
      final review = reviews.addReview(
        productId: 'product-1',
        serviceType: 'local_store',
        merchantId: 'store-1',
        reviewerName: 'You',
        rating: 5,
        reviewText: '  Great quality  ',
        createdAt: DateTime(2026, 10, 7),
      );

      final productReviews = reviews.reviewsFor(
        productId: 'product-1',
        serviceType: 'local_store',
        merchantId: 'store-1',
      );
      final summary = ProductReviewSummary.fromReviews(productReviews);

      expect(review.reviewText, 'Great quality');
      expect(review.isVerifiedPurchase, isFalse);
      expect(productReviews, [review]);
      expect(summary.ratingCount, 1);
      expect(summary.averageRating, 5);
      expect(summary.countFor(5), 1);
    });

    test('isolates identical product IDs across merchant identity', () {
      final reviews = DemoProductReviews();
      reviews.addReview(
        productId: 'same-id',
        serviceType: 'local_store',
        merchantId: 'store-a',
        reviewerName: 'You',
        rating: 4,
        reviewText: 'Good',
        createdAt: DateTime(2026, 10, 7),
      );

      expect(
        reviews
            .reviewsFor(
              productId: 'same-id',
              serviceType: 'local_store',
              merchantId: 'store-b',
            )
            .isEmpty,
        isTrue,
      );
    });

    test('increments a review helpful count locally', () {
      final reviews = DemoProductReviews();
      final review = reviews.addReview(
        productId: 'product-1',
        serviceType: 'restaurant',
        reviewerName: 'You',
        rating: 4,
        reviewText: 'Tasty',
        createdAt: DateTime(2026, 10, 7),
      );

      reviews.markHelpful(
        productId: 'product-1',
        serviceType: 'restaurant',
        reviewId: review.reviewId,
      );

      expect(
        reviews
            .reviewsFor(productId: 'product-1', serviceType: 'restaurant')
            .single
            .helpfulCount,
        1,
      );
    });
  });
}

ProductReview _review(String id, int rating, DateTime createdAt) {
  return ProductReview(
    reviewId: id,
    productId: 'product-1',
    serviceType: 'restaurant',
    reviewerName: 'Reviewer',
    rating: rating,
    reviewText: 'Sample review',
    createdAt: createdAt,
    isVerifiedPurchase: false,
    helpfulCount: 0,
  );
}
