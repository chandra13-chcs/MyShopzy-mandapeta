import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../models/saved_address.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
  static const _border = Color(0xFFE7EAE8);

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  List<SavedAddress> _addresses = const [];
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (CustomerApi.instance.hasCustomerSession) {
      _loading = true;
      Future<void>.delayed(Duration.zero, _loadAddresses);
    }
  }

  Future<void> _loadAddresses() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final addresses = await CustomerApi.instance.getSavedAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses.map(_toSavedAddress).toList(growable: false);
      });
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  SavedAddress _toSavedAddress(ApiSavedAddress address) {
    return SavedAddress(
      id: address.id,
      label: address.label,
      address: address.formattedAddress,
      icon: _addressIcon(address.label),
      isBackendData: true,
      latitude: address.latitude,
      longitude: address.longitude,
      pincode: address.pincode,
    );
  }

  IconData _addressIcon(String label) {
    return switch (label.toLowerCase()) {
      'home' => Icons.home_outlined,
      'work' => Icons.business_outlined,
      _ => Icons.location_on_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final backendMode = CustomerApi.instance.hasCustomerSession;
    return Scaffold(
      backgroundColor: SavedAddressesPage._background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Saved Addresses',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: !backendMode
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Sign in to access saved addresses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SavedAddressesPage._secondaryText,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            : _loading && _addresses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && _addresses.isEmpty
            ? _buildLoadError()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Your saved addresses',
                        style: const TextStyle(
                          color: SavedAddressesPage._secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  if (_loadError != null) _buildLoadErrorBanner(),
                  Expanded(
                    child: _addresses.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                            itemCount: _addresses.length + 1,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              if (index == _addresses.length) {
                                return _buildAddAddressButton(context);
                              }
                              return _buildAddressCard(
                                context,
                                _addresses[index],
                              );
                            },
                          ),
                  ),
                  if (_addresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: _buildAddAddressButton(context),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, SavedAddress address) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SavedAddressesPage._border),
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
                  color: SavedAddressesPage._lightGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  address.icon,
                  color: SavedAddressesPage._green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  address.label,
                  style: const TextStyle(
                    color: SavedAddressesPage._mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => _editAddress(address),
                tooltip: 'Edit address',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: SavedAddressesPage._green,
                  size: 21,
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => _deleteAddress(address),
                tooltip: 'Delete address',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: SavedAddressesPage._secondaryText,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            address.address,
            style: const TextStyle(
              color: SavedAddressesPage._secondaryText,
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
        onPressed: _saving ? null : _addAddress,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add New Address',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: SavedAddressesPage._green,
          backgroundColor: SavedAddressesPage._lightGreen,
          side: const BorderSide(color: SavedAddressesPage._green),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: SavedAddressesPage._green,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              'No saved addresses yet.',
              style: TextStyle(color: SavedAddressesPage._mainText),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: SavedAddressesPage._secondaryText,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SavedAddressesPage._secondaryText),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loading ? null : _loadAddresses,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(
                color: SavedAddressesPage._secondaryText,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _loadAddresses,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAddress() async {
    if (!CustomerApi.instance.hasCustomerSession) {
      _showAuthenticationRequired();
      return;
    }
    final result = await _showAddressEditor();
    if (result == null || !mounted) return;
    await _runAddressMutation(() async {
      final saved = await CustomerApi.instance.createSavedAddress(
        label: result.label,
        address: _addressPayload(result),
      );
      if (mounted) {
        setState(() => _addresses = [..._addresses, _toSavedAddress(saved)]);
      }
    });
  }

  Future<void> _editAddress(SavedAddress address) async {
    if (!CustomerApi.instance.hasCustomerSession || !address.isBackendData) {
      _showAuthenticationRequired();
      return;
    }
    final result = await _showAddressEditor(existing: address);
    if (result == null || !mounted) return;
    await _runAddressMutation(() async {
      final updated = await CustomerApi.instance.updateSavedAddress(
        address.id,
        label: result.label,
        address: _addressPayload(result),
      );
      if (!mounted) return;
      setState(() {
        _addresses = _addresses
            .map(
              (item) => item.id == address.id ? _toSavedAddress(updated) : item,
            )
            .toList(growable: false);
      });
    });
  }

  Map<String, Object?> _addressPayload(_AddressFormResult result) => {
    'formattedAddress': result.address,
    if (result.pincode.isNotEmpty) 'pincode': result.pincode,
    if (result.latitude != null) 'latitude': result.latitude,
    if (result.longitude != null) 'longitude': result.longitude,
  };

  Future<void> _deleteAddress(SavedAddress address) async {
    if (!CustomerApi.instance.hasCustomerSession || !address.isBackendData) {
      _showAuthenticationRequired();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${address.label} from saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAddressMutation(() async {
      await CustomerApi.instance.deleteSavedAddress(address.id);
      if (mounted) {
        setState(() {
          _addresses = _addresses
              .where((item) => item.id != address.id)
              .toList(growable: false);
        });
      }
    });
  }

  void _showAuthenticationRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to manage saved addresses.')),
    );
  }

  Future<void> _runAddressMutation(Future<void> Function() operation) async {
    setState(() => _saving = true);
    try {
      await operation();
    } on CustomerApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_AddressFormResult?> _showAddressEditor({SavedAddress? existing}) {
    return showDialog<_AddressFormResult>(
      context: context,
      builder: (context) => _AddressEditorDialog(existing: existing),
    );
  }
}

class _AddressFormResult {
  const _AddressFormResult({
    required this.label,
    required this.address,
    required this.pincode,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final String address;
  final String pincode;
  final double? latitude;
  final double? longitude;
}

class _AddressEditorDialog extends StatefulWidget {
  const _AddressEditorDialog({this.existing});

  final SavedAddress? existing;

  @override
  State<_AddressEditorDialog> createState() => _AddressEditorDialogState();
}

class _AddressEditorDialogState extends State<_AddressEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label);
    _addressController = TextEditingController(text: widget.existing?.address);
    _pincodeController = TextEditingController(
      text: widget.existing?.pincode ?? '',
    );
    _latitudeController = TextEditingController(
      text: widget.existing?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: widget.existing?.longitude?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit Address' : 'Add New Address'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('saved-address-label'),
              controller: _labelController,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Address Label'),
              validator: (value) {
                final label = value?.trim() ?? '';
                if (label.isEmpty) return 'Enter an address label.';
                if (label.length > 40) return 'Use 40 characters or fewer.';
                return null;
              },
            ),
            TextFormField(
              key: const ValueKey('saved-address-formatted'),
              controller: _addressController,
              maxLength: 500,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Full Address'),
              validator: (value) {
                if (value?.trim().isNotEmpty != true) {
                  return 'Enter the full address.';
                }
                return null;
              },
            ),
            TextFormField(
              key: const ValueKey('saved-address-pincode'),
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit Pincode'),
              validator: (value) {
                final pincode = value?.trim() ?? '';
                if (pincode.isNotEmpty &&
                    !RegExp(r'^\d{6}$').hasMatch(pincode)) {
                  return 'Enter a valid 6-digit pincode.';
                }
                return null;
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('saved-address-latitude'),
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: _validateLatitude,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('saved-address-longitude'),
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: _validateLongitude,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('saved-address-save'),
          onPressed: _submit,
          child: Text(editing ? 'Save Changes' : 'Save Address'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _AddressFormResult(
        label: _labelController.text.trim(),
        address: _addressController.text.trim(),
        pincode: _pincodeController.text.trim(),
        latitude: double.tryParse(_latitudeController.text.trim()),
        longitude: double.tryParse(_longitudeController.text.trim()),
      ),
    );
  }

  String? _validateLatitude(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final latitude = double.tryParse(text);
    if (latitude == null ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90) {
      return 'Invalid latitude';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final longitude = double.tryParse(text);
    if (longitude == null ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      return 'Invalid longitude';
    }
    return null;
  }
}
