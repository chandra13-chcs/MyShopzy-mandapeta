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
  List<SavedAddress> _addresses = demoSavedAddresses;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (CustomerApi.instance.isConfigured) {
      _addresses = const [];
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
    final backendMode = CustomerApi.instance.isConfigured;
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
        child: _loading && _addresses.isEmpty
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
                        backendMode
                            ? 'Backend saved addresses'
                            : 'Demo addresses · changes are local only',
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
            '${address.isBackendData ? '' : 'Demo address: '}${address.address}',
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
    final result = await _showAddressEditor();
    if (result == null || !mounted) return;
    if (!CustomerApi.instance.isConfigured) {
      setState(() {
        _addresses = [
          ..._addresses,
          SavedAddress(
            id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
            label: result.label,
            address: result.address,
            icon: _addressIcon(result.label),
          ),
        ];
      });
      return;
    }
    await _runAddressMutation(() async {
      final saved = await CustomerApi.instance.createSavedAddress(
        label: result.label,
        address: {'formattedAddress': result.address},
      );
      if (mounted) {
        setState(() => _addresses = [..._addresses, _toSavedAddress(saved)]);
      }
    });
  }

  Future<void> _editAddress(SavedAddress address) async {
    final result = await _showAddressEditor(existing: address);
    if (result == null || !mounted) return;
    if (!CustomerApi.instance.isConfigured || !address.isBackendData) {
      setState(() {
        _addresses = _addresses
            .map(
              (item) => item.id == address.id
                  ? SavedAddress(
                      id: item.id,
                      label: result.label,
                      address: result.address,
                      icon: _addressIcon(result.label),
                    )
                  : item,
            )
            .toList(growable: false);
      });
      return;
    }
    await _runAddressMutation(() async {
      final updated = await CustomerApi.instance.updateSavedAddress(
        address.id,
        label: result.label,
        address: {'formattedAddress': result.address},
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

  Future<void> _deleteAddress(SavedAddress address) async {
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
    if (!CustomerApi.instance.isConfigured || !address.isBackendData) {
      setState(() {
        _addresses = _addresses
            .where((item) => item.id != address.id)
            .toList(growable: false);
      });
      return;
    }
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
  const _AddressFormResult({required this.label, required this.address});

  final String label;
  final String address;
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

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label);
    _addressController = TextEditingController(text: widget.existing?.address);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
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
      ),
    );
  }
}
