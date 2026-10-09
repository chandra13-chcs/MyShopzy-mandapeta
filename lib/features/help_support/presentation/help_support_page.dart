import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
  static const _border = Color(0xFFE7EAE8);

  static const _categories = [
    _HelpCategory(
      title: 'Orders',
      icon: Icons.receipt_long_outlined,
      questions: [
        _FaqItem(
          'Where is my order?',
          'You can check the latest order status from My Orders in your account.',
        ),
        _FaqItem(
          'How can I cancel an order?',
          'Open My Orders and select an order to review its available options.',
        ),
        _FaqItem(
          'How can I view my order history?',
          'Your past orders can be found in the Delivered section of My Orders.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Delivery',
      icon: Icons.delivery_dining_outlined,
      questions: [
        _FaqItem(
          'How long does delivery take?',
          'Delivery time depends on the store and your delivery location.',
        ),
        _FaqItem(
          'How do I track my delivery?',
          'Check the order status in My Orders for the latest delivery updates.',
        ),
        _FaqItem(
          'What if my order is delayed?',
          'Please check your order status for updates. You can also contact support.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Payments',
      icon: Icons.payments_outlined,
      questions: [
        _FaqItem(
          'What payment methods are supported?',
          'Available payment methods are shown on the Payments screen and during checkout.',
        ),
        _FaqItem(
          'My payment failed. What should I do?',
          'Check your payment method and try again. If the issue continues, contact support.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Account',
      icon: Icons.person_outline_rounded,
      questions: [
        _FaqItem(
          'How do I edit my profile?',
          'Open My Account and select Edit Profile to update your details.',
        ),
        _FaqItem(
          'How do I manage saved addresses?',
          'Open Saved Addresses from My Account to view your saved locations.',
        ),
      ],
    ),
  ];

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filteredCategories;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const Text(
            'How can we help?',
            style: TextStyle(
              color: _mainText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find answers to common questions about your account and orders.',
            style: TextStyle(color: _secondaryText, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search help topics',
              hintStyle: const TextStyle(color: _secondaryText),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _secondaryText,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No matching help topics',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondaryText, fontSize: 14),
              ),
            )
          else
            for (final category in categories) ...[
              _buildCategoryCard(category),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 12),
          _buildContactSupport(context),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showComingSoon(
              context,
              'Issue reporting will be available soon',
            ),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report an Issue'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_HelpCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    final query = _searchQuery.toLowerCase();
    return [
      for (final category in _categories)
        if (category.title.toLowerCase().contains(query) ||
            category.questions.any(
              (item) =>
                  item.question.toLowerCase().contains(query) ||
                  item.answer.toLowerCase().contains(query),
            ))
          _HelpCategory(
            title: category.title,
            icon: category.icon,
            questions: category.questions
                .where(
                  (item) =>
                      category.title.toLowerCase().contains(query) ||
                      item.question.toLowerCase().contains(query) ||
                      item.answer.toLowerCase().contains(query),
                )
                .toList(),
          ),
    ];
  }

  Widget _buildCategoryCard(_HelpCategory category) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 7),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: _green, size: 21),
                ),
                const SizedBox(width: 11),
                Text(
                  category.title,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < category.questions.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: _border),
            _buildFaq(category.questions[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildFaq(_FaqItem item) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 15),
      childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
      iconColor: _green,
      collapsedIconColor: _secondaryText,
      title: Text(
        item.question,
        style: const TextStyle(
          color: _mainText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.answer,
            style: const TextStyle(
              color: _secondaryText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSupport(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Support',
            style: TextStyle(
              color: _mainText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          _buildContactAction(
            context,
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chat with Support',
            message: 'Support chat will be available soon',
          ),
          _buildContactAction(
            context,
            icon: Icons.call_outlined,
            title: 'Call Support',
            message: 'Call support will be available soon',
          ),
          _buildContactAction(
            context,
            icon: Icons.email_outlined,
            title: 'Email Support',
            message: 'Email support will be available soon',
          ),
        ],
      ),
    );
  }

  Widget _buildContactAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _green, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: _mainText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _secondaryText),
      onTap: () => _showComingSoon(context, message),
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HelpCategory {
  const _HelpCategory({
    required this.title,
    required this.icon,
    required this.questions,
  });

  final String title;
  final IconData icon;
  final List<_FaqItem> questions;
}

class _FaqItem {
  const _FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}
