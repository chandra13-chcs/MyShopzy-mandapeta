import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/presentation/promotional_banner.dart';
import '../data/parcel_location_service.dart';
import 'parcel_history_page.dart';
import 'parcel_summary_page.dart';

class ParcelPage extends StatefulWidget {
  const ParcelPage({this.locationService, super.key});

  final ParcelLocationService? locationService;

  @override
  State<ParcelPage> createState() => _ParcelPageState();
}

class _ParcelPageState extends State<ParcelPage> {
  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;
  static const _parcelTypes = ApiParcelBookingRequest.parcelTypes;

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _weightController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedParcelType = _parcelTypes.first;
  late final ParcelLocationService _locationService;
  bool _detectingPickupLocation = false;
  bool _pickupAddressEdited = false;
  String? _pickupLocationMessage;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? ParcelLocationService();
    _useCurrentLocation();
  }

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
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  children: [
                    const PromotionalBanner(
                      assetPath: 'assets/myshopzy_banners/parellu.jpeg',
                      imageKey: ValueKey('parcel-page-promotion-banner'),
                      semanticLabel: 'Parcel delivery promotion banner',
                    ),
                    const SizedBox(height: 16),
                    if (!CustomerApi.instance.isConfigured) ...[
                      _buildDemoModeNotice(),
                      const SizedBox(height: 14),
                    ],
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
          IconButton(
            key: const ValueKey('parcel-history-button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ParcelHistoryPage(),
              ),
            ),
            tooltip: 'Parcel history',
            icon: const Icon(Icons.history_rounded, color: _green),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE8EBE6)),
              minimumSize: const Size(42, 42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoModeNotice() {
    return Container(
      key: const ValueKey('parcel-demo-mode'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEED9A8)),
      ),
      child: const Text(
        'Demo mode · parcel requests are not submitted. Set MYSHOPZY_API_BASE_URL to a reachable backend origin when starting the app.',
        style: TextStyle(color: _ink, fontSize: 12, height: 1.35),
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
          validator: (value) => _validateLocation(value, 'pickup'),
          onChanged: (_) => _pickupAddressEdited = true,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                key: const ValueKey('parcel-use-current-location'),
                onPressed: _detectingPickupLocation
                    ? null
                    : () => _useCurrentLocation(overwriteManualAddress: true),
                icon: _detectingPickupLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 17),
                label: Text(
                  _detectingPickupLocation
                      ? 'Getting current location...'
                      : 'Use current location',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_pickupLocationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    _pickupLocationMessage!,
                    key: const ValueKey('parcel-location-message'),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
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
          validator: (value) => _validateLocation(value, 'drop'),
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
        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _validateWeight,
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
        TextFormField(
          controller: _instructionsController,
          minLines: 3,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if ((value ?? '').length > 1000) {
              return 'Instructions must be 1000 characters or fewer.';
            }
            return null;
          },
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
            if (!(_formKey.currentState?.validate() ?? false)) return;
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

  String? _validateLocation(String? value, String kind) {
    final location = value?.trim() ?? '';
    if (location.isEmpty) return 'Enter a $kind location.';
    if (location.length > 300) {
      return 'Location must be 300 characters or fewer.';
    }
    return null;
  }

  Future<void> _useCurrentLocation({
    bool overwriteManualAddress = false,
  }) async {
    setState(() {
      _detectingPickupLocation = true;
      _pickupLocationMessage = null;
    });
    try {
      final address = await _locationService.detectPickupAddress();
      if (!mounted) return;
      if (overwriteManualAddress || !_pickupAddressEdited) {
        _pickupController.value = TextEditingValue(
          text: address,
          selection: TextSelection.collapsed(offset: address.length),
        );
        _pickupAddressEdited = false;
        _pickupLocationMessage = 'Pickup address detected. You can edit it.';
      } else {
        _pickupLocationMessage =
            'Location detected. Your manually entered pickup address was kept.';
      }
    } on ParcelLocationException catch (error) {
      if (mounted) _pickupLocationMessage = error.message;
    } finally {
      if (mounted) {
        setState(() => _detectingPickupLocation = false);
      }
    }
  }

  String? _validateWeight(String? value) {
    final weightText = value?.trim() ?? '';
    final weight = double.tryParse(weightText);
    if (weight == null || !weight.isFinite) {
      return 'Enter a valid parcel weight.';
    }
    if (weight <= 0 || weight > 20) {
      return 'Weight must be greater than 0 kg and no more than 20 kg.';
    }
    if ((weight * 1000 - (weight * 1000).round()).abs() > 1e-7) {
      return 'Weight can have up to 3 decimal places.';
    }
    return null;
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
    required this.validator,
    this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final ValueChanged<String>? onChanged;

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
                TextFormField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  validator: validator,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF929892),
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
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
