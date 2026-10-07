import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/product_details/data/demo_product_reviews.dart';
import 'package:myshopzy/features/product_details/models/product_details_product.dart';
import 'package:myshopzy/features/reviews/presentation/reviews_page.dart';
import 'package:myshopzy/features/reviews/presentation/write_review_page.dart';

void main() {
  testWidgets('shows product-specific ratings and demo reviews', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ReviewsPage(product: _product())),
    );

    expect(find.text('Fresh Milk Bread'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('3 reviews'), findsOneWidget);
    expect(
      find.text('Great quality and just as described. Would order again.'),
      findsOneWidget,
    );
    expect(find.text('Verified Purchase'), findsNWidgets(2));

    await tester.tap(find.text('Most Relevant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lowest').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Good overall quality and a smooth ordering experience.'),
      findsOneWidget,
    );
  });

  testWidgets('write review adds only to its product in local demo memory', (
    tester,
  ) async {
    final product = _product(id: 'review-screen-test-product');
    final reviewStore = DemoProductReviews.instance;
    final originalCount = reviewStore
        .reviewsFor(
          productId: product.id,
          serviceType: product.serviceType,
          merchantId: product.merchantId,
        )
        .length;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => WriteReviewPage(product: product),
                ),
              ),
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('3 stars'));
    await tester.enterText(find.byType(TextField), 'Fresh and delicious.');
    await tester.ensureVisible(find.text('Submit Review'));
    await tester.tap(find.text('Submit Review'));
    await tester.pumpAndSettle();

    final productReviews = reviewStore.reviewsFor(
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.merchantId,
    );
    expect(productReviews, hasLength(originalCount + 1));
    expect(productReviews.first.rating, 3);
    expect(productReviews.first.reviewText, 'Fresh and delicious.');
    expect(
      find.text('Your review was added locally to this demo.'),
      findsOneWidget,
    );
  });
}

ProductDetailsProduct _product({String id = 'fresh-bread'}) {
  return ProductDetailsProduct(
    id: id,
    serviceType: 'bakery',
    merchantId: 'sri-sai-bakery',
    name: 'Fresh Milk Bread',
    icon: Icons.bakery_dining_rounded,
    available: true,
  );
}
