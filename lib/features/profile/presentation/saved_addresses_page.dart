import 'package:flutter/material.dart';

class SavedAddressesPage extends StatelessWidget {
  const SavedAddressesPage({super.key});

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  static const _addresses = [
    _SavedAddress(
      label: 'Home',
      icon: Icons.home_outlined,
      address: 'Demo address: 12 Green Park Road, Ravulapalem',
    ),
    _SavedAddress(
      label: 'Work',
      icon: Icons.business_outlined,
      address: 'Demo address: 24 Market Street, Ravulapalem',
    ),
    _SavedAddress(
      label: 'Other',
      icon: Icons.location_on_outlined,
      address: 'Demo address: 8 River View Lane, Ravulapalem',
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
          'Saved Addresses',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          itemCount: _addresses.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == _addresses.length) {
              return _buildAddAddressButton(context);
            }
            return _buildAddressCard(context, _addresses[index]);
          },
        ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, _SavedAddress address) {
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
                child: Icon(address.icon, color: _green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  address.label,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showComingSoon(
                  context,
                  'Address editing will be available soon',
                ),
                tooltip: 'Edit address',
                icon: const Icon(Icons.edit_outlined, color: _green, size: 21),
              ),
              IconButton(
                onPressed: () => _showComingSoon(
                  context,
                  'Address deletion will be available soon',
                ),
                tooltip: 'Delete address',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: _secondaryText,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            address.address,
            style: const TextStyle(
              color: _secondaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAddressButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () =>
            _showComingSoon(context, 'Address creation will be available soon'),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add New Address',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SavedAddress {
  const _SavedAddress({
    required this.label,
    required this.icon,
    required this.address,
  });

  final String label;
  final IconData icon;
  final String address;
}
