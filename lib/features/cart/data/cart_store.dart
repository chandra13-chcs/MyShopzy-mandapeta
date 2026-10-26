import 'package:flutter/material.dart';

import '../../../shared/data/customer_api.dart';
import '../models/cart_order_context.dart';

class CartStore extends ChangeNotifier {
  CartStore._();

  static final instance = CartStore._();

  final List<CartItem> _items = [];
  final Set<String> _pendingQuantityMutations = {};
  final Set<String> _pendingCatalogAdds = {};

  List<CartItem> get items => List.unmodifiable(_items);

  bool isQuantityMutationPending(String key) =>
      _pendingQuantityMutations.contains(key);

  bool isCatalogItemAddPending({
    required String productId,
    required String serviceType,
    required String merchantId,
    String? productVariantId,
  }) => _pendingCatalogAdds.contains(
    CartItem.keyFor(
      serviceType: serviceType,
      merchantId: merchantId,
      productId: productId,
      productVariantId: productVariantId,
    ),
  );

  bool get hasBackendCart =>
      _items.isNotEmpty && _items.every((item) => item.isBackendProduct);

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
    bool isBackendProduct = false,
  }) {
    if (!CustomerApi.instance.hasCustomerSession) {
      throw const CustomerApiException(
        statusCode: 401,
        code: 'AUTHENTICATION_REQUIRED',
        message: 'Sign in to add items to your cart.',
      );
    }
    if (!isBackendProduct || !CustomerApi.instance.isConfigured) {
      throw const CustomerApiException(
        statusCode: 503,
        code: 'CART_OWNERSHIP_UNAVAILABLE',
        message: 'Cart and checkout are unavailable until customer ownership is supported.',
      );
    }
    if (_items.any((item) => item.isBackendProduct != isBackendProduct)) {
      return false;
    }
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
        isBackendProduct: isBackendProduct,
      ),
    );
    notifyListeners();
    return true;
  }

  Future<bool> addCatalogItem({
    required String productId,
    required String serviceType,
    required String merchantId,
    required String categoryId,
    String? productVariantId,
    String? variantLabel,
    required String name,
    required String description,
    required int priceInPaise,
    required IconData icon,
  }) async {
    final api = CustomerApi.instance;
    if (!api.isConfigured) {
      return addItem(
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        categoryId: categoryId,
        productVariantId: productVariantId,
        variantLabel: variantLabel,
        name: name,
        description: description,
        priceInPaise: priceInPaise,
        icon: icon,
      );
    }

    if (_items.any((item) => !item.isBackendProduct)) {
      throw const CustomerApiException(
        statusCode: null,
        code: 'DEMO_CART_NOT_SYNCED',
        message:
            'Clear unsupported local cart items before using the live catalog.',
      );
    }
    if (productVariantId == null || productVariantId.isEmpty) {
      throw const CustomerApiException(
        statusCode: null,
        code: 'VARIANT_REQUIRED',
        message: 'Choose a product variant before adding it to your cart.',
      );
    }
    final incomingContext = CartOrderContext(
      serviceType: serviceType,
      merchantId: merchantId,
    );
    final restoredBackendContext =
        _items.isNotEmpty &&
        _items.every(
          (item) => item.isBackendProduct && item.merchantId == merchantId,
        );
    if (!restoredBackendContext && !canAddContext(incomingContext)) {
      return false;
    }

    final pendingKey = CartItem.keyFor(
      serviceType: serviceType,
      merchantId: merchantId,
      productId: productId,
      productVariantId: productVariantId,
    );
    if (_pendingCatalogAdds.contains(pendingKey)) return false;
    _pendingCatalogAdds.add(pendingKey);
    notifyListeners();
    try {
      final updatedQuantity = await api.addCartItem(
        productId,
        variantId: productVariantId,
      );
      for (final item in _items) {
        if (item.isBackendProduct &&
            item.productId == productId &&
            item.merchantId == merchantId &&
            item.productVariantId == productVariantId) {
          item.quantity = updatedQuantity;
          item.name = name;
          item.description = description;
          item.priceInPaise = priceInPaise;
          item.categoryId = categoryId;
          notifyListeners();
          return true;
        }
      }
      final added = addItem(
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        categoryId: categoryId,
        productVariantId: productVariantId,
        variantLabel: variantLabel,
        name: name,
        description: description,
        priceInPaise: priceInPaise,
        icon: icon,
        isBackendProduct: true,
      );
      final addedItem = _findItem(pendingKey);
      if (added && addedItem != null) {
        addedItem.quantity = updatedQuantity;
        notifyListeners();
      }
      return added;
    } finally {
      _pendingCatalogAdds.remove(pendingKey);
      notifyListeners();
    }
  }

  Future<void> refreshBackendCart() async {
    if (_items.any((item) => !item.isBackendProduct)) {
      throw const CustomerApiException(
        statusCode: null,
        code: 'CART_OWNERSHIP_UNAVAILABLE',
        message: 'Local preview items cannot be used for checkout.',
      );
    }
    final cart = await CustomerApi.instance.getCart();
    final existingItems = {
      for (final item in _items)
        if (item.isBackendProduct)
          '${item.merchantId}:${item.productId}:${item.productVariantId}': item,
    };
    _items
      ..clear()
      ..addAll(
        cart.items.map((apiItem) {
          final existing =
              existingItems['${apiItem.shopId}:${apiItem.productId}:${apiItem.variantId}'];
          if (existing != null) {
            return existing
              ..quantity = apiItem.quantity
              ..priceInPaise = apiItem.priceMinor
              ..name = apiItem.name
              ..available = apiItem.available;
          }
          final key = CartItem.keyFor(
            serviceType: 'backend_catalog',
            merchantId: apiItem.shopId,
            productId: apiItem.productId,
            productVariantId: apiItem.variantId,
          );
          return CartItem(
            key: key,
            productId: apiItem.productId,
            productVariantId: apiItem.variantId,
            variantLabel: apiItem.variantLabel,
            serviceType: 'backend_catalog',
            merchantId: apiItem.shopId,
            name: apiItem.name,
            description: '',
            priceInPaise: apiItem.priceMinor,
            icon: Icons.shopping_bag_outlined,
            quantity: apiItem.quantity,
            isBackendProduct: true,
            available: apiItem.available,
          );
        }),
      );
    notifyListeners();
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
    if (_items.isNotEmpty &&
        _items.every((item) => item.isBackendProduct) &&
        context.merchantId != null &&
        _items.every((item) => item.merchantId == context.merchantId)) {
      return true;
    }
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

  Future<bool> increaseQuantityFromUi(String key) async {
    final item = _findItem(key);
    if (item == null || !canAddContext(item.orderContext)) return false;
    return _updateQuantityFromUi(item, item.quantity + 1);
  }

  void decreaseQuantity(String key) {
    final item = _findItem(key);
    if (item == null || item.quantity <= 1) return;
    item.quantity--;
    notifyListeners();
  }

  Future<void> decreaseQuantityFromUi(String key) async {
    final item = _findItem(key);
    if (item == null || item.quantity <= 1) return;
    await _updateQuantityFromUi(item, item.quantity - 1);
  }

  Future<bool> _updateQuantityFromUi(CartItem item, int quantity) async {
    final key = item.key;
    if (_pendingQuantityMutations.contains(key)) return false;
    if (!item.isBackendProduct) {
      item.quantity = quantity;
      notifyListeners();
      return true;
    }

    _pendingQuantityMutations.add(key);
    notifyListeners();
    try {
      final updatedQuantity = await CustomerApi.instance.updateCartItem(
        item.productId,
        item.productVariantId!,
        quantity,
      );
      final currentItem = _findItem(key);
      if (currentItem != null) currentItem.quantity = updatedQuantity;
      return true;
    } finally {
      _pendingQuantityMutations.remove(key);
      notifyListeners();
    }
  }

  void removeItem(String key) {
    final originalLength = _items.length;
    _items.removeWhere((item) => item.key == key);
    if (_items.length != originalLength) notifyListeners();
  }

  Future<void> removeItemFromUi(String key) async {
    final item = _findItem(key);
    if (item == null) return;
    if (item.isBackendProduct) {
      await CustomerApi.instance.removeCartItem(
        item.productId,
        item.productVariantId!,
      );
    }
    removeItem(key);
  }

  Future<void> clearFromUi() async {
    if (_items.any((item) => item.isBackendProduct)) {
      await CustomerApi.instance.clearCart();
    }
    clear();
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
    this.isBackendProduct = false,
    this.available = true,
  });

  final String key;
  final String productId;
  final String serviceType;
  final String? merchantId;
  final String? serviceVariant;
  final String? productVariantId;
  String? categoryId;
  String name;
  String description;
  int priceInPaise;
  final String? imageUrl;
  final String? variantLabel;
  final IconData icon;
  int quantity;
  final bool isBackendProduct;
  bool available;

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
