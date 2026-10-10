import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/features/home/presentation/free_delivery_progress_strip.dart';

void main() {
  final cart = CartStore.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  testWidgets('offer banner sits above navigation and uses configured offer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final banner = find.byKey(const ValueKey('free-delivery-offer-banner'));
    final navigation = find.byType(BottomNavigationBar);

    expect(banner, findsOneWidget);
    expect(
      find.byKey(const ValueKey('free-delivery-offer-message')),
      findsOneWidget,
    );
    final message = tester.widget<Text>(
      find.byKey(const ValueKey('free-delivery-offer-message')),
    );
    final messageText = message.textSpan!.toPlainText();
    expect(messageText, 'FREE DELIVERY on orders above ₹199');
    expect(
      tester.getBottomLeft(banner).dy,
      lessThan(tester.getTopLeft(navigation).dy),
    );
  });

  testWidgets('dismissing offer keeps cart contents and subtotal unchanged', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const ValueKey('free-delivery-offer-dismiss')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('free-delivery-offer-banner')),
      findsNothing,
    );
    expect(cart.items, equals(previousItems));
    expect(cart.subtotalInPaise, previousSubtotal);
  });

  testWidgets('offer banner lays out without overflow on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FreeDeliveryOfferBanner(),
          body: SizedBox.expand(),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('free-delivery-offer-banner')))
          .width,
      280,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home navigation and banner fit at 280 logical pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    final navigation = find.byType(BottomNavigationBar);
    final banner = find.byKey(const ValueKey('free-delivery-offer-banner'));
    final bottomNavigationBar = tester.widget<BottomNavigationBar>(navigation);

    expect(bottomNavigationBar.items, hasLength(5));
    expect(bottomNavigationBar.items.map((item) => item.label).toList(), [
      'Home',
      'Categories',
      '',
      'Orders',
      'Profile',
    ]);
    expect(
      tester.getBottomLeft(banner).dy,
      lessThan(tester.getTopLeft(navigation).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
