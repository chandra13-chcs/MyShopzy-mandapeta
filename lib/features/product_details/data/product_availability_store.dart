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
  }) {
    return _availabilityOverrides[_key(
          productId: productId,
          serviceType: serviceType,
          merchantId: merchantId,
        )] ??
        defaultAvailable;
  }

  void setAvailability({
    required String productId,
    required String serviceType,
    required bool isAvailable,
    String? merchantId,
  }) {
    final key = _key(
      productId: productId,
      serviceType: serviceType,
      merchantId: merchantId,
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
  }) {
    return '$serviceType:${merchantId ?? ''}:$productId';
  }
}
