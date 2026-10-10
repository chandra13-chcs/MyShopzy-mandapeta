import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_access_button.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';
import 'package:myshopzy/features/product_details/data/product_availability_store.dart';

void main() {
  final availabilityStore = ProductAvailabilityStore.instance;
  final cartStore = CartStore.instance;

  setUp(() {
    availabilityStore.clearOverrides();
    cartStore.clear();
  });

  tearDown(() {
    availabilityStore.clearOverrides();
    cartStore.clear();
  });

  test('uses existing availability unless a local override is set', () {
    expect(
      availabilityStore.isAvailable(
        productId: 'product-1',
        serviceType: 'store',
        merchantId: 'store-1',
        defaultAvailable: false,
      ),
      isFalse,
    );

    availabilityStore.setAvailability(
      productId: 'product-1',
      serviceType: 'store',
      merchantId: 'store-1',
      isAvailable: true,
    );

    expect(
      availabilityStore.isAvailable(
        productId: 'product-1',
        serviceType: 'store',
        merchantId: 'store-1',
        defaultAvailable: false,
      ),
      isTrue,
    );
    expect(
      availabilityStore.isAvailable(
        productId: 'product-1',
        serviceType: 'store',
        merchantId: 'store-2',
        defaultAvailable: false,
      ),
      isFalse,
    );
    expect(
      availabilityStore.isAvailable(
        productId: 'product-1',
        serviceType: 'store',
        merchantId: 'store-1',
        defaultAvailable: true,
      ),
      isTrue,
    );

    availabilityStore.setAvailability(
      productId: 'product-1',
      serviceType: 'store',
      merchantId: 'store-1',
      isAvailable: false,
    );
    expect(
      availabilityStore.isAvailable(
        productId: 'product-1',
        serviceType: 'store',
        merchantId: 'store-1',
        variantId: 'variant-1',
        defaultAvailable: true,
      ),
      isTrue,
      reason: 'A product override must not replace a variant default.',
    );
  });

  testWidgets('product cart control blocks out-of-stock additions', (
    tester,
  ) async {
    availabilityStore.setAvailability(
      productId: 'product-1',
      serviceType: 'store',
      merchantId: 'store-1',
      isAvailable: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CartProductControl(
              productId: 'product-1',
              serviceType: 'store',
              merchantId: 'store-1',
              name: 'Sample product',
              description: 'Sample description',
              priceInPaise: 1000,
              icon: Icons.shopping_bag_outlined,
              available: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('OUT OF STOCK'), findsOneWidget);
    await tester.tap(find.text('OUT OF STOCK'));
    await tester.pump();
    expect(cartStore.totalQuantity, 0);
  });

  testWidgets('cart blocks out-of-stock increases but permits decreases', (
    tester,
  ) async {
    cartStore.addItem(
      productId: 'product-1',
      serviceType: 'store',
      merchantId: 'store-1',
      name: 'Sample product',
      description: 'Sample description',
      priceInPaise: 1000,
      icon: Icons.shopping_bag_outlined,
    );
    cartStore.increaseQuantity('store:store-1:product-1');
    availabilityStore.setAvailability(
      productId: 'product-1',
      serviceType: 'store',
      merchantId: 'store-1',
      isAvailable: false,
    );

    await tester.pumpWidget(const MaterialApp(home: CartPage()));
    expect(find.text('Out of Stock'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(cartStore.totalQuantity, 2);
    expect(
      find.text('This product is currently out of stock.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pump();
    expect(cartStore.totalQuantity, 1);
  });
}
