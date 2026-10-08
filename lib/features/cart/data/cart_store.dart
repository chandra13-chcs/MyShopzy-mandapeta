import 'package:flutter/material.dart';

import '../models/cart_order_context.dart';

class CartStore extends ChangeNotifier {
  CartStore._();

  static final instance = CartStore._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalQuantity =>
      _items.fold(0, (total, item) => total + item.quantity);

  int get subtotalInPaise => _items.fold(
    0,
    (total, item) => total + item.priceInPaise * item.quantity,
  );

  int quantityFor({
    required String productId,
    required String serviceType,
    String? merchantId,
    String? serviceVariant,
    String? productVariantId,
  }) {
    final key = CartItem.keyFor(
      serviceType: serviceType,
      merchantId: merchantId,
      serviceVariant: serviceVariant,
      productId: productId,
      productVariantId: productVariantId,
    );
    return _findItem(key)?.quantity ?? 0;
  }

  bool addItem({
    required String productId,
    required String serviceType,
    String? merchantId,
    String? serviceVariant,
    String? productVariantId,
    String? categoryId,
    String? variantLabel,
    required String name,
    required String description,
    required int priceInPaise,
    String? imageUrl,
    required IconData icon,
  }) {
    final incomingContext = CartOrderContext(
      serviceType: serviceType,
      merchantId: merchantId,
      serviceVariant: serviceVariant,
    );
    if (!canAddContext(incomingContext)) return false;

    final key = CartItem.keyFor(
      serviceType: serviceType,
      merchantId: merchantId,
      serviceVariant: serviceVariant,
      productId: productId,
      productVariantId: productVariantId,
    );
    for (final item in _items) {
      if (item.key == key) {
        item.quantity++;
        notifyListeners();
        return true;
      }
    }

    _items.add(
      CartItem(
        key: key,
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        serviceVariant: serviceVariant,
        productVariantId: productVariantId,
        categoryId: categoryId,
        variantLabel: variantLabel,
        name: name,
        description: description,
        priceInPaise: priceInPaise,
        imageUrl: imageUrl,
        icon: icon,
      ),
    );
    notifyListeners();
    return true;
  }

  bool canAddItem({
    required String serviceType,
    String? merchantId,
    String? serviceVariant,
  }) {
    return canAddContext(
      CartOrderContext(
        serviceType: serviceType,
        merchantId: merchantId,
        serviceVariant: serviceVariant,
      ),
    );
  }

  bool canAddContext(CartOrderContext context) {
    return _items.every((item) => item.orderContext.isCompatibleWith(context));
  }

  String? incompatibilityMessage({
    required String serviceType,
    String? merchantId,
    String? serviceVariant,
  }) {
    final incomingContext = CartOrderContext(
      serviceType: serviceType,
      merchantId: merchantId,
      serviceVariant: serviceVariant,
    );
    for (final item in _items) {
      if (!item.orderContext.isCompatibleWith(incomingContext)) {
        return incomingContext.incompatibilityMessageWith(item.orderContext);
      }
    }
    return null;
  }

  bool increaseQuantity(String key) {
    final item = _findItem(key);
    if (item == null || !canAddContext(item.orderContext)) return false;
    item.quantity++;
    notifyListeners();
    return true;
  }

  void decreaseQuantity(String key) {
    final item = _findItem(key);
    if (item == null || item.quantity <= 1) return;
    item.quantity--;
    notifyListeners();
  }

  void removeItem(String key) {
    final originalLength = _items.length;
    _items.removeWhere((item) => item.key == key);
    if (_items.length != originalLength) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  CartItem? _findItem(String key) {
    for (final item in _items) {
      if (item.key == key) return item;
    }
    return null;
  }
}

class CartItem {
  CartItem({
    required this.key,
    required this.productId,
    required this.serviceType,
    required this.name,
    required this.description,
    required this.priceInPaise,
    required this.icon,
    this.merchantId,
    this.serviceVariant,
    this.productVariantId,
    this.categoryId,
    this.imageUrl,
    this.variantLabel,
    this.quantity = 1,
  });

  final String key;
  final String productId;
  final String serviceType;
  final String? merchantId;
  final String? serviceVariant;
  final String? productVariantId;
  final String? categoryId;
  final String name;
  final String description;
  final int priceInPaise;
  final String? imageUrl;
  final String? variantLabel;
  final IconData icon;
  int quantity;

  CartOrderContext get orderContext => CartOrderContext(
    serviceType: serviceType,
    merchantId: merchantId,
    serviceVariant: serviceVariant,
  );

  static String keyFor({
    required String serviceType,
    required String productId,
    String? merchantId,
    String? serviceVariant,
    String? productVariantId,
  }) {
    final merchant = merchantId ?? '';
    final variant = serviceVariant;
    final productVariant = productVariantId;
    final baseKey = variant == null
        ? '$serviceType:$merchant:$productId'
        : '$serviceType:$merchant:$variant:$productId';
    return productVariant == null ? baseKey : '$baseKey:$productVariant';
  }
}
