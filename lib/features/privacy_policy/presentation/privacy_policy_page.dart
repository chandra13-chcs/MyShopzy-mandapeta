import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  static const _sections = [
    _PolicySection(
      'Information We Collect',
      'Depending on how the app is used, information may include details entered into an account, preferences, and information needed to support shopping and delivery features. This draft does not define a final collection scope.',
    ),
    _PolicySection(
      'How We Use Information',
      'Information may be used to provide and improve app features, help coordinate orders, and respond to user requests. The final purposes and processing practices are to be confirmed before launch.',
    ),
    _PolicySection(
      'Location Information',
      'Location may be relevant to showing nearby stores or arranging delivery. Any location access, its purpose, and available controls must be described and confirmed before production.',
    ),
    _PolicySection(
      'Order and Delivery Information',
      'Information related to a selected store, order, and delivery may be used to display order progress and help fulfill a request. The final information flows are to be documented before launch.',
    ),
    _PolicySection(
      'Payment Information',
      'Payment options and any payment-related information handling will depend on the checkout methods made available. This draft does not describe a payment provider or store card details.',
    ),
    _PolicySection(
      'Account Information',
      'If account features are provided, users may be able to view or update account details in the app. Account requirements and controls remain to be finalized.',
    ),
    _PolicySection(
      'Notifications',
      'The app may display order updates or other notifications. Any notification permissions and user controls will be explained before those features are launched.',
    ),
    _PolicySection(
      'Data Security',
      'Appropriate safeguards will be determined and documented before production. No specific security practice is promised by this demo text.',
    ),
    _PolicySection(
      'Data Retention',
      'Retention periods and deletion practices have not been finalized and will be provided before production launch.',
    ),
    _PolicySection(
      'Third-Party Services',
      'Some app capabilities may involve third-party services. Any services used and the information they handle will be identified in the final policy before launch.',
    ),
    _PolicySection(
      'Your Choices',
      'Available choices may include updating account details and adjusting device or app permissions where supported. Specific controls will be documented when finalized.',
    ),
    _PolicySection(
      'Changes to This Policy',
      'This draft may be updated as the app and its practices are finalized. The production policy will explain how material updates are communicated.',
    ),
    _PolicySection(
      'Contact',
      'Contact details will be provided by MyShopzy before production launch.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'Privacy information',
              style: TextStyle(
                color: _mainText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is placeholder/demo content for the MyShopzy interface. It is not a final privacy policy.',
              style: TextStyle(
                color: _secondaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Last updated: To be finalized before production launch.',
              style: TextStyle(
                color: _secondaryText,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 18),
            for (final section in _sections) ...[
              _buildSection(section),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(_PolicySection section) {
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
              color: _green,
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

class _PolicySection {
  const _PolicySection(this.title, this.body);

  final String title;
  final String body;
}
