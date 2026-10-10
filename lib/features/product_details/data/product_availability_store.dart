import 'package:flutter/foundation.dart';

class ProductAvailabilityStore extends ChangeNotifier {
  ProductAvailabilityStore();

  static final instance = ProductAvailabilityStore();

  final Map<String, bool> _availabilityOverrides = {};

  bool isAvailable({
    required String productId,
    required String serviceType,
    required bool defaultAvailable,
    String? merchantId,
    String? variantId,
  }) {
    final variantOverride = variantId == null
        ? null
        : _availabilityOverrides[_key(
            productId: productId,
            serviceType: serviceType,
            merchantId: merchantId,
            variantId: variantId,
          )];
    final productOverride =
        _availabilityOverrides[_key(
          productId: productId,
          serviceType: serviceType,
          merchantId: merchantId,
        )];
    if (variantOverride != null) return variantOverride;
    if (variantId != null) return defaultAvailable;
    return productOverride ?? defaultAvailable;
  }

  void setAvailability({
    required String productId,
    required String serviceType,
    required bool isAvailable,
    String? merchantId,
    String? variantId,
  }) {
    final key = _key(
      productId: productId,
      serviceType: serviceType,
      merchantId: merchantId,
      variantId: variantId,
    );
    if (_availabilityOverrides[key] == isAvailable) return;
    _availabilityOverrides[key] = isAvailable;
    notifyListeners();
  }

  void clearOverrides() {
    if (_availabilityOverrides.isEmpty) return;
    _availabilityOverrides.clear();
    notifyListeners();
  }

  String _key({
    required String productId,
    required String serviceType,
    String? merchantId,
    String? variantId,
  }) {
    final productKey = '$serviceType:${merchantId ?? ''}:$productId';
    return variantId == null ? productKey : '$productKey:$variantId';
  }
}
