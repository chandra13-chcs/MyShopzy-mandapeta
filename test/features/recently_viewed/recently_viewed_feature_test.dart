import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/product_details/data/recently_viewed_store.dart';
import 'package:myshopzy/features/product_details/models/product_details_product.dart';
import 'package:myshopzy/features/recently_viewed/presentation/recently_viewed_page.dart';

void main() {
  final history = RecentlyViewedStore.instance;

  setUp(() {
    history.clear();
  });

  tearDown(() {
    history.clear();
  });

  testWidgets('Home hides Recently Viewed while history is empty', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('Recently Viewed'), findsNothing);
    expect(find.text('View All'), findsNothing);
  });

  testWidgets('Home shows View All when enough viewed products exist', (
    tester,
  ) async {
    for (var index = 0; index < 4; index++) {
      history.addViewedProduct(_product('home-view-$index'));
    }

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View All'));
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();

    expect(find.byType(RecentlyViewedPage), findsOneWidget);
    expect(find.text('Recently Viewed'), findsOneWidget);
    expect(find.text('Home Product 0'), findsOneWidget);
  });

  testWidgets('Clear All requires confirmation and clears local history', (
    tester,
  ) async {
    history.addViewedProduct(_product('clear-test-product'));

    await tester.pumpWidget(const MaterialApp(home: RecentlyViewedPage()));
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(history.products, hasLength(1));
    expect(find.text('Clear recently viewed?'), findsOneWidget);
    await tester.tap(find.text('Clear All').last);
    await tester.pumpAndSettle();

    expect(history.products, isEmpty);
    expect(find.text('No recently viewed products'), findsOneWidget);
    expect(find.text('Clear All'), findsNothing);
  });
}

ProductDetailsProduct _product(String id) {
  return ProductDetailsProduct(
    id: id,
    serviceType: 'local_store',
    merchantId: 'demo-store',
    name: 'Home Product ${id.split('-').last}',
    icon: Icons.inventory_2_rounded,
    available: true,
    priceInPaise: 12900,
  );
}
