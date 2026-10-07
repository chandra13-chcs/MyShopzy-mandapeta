import 'package:flutter/foundation.dart';

import '../../product_details/models/product_details_product.dart';

class WishlistStore extends ChangeNotifier {
  WishlistStore();

  static final instance = WishlistStore();

  final List<ProductDetailsProduct> _products = [];

  List<ProductDetailsProduct> get products =>
      List<ProductDetailsProduct>.unmodifiable(_products);

  bool contains(ProductDetailsProduct product) {
    final key = _identityOf(product);
    return _products.any((saved) => _identityOf(saved) == key);
  }

  void toggle(ProductDetailsProduct product) {
    if (contains(product)) {
      remove(product);
      return;
    }
    save(product);
  }

  void save(ProductDetailsProduct product) {
    if (contains(product)) return;
    _products.insert(0, product);
    notifyListeners();
  }

  void remove(ProductDetailsProduct product) {
    final key = _identityOf(product);
    final originalLength = _products.length;
    _products.removeWhere((saved) => _identityOf(saved) == key);
    if (_products.length != originalLength) notifyListeners();
  }

  void clear() {
    if (_products.isEmpty) return;
    _products.clear();
    notifyListeners();
  }

  String _identityOf(ProductDetailsProduct product) {
    return '${product.serviceType}:${product.merchantId ?? ''}:${product.id}';
  }
}
