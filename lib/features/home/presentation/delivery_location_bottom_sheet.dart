import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme/app_theme.dart';
import '../../profile/models/saved_address.dart';

class DeliveryLocationBottomSheet extends StatefulWidget {
  const DeliveryLocationBottomSheet({
    required this.onViewAll,
    required this.onEnterManually,
    super.key,
  });

  final VoidCallback onViewAll;
  final VoidCallback onEnterManually;

  @override
  State<DeliveryLocationBottomSheet> createState() =>
      _DeliveryLocationBottomSheetState();
}

class _DeliveryLocationBottomSheetState
    extends State<DeliveryLocationBottomSheet> {
  static const _blue = Color(0xFF1769AA);
  static const _paleBlue = Color(0xFFEAF4FF);
  static const _divider = Color(0xFFE8ECEF);

  bool _isLoadingLocation = false;

  Future<void> _requestCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        if (!await Geolocator.isLocationServiceEnabled()) {
          _showLocationMessage(
            'Turn on device location, then tap GRANT to try again.',
          );
          return;
        }
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationMessage('Location permission was denied.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        _showLocationMessage(
          'Allow location access in app settings, then tap GRANT again.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;

      Navigator.of(context).pop(
        SavedAddress(
          id: 'current-location',
          label: 'Current location',
          address:
              '${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}',
          icon: Icons.my_location_rounded,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on LocationServiceDisabledException {
      _showLocationMessage('Turn on device location, then tap GRANT again.');
    } on PermissionDeniedException {
      _showLocationMessage(
        'Location permission is required to find your location.',
      );
    } on TimeoutException {
      _showLocationMessage(
        'Your location request timed out. Please try again.',
      );
    } on PlatformException {
      _showLocationMessage('Your location is temporarily unavailable.');
    } on MissingPluginException {
      _showLocationMessage('Location services are unavailable on this device.');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                            _isLoadingLocation
                                ? 'Finding your location...'
                                : 'Location Permission is Off',
                            style: TextStyle(
                              color: AppTheme.primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Turn on location to find your delivery area.',
                            style: TextStyle(
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
                      onPressed: _isLoadingLocation
                          ? null
                          : _requestCurrentLocation,
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
                          : const Text(
                              'GRANT',
                              style: TextStyle(
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
                    onPressed: widget.onViewAll,
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
              for (var index = 0; index < demoSavedAddresses.length; index++)
                _buildAddressRow(context, demoSavedAddresses[index], index),
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
          label: '${address.label}, Demo address: ${address.address}',
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
                          'Demo address: ${address.address}',
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
