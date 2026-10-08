class CartOrderContext {
  const CartOrderContext({
    required this.serviceType,
    this.merchantId,
    this.serviceVariant,
  });

  final String serviceType;
  final String? merchantId;
  final String? serviceVariant;

  bool isCompatibleWith(CartOrderContext other) =>
      serviceType == other.serviceType &&
      merchantId == other.merchantId &&
      serviceVariant == other.serviceVariant;

  String incompatibilityMessageWith(CartOrderContext other) {
    if (serviceType == 'restaurant' && other.serviceType == 'restaurant') {
      return 'You can only order from one restaurant at a time.';
    }
    if (serviceType == 'bakery' && other.serviceType == 'bakery') {
      return 'You can only order from one bakery at a time.';
    }
    if (serviceType == 'local_store' && other.serviceType == 'local_store') {
      return 'You can only order from one store at a time.';
    }
    if (serviceType == 'vegetables_fruits' &&
        other.serviceType == 'vegetables_fruits') {
      return 'Please complete or clear your current order before adding items '
          'from another service.';
    }
    return 'Please complete or clear your current order before adding items '
        'from another service.';
  }
}
