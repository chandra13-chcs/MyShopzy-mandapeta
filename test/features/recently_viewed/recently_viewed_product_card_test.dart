import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/product_details/models/product_details_product.dart';
import 'package:myshopzy/features/recently_viewed/presentation/recently_viewed_product_card.dart';
import 'package:myshopzy/shared/presentation/press_scale_feedback.dart';

void main() {
  testWidgets('dietary label only appears when product data includes it', (
    tester,
  ) async {
    await tester.pumpWidget(_card(isVegetarian: true));
    expect(find.text('Veg'), findsOneWidget);
    expect(find.text('Non-Veg'), findsNothing);

    await tester.pumpWidget(_card(isVegetarian: false));
    expect(find.text('Non-Veg'), findsOneWidget);
    expect(find.text('Veg'), findsNothing);

    await tester.pumpWidget(_card());
    expect(find.text('Veg'), findsNothing);
    expect(find.text('Non-Veg'), findsNothing);
  });

  testWidgets('product card scales on press without changing its layout', (
    tester,
  ) async {
    await tester.pumpWidget(_card(isVegetarian: true));
    final card = find.byType(RecentlyViewedProductCard);
    final initialSize = tester.getSize(card);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 60));

    final pressFeedback = find.descendant(
      of: card,
      matching: find.byType(PressScaleFeedback),
    );
    final scale = tester.widget<AnimatedScale>(
      find.descendant(of: pressFeedback, matching: find.byType(AnimatedScale)),
    );
    expect(scale.scale, lessThan(1));
    expect(tester.getSize(card), initialSize);

    await gesture.cancel();
    await tester.pumpAndSettle();
  });
}

Widget _card({bool? isVegetarian}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          height: 190,
          child: RecentlyViewedProductCard(
            width: 138,
            product: ProductDetailsProduct(
              id: 'dietary-test',
              serviceType: 'restaurant',
              name: 'Sample product',
              icon: Icons.restaurant,
              available: true,
              priceInPaise: 10000,
              isVegetarian: isVegetarian,
            ),
          ),
        ),
      ),
    ),
  );
}
