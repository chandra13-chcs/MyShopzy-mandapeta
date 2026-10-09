import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../models/demo_coupon.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  static final ValueNotifier<int> newDemoCouponCount = ValueNotifier<int>(
    demoCoupons.length,
  );

  static void markDemoCouponsViewed() {
    if (newDemoCouponCount.value != 0) newDemoCouponCount.value = 0;
  }

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
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
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
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
          for (final coupon in demoCoupons.take(2)) ...[
            _buildCouponCard(context, coupon),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          _buildSectionHeading('Offers'),
          const SizedBox(height: 11),
          for (final coupon in demoCoupons.skip(2)) ...[
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

  Widget _buildCouponCard(BuildContext context, DemoCoupon coupon) {
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
            coupon.minimumOrderLabel,
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
                  SnackBar(
                    content: Text(
                      'Use ${coupon.code} during Checkout to validate it '
                      'against your cart.',
                    ),
                  ),
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
              child: const Text('Use at Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
