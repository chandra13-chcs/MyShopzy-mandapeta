import 'package:flutter/material.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  static const _availableCoupons = [
    _DemoCoupon(
      code: 'MYSHOPZY50',
      offer: 'Get ₹50 off',
      description: 'Save on your next order from selected stores.',
      minimumOrder: 'On orders above ₹299',
      validity: 'Demo offer · Valid for a limited time',
    ),
    _DemoCoupon(
      code: 'WELCOME100',
      offer: 'Get ₹100 off',
      description: 'A little something for your first MyShopzy order.',
      minimumOrder: 'On orders above ₹499',
      validity: 'Demo offer · New customers',
    ),
  ];

  static const _offers = [
    _DemoCoupon(
      code: 'FIRSTORDER',
      offer: '15% off your first order',
      description:
          'Enjoy a discount on a first order from participating shops.',
      minimumOrder: 'On orders above ₹199',
      validity: 'Demo offer · Selected categories',
    ),
  ];

  static final ValueNotifier<int> newDemoCouponCount = ValueNotifier<int>(
    _availableCoupons.length + _offers.length,
  );

  static void markDemoCouponsViewed() {
    if (newDemoCouponCount.value != 0) newDemoCouponCount.value = 0;
  }

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CouponsPage.markDemoCouponsViewed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        title: const Text(
          'Coupons & Offers',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          _buildSectionHeading('Available Coupons'),
          const SizedBox(height: 11),
          for (final coupon in CouponsPage._availableCoupons) ...[
            _buildCouponCard(context, coupon),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          _buildSectionHeading('Offers'),
          const SizedBox(height: 11),
          for (final coupon in CouponsPage._offers) ...[
            _buildCouponCard(context, coupon),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _mainText,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCouponCard(BuildContext context, _DemoCoupon coupon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: _green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  coupon.offer,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _border),
            ),
            child: Text(
              coupon.code,
              style: const TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            coupon.description,
            style: const TextStyle(
              color: _secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            coupon.minimumOrder,
            style: const TextStyle(
              color: _mainText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            coupon.validity,
            style: const TextStyle(color: _secondaryText, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coupon applied for demo')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCoupon {
  const _DemoCoupon({
    required this.code,
    required this.offer,
    required this.description,
    required this.minimumOrder,
    required this.validity,
  });

  final String code;
  final String offer;
  final String description;
  final String minimumOrder;
  final String validity;
}
