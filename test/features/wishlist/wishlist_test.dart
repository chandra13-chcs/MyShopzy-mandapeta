import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/product_details/models/product_details_product.dart';
import 'package:myshopzy/features/wishlist/data/wishlist_store.dart';
import 'package:myshopzy/features/wishlist/presentation/save_list_button.dart';
import 'package:myshopzy/features/wishlist/presentation/wishlist_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  final wishlist = WishlistStore.instance;

  tearDown(() {
    wishlist.clear();
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('wishlist access requires a customer session', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));

    expect(find.text('Sign in to access your wishlist.'), findsOneWidget);
    expect(find.text('Your Wishlist is empty'), findsNothing);
  });

  testWidgets('saving a product while signed out does not create local data', (
    tester,
  ) async {
    final product = ProductDetailsProduct(
      id: 'product-1',
      serviceType: 'local_store',
      name: 'Product',
      icon: Icons.inventory_2_outlined,
      available: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaveListButton(product: product)),
      ),
    );

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pump();

    expect(wishlist.products, isEmpty);
    expect(find.text('Sign in to manage your wishlist.'), findsOneWidget);
  });

  testWidgets('development preview saves wishlist items locally only', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = CustomerApi(
      baseUrl: 'https://shop.example',
      enableDevelopmentPreview: true,
      enableDevelopmentGuestCart: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 500);
      }),
    );
    CustomerApi.instance.close();
    CustomerApi.instance = api;
    addTearDown(api.close);

    await tester.pumpWidget(const MaterialApp(home: WishlistPage()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to access your wishlist.'), findsNothing);
    expect(find.text('Your Wishlist is empty'), findsOneWidget);

    final product = ProductDetailsProduct(
      id: 'backend-product-1',
      serviceType: 'catalog',
      name: 'Preview Product',
      icon: Icons.inventory_2_outlined,
      available: true,
      isBackendProduct: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaveListButton(product: product)),
      ),
    );

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pumpAndSettle();

    expect(wishlist.products, hasLength(1));
    expect(wishlist.contains(product), isTrue);
    expect(wishlist.products.single.isBackendProduct, isTrue);
    expect(requests, isEmpty);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();

    expect(wishlist.products, isEmpty);
    expect(requests, isEmpty);
  });
}
