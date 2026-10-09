import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
  static const _border = Color(0xFFE7EAE8);

  static const _sections = [
    _TermsSection(
      'Introduction',
      'These draft terms describe general expectations for using the MyShopzy app interface and its delivery and local-commerce features. They are demo content only, not final legal terms.',
    ),
    _TermsSection(
      'User Accounts',
      'Where account features are offered, users may be asked to provide information and keep it accurate. Account setup, access, and responsibilities must be finalized before launch.',
    ),
    _TermsSection(
      'Orders',
      'An order request may be submitted through the app for a product or service shown there. Availability and confirmation details will be described in the final terms.',
    ),
    _TermsSection(
      'Restaurant / Store / Bakery Orders',
      'Items are offered by participating restaurants, stores, or bakeries. Item descriptions and availability may vary and will be presented in the app when the service is finalized.',
    ),
    _TermsSection(
      'Meat Orders',
      'Meat products, if offered, will be subject to the product information and availability shown at the time of an order. Handling and fulfillment details remain to be finalized.',
    ),
    _TermsSection(
      'Parcel Services',
      'Parcel features, if available, will be subject to the service details and item restrictions presented in the app. Applicable limits will be provided before launch.',
    ),
    _TermsSection(
      'Delivery',
      'Delivery options and estimated times may depend on location, availability, and other operational factors. The app will show relevant details when provided.',
    ),
    _TermsSection(
      'Pricing and Payments',
      'Prices and available payment options will be shown in the app before an order is placed. Any applicable charges and payment terms must be finalized and disclosed before production.',
    ),
    _TermsSection(
      'Cancellations and Refunds',
      'Cancellation and refund options may depend on order status and the applicable service. The final rules and any timelines will be stated before launch.',
    ),
    _TermsSection(
      'User Responsibilities',
      'Users are expected to provide accurate information, review order details before submission, and use the app in a lawful and respectful manner.',
    ),
    _TermsSection(
      'Partner Responsibilities',
      'Participating partners are expected to provide accurate product and availability information and fulfill confirmed orders according to the service details agreed for launch.',
    ),
    _TermsSection(
      'Prohibited Use',
      'Users must not misuse the app, interfere with its operation, or use it to submit misleading or unlawful requests. Final prohibited-use terms remain subject to review.',
    ),
    _TermsSection(
      'Service Availability',
      'Features and participating services may vary by location and availability. No service availability commitment is made by this demo content.',
    ),
    _TermsSection(
      'Limitation of Liability',
      'Any provisions about responsibility or liability require legal review and will be finalized before production. This draft does not establish final legal terms.',
    ),
    _TermsSection(
      'Changes to Terms',
      'The terms may be revised as app features and operating practices are finalized. The final terms will describe how updates are communicated.',
    ),
    _TermsSection(
      'Contact',
      'Contact details will be provided before production launch.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _lightGreen,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: const Text(
                'These terms are draft/demo content and should be reviewed and finalized before production launch.',
                style: TextStyle(
                  color: _green,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final section in _sections) ...[
              _buildSection(section),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(_TermsSection section) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: _mainText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            section.body,
            style: const TextStyle(
              color: _secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection {
  const _TermsSection(this.title, this.body);

  final String title;
  final String body;
}
