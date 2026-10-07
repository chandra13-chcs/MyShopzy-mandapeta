import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/product_details/presentation/product_details_page.dart';
import 'package:myshopzy/features/search/data/search_index.dart';
import 'package:myshopzy/features/search/models/search_result.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';

void main() {
  test(
    'normalizes queries and does not return all records for an empty query',
    () {
      expect(SearchIndex.search('  '), isEmpty);

      final results = SearchIndex.search('  sPiCe   rOuTe ');
      expect(
        results.any(
          (result) =>
              result.type == SearchResultType.restaurant &&
              result.displayName == 'Spice Route Kitchen',
        ),
        isTrue,
      );
    },
  );

  test('resolves existing product results to Product Details', () {
    final restaurantItem = SearchIndex.search(
      'chicken dum biryani',
    ).firstWhere((result) => result.type == SearchResultType.restaurantProduct);
    expect(
      SearchIndex.destinationFor(restaurantItem),
      isA<ProductDetailsPage>(),
    );

    final bakeryItem = SearchIndex.search('butter cookies')
        .firstWhere((result) => result.type == SearchResultType.bakeryProduct);
    expect(SearchIndex.destinationFor(bakeryItem), isA<ProductDetailsPage>());

    final storeItem = SearchIndex.search('classic basmati rice')
        .firstWhere((result) => result.type == SearchResultType.storeProduct);
    expect(SearchIndex.destinationFor(storeItem), isA<ProductDetailsPage>());

    final meatItem = SearchIndex.search('mutton keema')
        .firstWhere((result) => result.type == SearchResultType.meatProduct);
    expect(SearchIndex.destinationFor(meatItem), isA<ProductDetailsPage>());

    final produceItem = SearchIndex.search('shimla apples')
        .firstWhere((result) => result.type == SearchResultType.produceProduct);
    expect(SearchIndex.destinationFor(produceItem), isA<ProductDetailsPage>());
  });

  testWidgets(
    'Home search includes discovery products and opens Product Details',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.tap(find.text('Search restaurants, groceries, products...'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Sunflower Oil');
      await tester.pumpAndSettle();

      expect(find.text('Sunflower Oil'), findsNWidgets(2));
      await tester.tap(find.text('Sunflower Oil').last);
      await tester.pumpAndSettle();

      expect(find.byType(ProductDetailsPage), findsOneWidget);
      expect(find.text('Sunflower Oil'), findsOneWidget);
    },
  );
}
