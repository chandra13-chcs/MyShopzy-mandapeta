import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';

void main() {
  final cart = CartStore.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  test('an empty cart accepts the first valid product', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(cart.items, hasLength(1));
  });

  test('products from the same restaurant can coexist', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(
      _add(cart, 'restaurant', 'starter', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(cart.items, hasLength(2));
  });

  test('products from different restaurants cannot mix', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(
      _add(cart, 'restaurant', 'pizza', merchantId: 'restaurant-b'),
      isFalse,
    );
  });

  test('products from the same bakery can coexist', () {
    expect(_add(cart, 'bakery', 'bread', merchantId: 'bakery-a'), isTrue);
    expect(_add(cart, 'bakery', 'cake', merchantId: 'bakery-a'), isTrue);
  });

  test('products from different bakeries cannot mix', () {
    expect(_add(cart, 'bakery', 'bread', merchantId: 'bakery-a'), isTrue);
    expect(_add(cart, 'bakery', 'cake', merchantId: 'bakery-b'), isFalse);
  });

  test('products from the same Local Store can coexist', () {
    expect(_add(cart, 'local_store', 'rice', merchantId: 'store-a'), isTrue);
    expect(_add(cart, 'local_store', 'noodles', merchantId: 'store-a'), isTrue);
  });

  test('products from different Local Stores cannot mix', () {
    expect(_add(cart, 'local_store', 'rice', merchantId: 'store-a'), isTrue);
    expect(_add(cart, 'local_store', 'rice', merchantId: 'store-b'), isFalse);
  });

  test('vegetable products can coexist', () {
    expect(
      _add(cart, 'vegetables_fruits', 'carrot', serviceVariant: 'vegetable'),
      isTrue,
    );
    expect(
      _add(cart, 'vegetables_fruits', 'tomato', serviceVariant: 'vegetable'),
      isTrue,
    );
  });

  test('vegetables cannot mix with fruits', () {
    expect(
      _add(cart, 'vegetables_fruits', 'carrot', serviceVariant: 'vegetable'),
      isTrue,
    );
    expect(
      _add(cart, 'vegetables_fruits', 'apple', serviceVariant: 'fruit'),
      isFalse,
    );
  });

  test('fruit products can coexist', () {
    expect(
      _add(cart, 'vegetables_fruits', 'apple', serviceVariant: 'fruit'),
      isTrue,
    );
    expect(
      _add(cart, 'vegetables_fruits', 'banana', serviceVariant: 'fruit'),
      isTrue,
    );
  });

  test('fruits cannot mix with vegetables', () {
    expect(
      _add(cart, 'vegetables_fruits', 'apple', serviceVariant: 'fruit'),
      isTrue,
    );
    expect(
      _add(cart, 'vegetables_fruits', 'potato', serviceVariant: 'vegetable'),
      isFalse,
    );
  });

  test('chicken products from the same source can coexist', () {
    expect(
      _add(cart, 'meat', 'curry-cuts', merchantId: 'meat-source-a'),
      isTrue,
    );
    expect(_add(cart, 'meat', 'boneless', merchantId: 'meat-source-a'), isTrue);
  });

  test('chicken cannot mix with restaurant products', () {
    expect(
      _add(cart, 'meat', 'curry-cuts', merchantId: 'meat-source-a'),
      isTrue,
    );
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isFalse,
    );
  });

  test('chicken cannot mix with grocery products', () {
    expect(
      _add(cart, 'meat', 'curry-cuts', merchantId: 'meat-source-a'),
      isTrue,
    );
    expect(_add(cart, 'local_store', 'rice', merchantId: 'store-a'), isFalse);
  });

  test('bakery cannot mix with restaurant products', () {
    expect(_add(cart, 'bakery', 'bread', merchantId: 'bakery-a'), isTrue);
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isFalse,
    );
  });

  test('restaurant cannot mix with grocery products', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(_add(cart, 'local_store', 'rice', merchantId: 'store-a'), isFalse);
  });

  test('a rejected addition leaves existing cart contents unchanged', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );

    expect(_add(cart, 'bakery', 'bread', merchantId: 'bakery-a'), isFalse);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.productId, 'biryani');
  });

  test('a different context is accepted after the cart is emptied', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    cart.clear();

    expect(_add(cart, 'bakery', 'bread', merchantId: 'bakery-a'), isTrue);
    expect(cart.items.single.serviceType, 'bakery');
  });

  test('adding and incrementing compatible products preserves quantity', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(cart.items.single.quantity, 2);

    expect(cart.increaseQuantity(cart.items.single.key), isTrue);
    expect(cart.items.single.quantity, 3);
  });

  test('decrement and remove retain their existing behavior', () {
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    expect(
      _add(cart, 'restaurant', 'biryani', merchantId: 'restaurant-a'),
      isTrue,
    );
    final key = cart.items.single.key;

    cart.decreaseQuantity(key);
    expect(cart.items.single.quantity, 1);
    cart.removeItem(key);
    expect(cart.items, isEmpty);
  });

  test('quantity changes and removal recalculate the cart subtotal', () {
    _add(
      cart,
      'local_store',
      'rice',
      merchantId: 'store-a',
      priceInPaise: 15400,
    );
    final key = cart.items.single.key;

    expect(cart.subtotalInPaise, 15400);
    expect(cart.increaseQuantity(key), isTrue);
    expect(cart.subtotalInPaise, 30800);

    cart.decreaseQuantity(key);
    expect(cart.subtotalInPaise, 15400);
    cart.decreaseQuantity(key);
    expect(cart.items.single.quantity, 1);
    expect(cart.subtotalInPaise, 15400);

    cart.removeItem(key);
    expect(cart.items, isEmpty);
    expect(cart.subtotalInPaise, 0);
  });

  test('cart listeners receive changes only when cart state changes', () {
    var notifications = 0;
    void listener() => notifications++;
    cart.addListener(listener);
    addTearDown(() => cart.removeListener(listener));

    _add(cart, 'local_store', 'rice', merchantId: 'store-a');
    final key = cart.items.single.key;
    cart.decreaseQuantity(key);
    cart.increaseQuantity(key);
    cart.removeItem(key);
    cart.removeItem(key);

    expect(notifications, 3);
  });
}

bool _add(
  CartStore cart,
  String serviceType,
  String productId, {
  String? merchantId,
  String? serviceVariant,
  int priceInPaise = 1000,
}) {
  return cart.addItem(
    productId: productId,
    serviceType: serviceType,
    merchantId: merchantId,
    serviceVariant: serviceVariant,
    name: productId,
    description: 'Demo item',
    priceInPaise: priceInPaise,
    icon: Icons.shopping_bag_outlined,
  );
}
