import 'package:flutter/foundation.dart';

import '../models/product_review.dart';

class DemoProductReviews extends ChangeNotifier {
  DemoProductReviews();

  static final instance = DemoProductReviews();

  static const _seededDemoProductKeys = {
    'restaurant:spice-route:chicken-dum-biryani',
    'bakery:sri-sai-bakery:fresh-bread',
  };

  final Map<String, List<ProductReview>> _reviewsByProduct = {};
  var _nextReviewId = 0;

  List<ProductReview> reviewsFor({
    required String productId,
    required String serviceType,
    String? merchantId,
  }) {
    final key = _key(
      productId: productId,
      serviceType: serviceType,
      merchantId: merchantId,
    );
    final reviews = _reviewsByProduct.putIfAbsent(key, () {
      if (!_seededDemoProductKeys.contains(key)) return <ProductReview>[];
      return _demoReviews(
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
      );
    });
    return List<ProductReview>.unmodifiable(reviews);
  }

  ProductReview addReview({
    required String productId,
    required String serviceType,
    required String reviewerName,
    required int rating,
    required String reviewText,
    required DateTime createdAt,
    String? merchantId,
  }) {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Must be between 1 and 5.');
    }
    final normalizedText = reviewText.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(reviewText, 'reviewText', 'Cannot be empty.');
    }
    final review = ProductReview(
      reviewId:
          'demo-review-${createdAt.microsecondsSinceEpoch}-${_nextReviewId++}',
      productId: productId,
      serviceType: serviceType,
      merchantId: merchantId,
      reviewerName: reviewerName,
      rating: rating,
      reviewText: normalizedText,
      createdAt: createdAt,
      isVerifiedPurchase: false,
      helpfulCount: 0,
    );
    final key = _key(
      productId: productId,
      serviceType: serviceType,
      merchantId: merchantId,
    );
    _reviewsByProduct.putIfAbsent(key, () => []).insert(0, review);
    notifyListeners();
    return review;
  }

  void markHelpful({
    required String productId,
    required String serviceType,
    required String reviewId,
    String? merchantId,
  }) {
    final reviews =
        _reviewsByProduct[_key(
          productId: productId,
          serviceType: serviceType,
          merchantId: merchantId,
        )];
    if (reviews == null) return;
    final index = reviews.indexWhere((review) => review.reviewId == reviewId);
    if (index == -1) return;
    reviews[index] = reviews[index].copyWith(
      helpfulCount: reviews[index].helpfulCount + 1,
    );
    notifyListeners();
  }

  String _key({
    required String productId,
    required String serviceType,
    String? merchantId,
  }) {
    return '$serviceType:${merchantId ?? ''}:$productId';
  }

  List<ProductReview> _demoReviews({
    required String productId,
    required String serviceType,
    String? merchantId,
  }) {
    return [
      ProductReview(
        reviewId: 'demo-$productId-1',
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        reviewerName: 'Ananya R.',
        rating: 5,
        reviewText: 'Great quality and just as described. Would order again.',
        createdAt: DateTime(2026, 9, 24),
        isVerifiedPurchase: true,
        helpfulCount: 8,
      ),
      ProductReview(
        reviewId: 'demo-$productId-2',
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        reviewerName: 'Karthik M.',
        rating: 5,
        reviewText:
            'Really good value for the price. Arrived in great condition.',
        createdAt: DateTime(2026, 9, 17),
        isVerifiedPurchase: true,
        helpfulCount: 4,
      ),
      ProductReview(
        reviewId: 'demo-$productId-3',
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        reviewerName: 'Meera S.',
        rating: 4,
        reviewText: 'Good overall quality and a smooth ordering experience.',
        createdAt: DateTime(2026, 9, 9),
        isVerifiedPurchase: false,
        helpfulCount: 2,
      ),
    ];
  }
}
