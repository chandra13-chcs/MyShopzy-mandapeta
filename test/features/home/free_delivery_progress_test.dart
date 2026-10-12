import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/app/config/delivery_offer_config.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/cart/presentation/cart_page.dart';

void main() {
  final cartStore = CartStore.instance;

  setUp(cartStore.clear);
  tearDown(cartStore.clear);

  test(
    'delivery offer uses the configured threshold and eligible subtotal',
    () {
      expect(DeliveryOfferConfig.thresholdInPaise, 19900);
      expect(
        DeliveryOfferConfig.messageForSubtotal(15400),
        'Add ₹45 more to unlock FREE DELIVERY',
      );
      expect(
        DeliveryOfferConfig.messageForSubtotal(18000),
        'Add ₹19 more to unlock FREE DELIVERY',
      );
      expect(
        DeliveryOfferConfig.messageForSubtotal(19900),
        'Free delivery unlocked!',
      );
      expect(
        DeliveryOfferConfig.messageForSubtotal(25000),
        'Free delivery unlocked!',
      );
    },
  );

  testWidgets('cart free-delivery progress follows cart quantity changes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CartPage()));

    expect(
      find.text('Add ₹199 more to unlock FREE DELIVERY'),
      findsOneWidget,
    );
    cartStore.addItem(
      productId: 'eligible-item',
      serviceType: 'store',
      name: 'Eligible item',
      description: '',
      priceInPaise: 7000,
      icon: Icons.shopping_bag_outlined,
    );
    await tester.pump();
    expect(
      find.text('Add ₹129 more to unlock FREE DELIVERY'),
      findsOneWidget,
    );

    final key = CartItem.keyFor(
      serviceType: 'store',
      productId: 'eligible-item',
    );
    cartStore.increaseQuantity(key);
    await tester.pump();
    expect(
      find.text('Add ₹59 more to unlock FREE DELIVERY'),
      findsOneWidget,
    );

    cartStore.increaseQuantity(key);
    await tester.pump();
    expect(find.text('Free delivery unlocked!'), findsOneWidget);

    cartStore.decreaseQuantity(key);
    await tester.pump();
    expect(
      find.text('Add ₹59 more to unlock FREE DELIVERY'),
      findsOneWidget,
    );

    cartStore.decreaseQuantity(key);
    await tester.pump();
    expect(
      find.text('Add ₹129 more to unlock FREE DELIVERY'),
      findsOneWidget,
    );

    cartStore.removeItem(key);
    await tester.pump();
    expect(
      find.text('Add ₹199 more to unlock FREE DELIVERY'),
      findsOneWidget,
    );
  });
}
