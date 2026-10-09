import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'parcel_summary_page.dart';

class ParcelPage extends StatefulWidget {
  const ParcelPage({super.key});

  @override
  State<ParcelPage> createState() => _ParcelPageState();
}

class _ParcelPageState extends State<ParcelPage> {
  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;
  static const _parcelTypes = [
    'Documents',
    'Food',
    'Clothing',
    'Electronics',
    'Other',
  ];

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _weightController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _selectedParcelType = _parcelTypes.first;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _weightController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                children: [
                  _buildLocationFields(),
                  const SizedBox(height: 22),
                  _buildSectionTitle('Parcel details'),
                  const SizedBox(height: 11),
                  _buildParcelTypeOptions(),
                  const SizedBox(height: 18),
                  _buildWeightField(),
                  const SizedBox(height: 17),
                  _buildInstructionsField(),
                  const SizedBox(height: 18),
                  _buildDeliveryInformation(),
                ],
              ),
            ),
            _buildBottomAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE8EBE6)),
              minimumSize: const Size(42, 42),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send a Parcel',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Bike delivery • Up to 50 km',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pickup & drop'),
        const SizedBox(height: 10),
        _LocationField(
          label: 'Pickup Location',
          hint: 'Enter pickup location',
          icon: Icons.radio_button_checked_rounded,
          iconColor: _green,
          controller: _pickupController,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 21),
          child: Container(
            width: 1,
            height: 13,
            color: const Color(0xFFD9DED8),
          ),
        ),
        _LocationField(
          label: 'Drop Location',
          hint: 'Enter drop location',
          icon: Icons.location_on_rounded,
          iconColor: const Color(0xFFD16A53),
          controller: _dropController,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildParcelTypeOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parcel Type',
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _parcelTypes.map((type) {
            final selected = type == _selectedParcelType;
            return ChoiceChip(
              label: Text(type),
              selected: selected,
              showCheckmark: false,
              onSelected: (value) {
                if (value) setState(() => _selectedParcelType = type);
              },
              labelStyle: TextStyle(
                color: selected ? _green : _ink,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFE6F2E8),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF9DC9A6)
                    : const Color(0xFFE5E9E3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWeightField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Weight',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Maximum 20 kg',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(
            hint: 'Enter parcel weight',
            prefixIcon: const Icon(
              Icons.scale_outlined,
              color: _muted,
              size: 19,
            ),
            suffixText: 'kg',
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instructions',
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionsController,
          minLines: 3,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: _inputDecoration(
            hint: 'Any instructions for the rider?',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryInformation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD9E9DA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _green, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maximum delivery distance: 50 km',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Vehicle: Bike',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EBE6))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => ParcelSummaryPage(
                  pickupLocation: _pickupController.text.trim(),
                  dropLocation: _dropController.text.trim(),
                  parcelType: _selectedParcelType,
                  weight: _weightController.text.trim(),
                  instructions: _instructionsController.text.trim(),
                ),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Continue'),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    String? suffixText,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF929892), fontSize: 12),
      prefixIcon: prefixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: _muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E9E3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E9E3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8EB99A)),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.controller,
  });

  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5E9E3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF727A74),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration.collapsed(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF929892),
                      fontSize: 12,
                    ),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF17251F),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
