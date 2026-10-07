class DemoCoupon {
  const DemoCoupon({
    required this.code,
    required this.offer,
    required this.description,
    required this.minimumOrderInPaise,
    required this.minimumOrderLabel,
    required this.validity,
    required this.isCurrentlyValid,
    this.discountInPaise,
    this.discountPercent,
  }) : assert(
         (discountInPaise == null) != (discountPercent == null),
         'Provide exactly one discount value.',
       );

  final String code;
  final String offer;
  final String description;
  final int minimumOrderInPaise;
  final String minimumOrderLabel;
  final String validity;
  final bool isCurrentlyValid;
  final int? discountInPaise;
  final int? discountPercent;

  int discountFor(int eligibleSubtotalInPaise) {
    final calculated =
        discountInPaise ?? (eligibleSubtotalInPaise * discountPercent! ~/ 100);
    return calculated.clamp(0, eligibleSubtotalInPaise);
  }
}

const demoCoupons = [
  DemoCoupon(
    code: 'MYSHOPZY50',
    offer: 'Get ₹50 off',
    description: 'Save on your next order from selected stores.',
    minimumOrderInPaise: 30000,
    minimumOrderLabel: 'On orders above ₹299',
    validity: 'Demo offer · Valid for a limited time',
    isCurrentlyValid: true,
    discountInPaise: 5000,
  ),
  DemoCoupon(
    code: 'WELCOME100',
    offer: 'Get ₹100 off',
    description: 'A little something for your first MyShopzy order.',
    minimumOrderInPaise: 50000,
    minimumOrderLabel: 'On orders above ₹499',
    validity: 'Demo offer · New customers',
    isCurrentlyValid: true,
    discountInPaise: 10000,
  ),
  DemoCoupon(
    code: 'FIRSTORDER',
    offer: '15% off your first order',
    description: 'Enjoy a discount on a first order from participating shops.',
    minimumOrderInPaise: 20000,
    minimumOrderLabel: 'On orders above ₹199',
    validity: 'Demo offer · Selected categories',
    isCurrentlyValid: true,
    discountPercent: 15,
  ),
];

enum CouponValidationStatus {
  valid,
  invalidCode,
  expired,
  minimumOrderNotMet,
  cartNotEligible,
  alreadyApplied,
  anotherCouponAlreadyApplied,
}

class CouponValidationResult {
  const CouponValidationResult({
    required this.status,
    this.coupon,
    this.amountShortInPaise = 0,
  });

  final CouponValidationStatus status;
  final DemoCoupon? coupon;
  final int amountShortInPaise;

  bool get isValid => status == CouponValidationStatus.valid;
}

class DemoCouponValidator {
  const DemoCouponValidator._();

  static CouponValidationResult validate({
    required String code,
    required int subtotalInPaise,
    required bool hasCartItems,
    required String? appliedCouponCode,
    List<DemoCoupon> coupons = demoCoupons,
  }) {
    final normalizedCode = code.trim().toUpperCase();
    DemoCoupon? coupon;
    for (final candidate in coupons) {
      if (candidate.code.toUpperCase() == normalizedCode) {
        coupon = candidate;
        break;
      }
    }
    if (coupon == null) {
      return const CouponValidationResult(
        status: CouponValidationStatus.invalidCode,
      );
    }
    if (appliedCouponCode != null) {
      return CouponValidationResult(
        status: normalizedCode == appliedCouponCode.trim().toUpperCase()
            ? CouponValidationStatus.alreadyApplied
            : CouponValidationStatus.anotherCouponAlreadyApplied,
        coupon: coupon,
      );
    }
    if (!coupon.isCurrentlyValid) {
      return CouponValidationResult(
        status: CouponValidationStatus.expired,
        coupon: coupon,
      );
    }
    if (!hasCartItems) {
      return CouponValidationResult(
        status: CouponValidationStatus.cartNotEligible,
        coupon: coupon,
      );
    }
    if (subtotalInPaise < coupon.minimumOrderInPaise) {
      return CouponValidationResult(
        status: CouponValidationStatus.minimumOrderNotMet,
        coupon: coupon,
        amountShortInPaise: coupon.minimumOrderInPaise - subtotalInPaise,
      );
    }
    return CouponValidationResult(
      status: CouponValidationStatus.valid,
      coupon: coupon,
    );
  }

  static int payableTotal({
    required int subtotalInPaise,
    required int deliveryFeeInPaise,
    required DemoCoupon? coupon,
  }) {
    final total =
        subtotalInPaise +
        deliveryFeeInPaise -
        (coupon?.discountFor(subtotalInPaise) ?? 0);
    return total < 0 ? 0 : total;
  }
}
