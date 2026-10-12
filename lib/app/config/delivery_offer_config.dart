class DeliveryOfferConfig {
  const DeliveryOfferConfig._();

  static const thresholdInPaise = 19900;

  static String get thresholdLabel => '₹${thresholdInPaise ~/ 100}';

  static int remainingInPaise(int eligibleSubtotalInPaise) {
    final remaining = thresholdInPaise - eligibleSubtotalInPaise;
    return remaining > 0 ? remaining : 0;
  }

  static String messageForSubtotal(int eligibleSubtotalInPaise) {
    final remaining = remainingInPaise(eligibleSubtotalInPaise);
    if (remaining == 0) return 'Free delivery unlocked!';
    final remainingRupees = (remaining + 99) ~/ 100;
    return 'Add ₹$remainingRupees more to unlock FREE DELIVERY';
  }
}
