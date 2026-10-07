import 'package:flutter/material.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  static const _methods = [
    _PaymentMethod(
      title: 'UPI',
      status: 'Available',
      icon: Icons.account_balance_wallet_outlined,
      isAvailable: true,
    ),
    _PaymentMethod(
      title: 'Cash on Delivery',
      status: 'Available',
      icon: Icons.payments_outlined,
      isAvailable: true,
    ),
    _PaymentMethod(
      title: 'Credit / Debit Card',
      status: 'Coming soon',
      icon: Icons.credit_card_outlined,
      isAvailable: false,
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
          'Payments',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(
              color: _mainText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                for (var index = 0; index < _methods.length; index++) ...[
                  _buildMethodRow(_methods[index]),
                  if (index < _methods.length - 1)
                    const Divider(height: 1, color: _border),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _showComingSoon(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Payment Method',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                backgroundColor: _lightGreen,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: _green, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your payment details will be securely handled during checkout.',
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodRow(_PaymentMethod method) {
    final statusColor = method.isAvailable ? _green : _secondaryText;
    final statusBackground = method.isAvailable
        ? _lightGreen
        : const Color(0xFFF3F4F3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(method.icon, color: _green, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              method.title,
              style: const TextStyle(
                color: _mainText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              method.status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment methods will be available soon')),
    );
  }
}

class _PaymentMethod {
  const _PaymentMethod({
    required this.title,
    required this.status,
    required this.icon,
    required this.isAvailable,
  });

  final String title;
  final String status;
  final IconData icon;
  final bool isAvailable;
}
