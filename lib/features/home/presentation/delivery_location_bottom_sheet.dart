import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../parcel/data/parcel_location_service.dart';
import '../../profile/models/saved_address.dart';

class DeliveryLocationBottomSheet extends StatefulWidget {
  const DeliveryLocationBottomSheet({
    required this.onViewAll,
    required this.onEnterManually,
    this.locationService,
    super.key,
  });

  final VoidCallback onViewAll;
  final VoidCallback onEnterManually;
  final ParcelLocationService? locationService;

  @override
  State<DeliveryLocationBottomSheet> createState() =>
      _DeliveryLocationBottomSheetState();
}

class _DeliveryLocationBottomSheetState
    extends State<DeliveryLocationBottomSheet>
    with WidgetsBindingObserver {
  static const _blue = Color(0xFF1769AA);
  static const _paleBlue = Color(0xFFEAF4FF);
  static const _divider = Color(0xFFE8ECEF);

  bool _isLoadingLocation = false;
  bool _isOpeningSettings = false;
  bool? _locationServicesEnabled;
  LocationPermission? _permission;
  String? _locationError;
  List<SavedAddress> _savedAddresses = const [];
  bool _loadingSavedAddresses = false;
  String? _savedAddressesError;

  late final ParcelLocationService _locationService =
      widget.locationService ?? ParcelLocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshLocationStatus());
    if (CustomerApi.instance.hasCustomerSession) {
      unawaited(_loadSavedAddresses());
    }
  }

  Future<void> _loadSavedAddresses() async {
    setState(() {
      _loadingSavedAddresses = true;
      _savedAddressesError = null;
    });
    try {
      final addresses = await CustomerApi.instance.getSavedAddresses();
      if (!mounted) return;
      setState(() {
        _savedAddresses = addresses
            .map(
              (address) => SavedAddress(
                id: address.id,
                label: address.label,
                address: address.formattedAddress,
                icon: Icons.location_on_outlined,
                isBackendData: true,
                latitude: address.latitude,
                longitude: address.longitude,
                pincode: address.pincode,
              ),
            )
            .toList(growable: false);
      });
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _savedAddressesError = error.message);
    } finally {
      if (mounted) setState(() => _loadingSavedAddresses = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOpeningSettings) {
      _isOpeningSettings = false;
      unawaited(_refreshLocationStatus(fetchWhenAvailable: true));
    }
  }

  Future<void> _refreshLocationStatus({bool fetchWhenAvailable = false}) async {
    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      final permission = await _locationService.checkPermission();
      if (!mounted) return;
      setState(() {
        _locationServicesEnabled = serviceEnabled;
        _permission = permission;
        _locationError = null;
      });
      if (fetchWhenAvailable &&
          serviceEnabled &&
          _hasForegroundPermission(permission)) {
        await _requestCurrentLocation(requestPermission: false);
      }
    } on ParcelLocationException catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.message);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _locationServicesEnabled = null;
        _locationError =
            'Location is unavailable right now. Choose your location manually.';
      });
      debugPrint('Unable to check location status: $error');
    }
  }

  bool _hasForegroundPermission(LocationPermission? permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  String get _locationTitle {
    if (_isLoadingLocation) return 'Finding your location...';
    if (_locationServicesEnabled == null || _permission == null) {
      return 'Checking location access...';
    }
    if (!_locationServicesEnabled!) return 'Device location is off';
    if (_permission == LocationPermission.deniedForever) {
      return 'Location access is permanently denied';
    }
    if (_permission == LocationPermission.denied) {
      return 'Location access is off';
    }
    return 'Location access is on';
  }

  String get _locationDescription {
    if (_locationError != null) return _locationError!;
    if (_locationServicesEnabled == null || _permission == null) {
      return 'Checking permission and device location settings.';
    }
    if (!_locationServicesEnabled!) {
      return 'Turn on device location to find your delivery area.';
    }
    if (_permission == LocationPermission.deniedForever) {
      return 'Allow location in app settings, or choose an address manually.';
    }
    if (_permission == LocationPermission.denied) {
      return 'Allow location access to find your delivery area, or choose an address manually.';
    }
    return 'Use your current location or choose an address manually.';
  }

  String get _locationActionLabel {
    if (_locationServicesEnabled == false) return 'ENABLE';
    if (_permission == LocationPermission.deniedForever) return 'SETTINGS';
    if (_permission == null || _locationServicesEnabled == null) return '';
    return _permission == LocationPermission.denied ? 'GRANT' : 'USE';
  }

  Future<void> _handleLocationAction() async {
    if (_locationServicesEnabled == false) {
      _isOpeningSettings = true;
      try {
        await _locationService.openLocationSettings();
      } on Exception catch (error) {
        _isOpeningSettings = false;
        if (mounted) {
          setState(
            () => _locationError = 'Could not open device location settings. Choose your location manually.',
          );
        }
        debugPrint('Unable to open device location settings: $error');
      }
      return;
    }
    if (_permission == LocationPermission.deniedForever) {
      _isOpeningSettings = true;
      try {
        await _locationService.openAppSettings();
      } on Exception catch (error) {
        _isOpeningSettings = false;
        if (mounted) {
          setState(
            () => _locationError =
                'Could not open app settings. Choose your location manually.',
          );
        }
        debugPrint('Unable to open app settings: $error');
      }
      return;
    }
    await _requestCurrentLocation(requestPermission: true);
  }

  Future<void> _requestCurrentLocation({
    required bool requestPermission,
  }) async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);
    try {
      final location = await _locationService.detectCurrentLocation(
        requestPermission: requestPermission,
      );
      if (!mounted) return;

      Navigator.of(context).pop(
        SavedAddress(
          id: 'current-location',
          label: 'Current location',
          address: location.address,
          icon: Icons.my_location_rounded,
          latitude: location.latitude,
          longitude: location.longitude,
          pincode: location.pincode,
        ),
      );
    } on ParcelLocationException catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.message);
      await _refreshLocationStatus();
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D9DC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                decoration: BoxDecoration(
                  color: _paleBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD6E8FC)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: _blue,
                      size: 24,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _locationTitle,
                            style: TextStyle(
                              color: AppTheme.primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _locationDescription,
                            style: const TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      key: const ValueKey('location-permission-grant'),
                      onPressed:
                          _isLoadingLocation || _locationActionLabel.isEmpty
                          ? null
                          : _handleLocationAction,
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _locationActionLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Delivery Address',
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('location-view-all'),
                    onPressed: CustomerApi.instance.hasCustomerSession
                        ? widget.onViewAll
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      minimumSize: const Size(64, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'VIEW ALL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              if (_loadingSavedAddresses)
                const LinearProgressIndicator()
              else if (!CustomerApi.instance.hasCustomerSession)
                const Text(
                  'Sign in to access saved addresses.',
                  style: TextStyle(color: AppTheme.secondaryText),
                )
              else if (_savedAddressesError != null)
                Text(
                  _savedAddressesError!,
                  style: const TextStyle(color: AppTheme.secondaryText),
                )
              else if (_savedAddresses.isEmpty)
                const Text(
                  'No saved addresses yet.',
                  style: TextStyle(color: AppTheme.secondaryText),
                )
              else
                for (var index = 0; index < _savedAddresses.length; index++)
                  _buildAddressRow(context, _savedAddresses[index], index),
              const SizedBox(height: 12),
              const Divider(height: 1, color: _divider),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const ValueKey('location-enter-manually'),
                  onPressed: widget.onEnterManually,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 21),
                  label: const Text('Enter Location Manually'),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppTheme.primaryGreen,
                    minimumSize: const Size(44, 48),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressRow(
    BuildContext context,
    SavedAddress address,
    int index,
  ) {
    return Column(
      children: [
        if (index > 0) const Divider(height: 1, color: _divider),
        Semantics(
          button: true,
          label: '${address.label}: ${address.address}',
          child: InkWell(
            key: ValueKey('saved-delivery-address-${address.id}'),
            onTap: () => Navigator.of(context).pop(address),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.lightBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      address.icon,
                      color: AppTheme.primaryGreen,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.label,
                          style: const TextStyle(
                            color: AppTheme.primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.secondaryText,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
