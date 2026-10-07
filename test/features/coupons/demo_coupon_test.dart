import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/coupons/models/demo_coupon.dart';

void main() {
  test('accepts known coupon when minimum is met and cart has items', () {
    final result = DemoCouponValidator.validate(
      code: ' myshopzy50 ',
      subtotalInPaise: 30000,
      hasCartItems: true,
      appliedCouponCode: null,
    );

    expect(result.status, CouponValidationStatus.valid);
    expect(result.coupon?.code, 'MYSHOPZY50');
    expect(result.coupon?.discountFor(30000), 5000);
  });

  test('reports amount short of the coupon minimum', () {
    final result = DemoCouponValidator.validate(
      code: 'MYSHOPZY50',
      subtotalInPaise: 29900,
      hasCartItems: true,
      appliedCouponCode: null,
    );

    expect(result.status, CouponValidationStatus.minimumOrderNotMet);
    expect(result.amountShortInPaise, 100);
  });

  test('rejects unknown and empty coupon codes', () {
    for (final code in ['', 'NOTREAL']) {
      final result = DemoCouponValidator.validate(
        code: code,
        subtotalInPaise: 100000,
        hasCartItems: true,
        appliedCouponCode: null,
      );
      expect(result.status, CouponValidationStatus.invalidCode);
    }
  });

  test('rejects a coupon that is no longer valid', () {
    const expiredCoupon = DemoCoupon(
      code: 'EXPIRED',
      offer: 'Expired',
      description: 'Test only',
      minimumOrderInPaise: 0,
      minimumOrderLabel: 'No minimum',
      validity: 'Expired demo',
      isCurrentlyValid: false,
      discountInPaise: 500,
    );

    final result = DemoCouponValidator.validate(
      code: 'EXPIRED',
      subtotalInPaise: 1000,
      hasCartItems: true,
      appliedCouponCode: null,
      coupons: const [expiredCoupon],
    );
    expect(result.status, CouponValidationStatus.expired);
  });

  test('calculates percentage discount and caps it at eligible subtotal', () {
    final coupon = demoCoupons.singleWhere((coupon) => coupon.code == 'FIRSTORDER');
    expect(coupon.discountFor(100000), 15000);

    const oversizedCoupon = DemoCoupon(
      code: 'BIG',
      offer: 'Oversized',
      description: 'Test only',
      minimumOrderInPaise: 0,
      minimumOrderLabel: 'No minimum',
      validity: 'Test',
      isCurrentlyValid: true,
      discountInPaise: 5000,
    );
    expect(oversizedCoupon.discountFor(1000), 1000);
  });

  test('payable amount cannot be negative after a coupon discount', () {
    const oversizedCoupon = DemoCoupon(
      code: 'BIG',
      offer: 'Oversized',
      description: 'Test only',
      minimumOrderInPaise: 0,
      minimumOrderLabel: 'No minimum',
      validity: 'Test',
      isCurrentlyValid: true,
      discountInPaise: 5000,
    );
    expect(
      DemoCouponValidator.payableTotal(
        subtotalInPaise: 1000,
        deliveryFeeInPaise: 0,
        coupon: oversizedCoupon,
      ),
      0,
    );
  });

  test('distinguishes duplicate coupon from a different second coupon', () {
    final result = DemoCouponValidator.validate(
      code: 'WELCOME100',
      subtotalInPaise: 100000,
      hasCartItems: true,
      appliedCouponCode: 'MYSHOPZY50',
    );
    expect(result.status, CouponValidationStatus.anotherCouponAlreadyApplied);

    final duplicate = DemoCouponValidator.validate(
      code: 'myshopzy50',
      subtotalInPaise: 100000,
      hasCartItems: true,
      appliedCouponCode: 'MYSHOPZY50',
    );
    expect(duplicate.status, CouponValidationStatus.alreadyApplied);
  });

  test('requires cart items before coupon can apply', () {
    final result = DemoCouponValidator.validate(
      code: 'MYSHOPZY50',
      subtotalInPaise: 100000,
      hasCartItems: false,
      appliedCouponCode: null,
    );
    expect(result.status, CouponValidationStatus.cartNotEligible);
  });
}
