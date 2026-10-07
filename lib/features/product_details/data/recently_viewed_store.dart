import 'package:flutter/foundation.dart';

import '../models/product_details_product.dart';

class RecentlyViewedStore extends ChangeNotifier {
  RecentlyViewedStore();

  static final instance = RecentlyViewedStore();

  static const maxItems = 10;

  final List<ProductDetailsProduct> _products = [];

  List<ProductDetailsProduct> get products =>
      List<ProductDetailsProduct>.unmodifiable(_products);

  void addViewedProduct(ProductDetailsProduct product) {
    final key = _identityOf(product);
    _products.removeWhere((existing) => _identityOf(existing) == key);
    _products.insert(0, product);
    if (_products.length > maxItems) {
      _products.removeRange(maxItems, _products.length);
    }
    notifyListeners();
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
