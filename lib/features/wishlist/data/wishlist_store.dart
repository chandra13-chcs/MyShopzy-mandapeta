import 'package:flutter/material.dart';

import '../../product_details/models/product_details_product.dart';
import '../../../shared/data/customer_api.dart';

class WishlistStore extends ChangeNotifier {
  WishlistStore();

  static final instance = WishlistStore();

  final List<ProductDetailsProduct> _products = [];
  final Set<String> _pendingKeys = {};
  bool _isLoading = false;
  String? _error;

  bool get isBackendMode => CustomerApi.instance.isConfigured;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ProductDetailsProduct> get products =>
      List<ProductDetailsProduct>.unmodifiable(_products);

  bool isPending(ProductDetailsProduct product) =>
      _pendingKeys.contains(_identityOf(product));

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
    if (_products.isEmpty &&
        _pendingKeys.isEmpty &&
        !_isLoading &&
        _error == null) {
      return;
    }
    _products.clear();
    _pendingKeys.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (!isBackendMode) return;
    _products.clear();
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final items = await CustomerApi.instance.getWishlist();
      _products
        ..clear()
        ..addAll(items.map(_toProduct));
    } on CustomerApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleSavedProduct(ProductDetailsProduct product) async {
    if (!isBackendMode) {
      toggle(product);
      return;
    }
    if (!product.isBackendProduct) {
      throw const CustomerApiException(
        statusCode: null,
        code: 'DEMO_PRODUCT_NOT_SUPPORTED',
        message: 'Demo products cannot be saved to the backend wishlist.',
      );
    }
    if (isPending(product)) return;
    final key = _identityOf(product);
    _pendingKeys.add(key);
    notifyListeners();
    try {
      if (contains(product)) {
        await CustomerApi.instance.removeWishlistItem(product.id);
        _products.removeWhere((saved) => _identityOf(saved) == key);
      } else {
        await CustomerApi.instance.addWishlistItem(product.id);
        if (!contains(product)) _products.insert(0, product);
      }
    } finally {
      _pendingKeys.remove(key);
      notifyListeners();
    }
  }

  Future<void> removeSavedProduct(ProductDetailsProduct product) async {
    if (!isBackendMode) {
      remove(product);
      return;
    }
    if (!product.isBackendProduct) {
      throw const CustomerApiException(
        statusCode: null,
        code: 'DEMO_PRODUCT_NOT_SUPPORTED',
        message: 'Demo products cannot be removed from the backend wishlist.',
      );
    }
    if (isPending(product)) return;
    final key = _identityOf(product);
    _pendingKeys.add(key);
    notifyListeners();
    try {
      await CustomerApi.instance.removeWishlistItem(product.id);
      _products.removeWhere((saved) => _identityOf(saved) == key);
    } finally {
      _pendingKeys.remove(key);
      notifyListeners();
    }
  }

  ProductDetailsProduct _toProduct(ApiWishlistItem item) {
    return ProductDetailsProduct(
      id: item.productId,
      serviceType: 'catalog',
      merchantId: item.shopId,
      merchantName: item.shopName,
      name: item.name,
      description: item.description,
      icon: Icons.inventory_2_outlined,
      available: item.available,
      priceInPaise: item.priceMinor,
      isBackendProduct: true,
    );
  }

  String _identityOf(ProductDetailsProduct product) {
    if (product.isBackendProduct) return 'backend:${product.id}';
    return '${product.serviceType}:${product.merchantId ?? ''}:'
        '${product.id}';
  }
}
