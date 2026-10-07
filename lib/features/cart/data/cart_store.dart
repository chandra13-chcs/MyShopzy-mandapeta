import 'package:flutter/material.dart';

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
  }) {
    final key = '$serviceType:${merchantId ?? ''}:$productId';
    return _findItem(key)?.quantity ?? 0;
  }

  void addItem({
    required String productId,
    required String serviceType,
    String? merchantId,
    String? categoryId,
    required String name,
    required String description,
    required int priceInPaise,
    String? imageUrl,
    required IconData icon,
  }) {
    final key = '$serviceType:${merchantId ?? ''}:$productId';
    for (final item in _items) {
      if (item.key == key) {
        item.quantity++;
        notifyListeners();
        return;
      }
    }

    _items.add(
      CartItem(
        key: key,
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        categoryId: categoryId,
        name: name,
        description: description,
        priceInPaise: priceInPaise,
        imageUrl: imageUrl,
        icon: icon,
      ),
    );
    notifyListeners();
  }

  void increaseQuantity(String key) {
    final item = _findItem(key);
    if (item == null) return;
    item.quantity++;
    notifyListeners();
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
    this.categoryId,
    this.imageUrl,
    this.quantity = 1,
  });

  final String key;
  final String productId;
  final String serviceType;
  final String? merchantId;
  final String? categoryId;
  final String name;
  final String description;
  final int priceInPaise;
  final String? imageUrl;
  final IconData icon;
  int quantity;
}
