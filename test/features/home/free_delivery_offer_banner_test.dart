import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';

void main() {
  final cart = CartStore.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  testWidgets('Home does not render free-delivery messaging', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.byKey(const ValueKey('free-delivery-offer-banner')), findsNothing);
    expect(find.byKey(const ValueKey('free-delivery-progress-strip')), findsNothing);
  });

  testWidgets('Home leaves existing cart contents unchanged', (tester) async {
    cart.addItem(
      productId: 'banner-cart-item',
      serviceType: 'local_store',
      merchantId: 'banner-test-store',
      name: 'Banner cart item',
      description: '',
      priceInPaise: 15400,
      icon: Icons.shopping_bag_outlined,
    );
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final previousItems = cart.items;
    final previousSubtotal = cart.subtotalInPaise;
    await tester.pumpAndSettle();
    expect(cart.items, equals(previousItems));
    expect(cart.subtotalInPaise, previousSubtotal);
  });

  testWidgets('home navigation fits at 280 logical pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    final navigation = find.byType(BottomNavigationBar);
    final bottomNavigationBar = tester.widget<BottomNavigationBar>(navigation);

    expect(bottomNavigationBar.items, hasLength(5));
    expect(bottomNavigationBar.items.map((item) => item.label).toList(), [
      'Home',
      'Categories',
      '',
      'Orders',
      'Profile',
    ]);
    expect(find.byKey(const ValueKey('free-delivery-offer-banner')), findsNothing);
    expect(find.byKey(const ValueKey('free-delivery-progress-strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
