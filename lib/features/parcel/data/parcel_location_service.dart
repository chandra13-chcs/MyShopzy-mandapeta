import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class ParcelLocationException implements Exception {
  const ParcelLocationException(this.message, {this.action});

  final String message;
  final ParcelLocationAction? action;
}

enum ParcelLocationAction { openAppSettings, openLocationSettings }

class DetectedLocation {
  const DetectedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.pickupAddress,
    this.pincode,
  });

  final double latitude;
  final double longitude;
  final String address;
  final String pickupAddress;
  final String? pincode;
}

class ParcelLocationService {
  ParcelLocationService({
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position> Function()? getCurrentPosition,
    Future<List<Placemark>> Function(double latitude, double longitude)?
    reverseGeocode,
    Future<bool> Function()? openLocationSettings,
    Future<bool> Function()? openAppSettings,
  }) : _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _getCurrentPosition =
           getCurrentPosition ??
           (() => Geolocator.getCurrentPosition(
             desiredAccuracy: LocationAccuracy.high,
             timeLimit: const Duration(seconds: 15),
           )),
       _reverseGeocode = reverseGeocode ?? placemarkFromCoordinates,
       _openLocationSettings =
           openLocationSettings ?? Geolocator.openLocationSettings,
       _openAppSettings = openAppSettings ?? Geolocator.openAppSettings;

  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position> Function() _getCurrentPosition;
  final Future<List<Placemark>> Function(double, double) _reverseGeocode;
  final Future<bool> Function() _openLocationSettings;
  final Future<bool> Function() _openAppSettings;

  Future<bool> isLocationServiceEnabled() => _isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => _checkPermission();

  Future<LocationPermission> requestPermission() => _requestPermission();

  Future<bool> openLocationSettings() => _openLocationSettings();

  Future<bool> openAppSettings() => _openAppSettings();

  Future<String> detectPickupAddress() async {
    final location = await detectCurrentLocation(requestPermission: true);
    if (location.pickupAddress.isEmpty) {
      throw const ParcelLocationException(
        'Could not find an address for your location. Enter the pickup address manually.',
      );
    }
    return location.pickupAddress;
  }

  Future<DetectedLocation> detectCurrentLocation({
    bool requestPermission = false,
  }) async {
    try {
      if (!await _isLocationServiceEnabled()) {
        throw const ParcelLocationException(
          'Location services are off. Turn on GPS or enter the pickup address manually.',
          action: ParcelLocationAction.openLocationSettings,
        );
      }

      var permission = await _checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await _requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const ParcelLocationException(
          'Location permission is permanently denied. Enable it in app settings or choose your location manually.',
          action: ParcelLocationAction.openAppSettings,
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const ParcelLocationException(
          'Location permission was denied. Allow location access or enter the pickup address manually.',
        );
      }

      final position = await _getCurrentPosition();
      var address = 'Choose your location';
      var pickupAddress = '';
      String? pincode;
      // The geocoding plugin has no web implementation.
      if (!kIsWeb) {
        try {
          final placemarks = await _reverseGeocode(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 10));
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            final readableAddress = _formatAddress(placemark);
            if (readableAddress.isNotEmpty) address = readableAddress;
            pickupAddress = _formatPickupAddress(placemark);
            if (pickupAddress.isEmpty) pickupAddress = readableAddress;
            final postalCode = placemark.postalCode?.trim();
            if (postalCode != null && postalCode.isNotEmpty) {
              pincode = postalCode;
            }
          }
        } on NoResultFoundException {
          // Keep the friendly fallback when the platform has no geocoding result.
        } on TimeoutException {
          // The GPS position is still useful even if reverse geocoding times out.
        } on PlatformException {
          // Geocoding is optional; never expose coordinates as a customer address.
        } on MissingPluginException {
          // Geocoding may be unavailable on some platforms.
        } on TypeError {
          // Unsupported geocoding implementations can fail during method lookup.
        }
      }
      return DetectedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        pickupAddress: pickupAddress,
        pincode: pincode,
      );
    } on NoResultFoundException {
      throw const ParcelLocationException(
        'Could not find an address for your location. Enter the pickup address manually.',
      );
    } on ParcelLocationException {
      rethrow;
    } on TimeoutException {
      throw const ParcelLocationException(
        'Location lookup timed out. Try again or enter the pickup address manually.',
      );
    } on LocationServiceDisabledException {
      throw const ParcelLocationException(
        'Location services are off. Turn on GPS or enter the pickup address manually.',
      );
    } on PermissionDeniedException {
      throw const ParcelLocationException(
        'Location permission was denied. Allow location access or enter the pickup address manually.',
      );
    } on PlatformException {
      throw const ParcelLocationException(
        'Your device could not resolve the current location or address. Try again or enter the pickup address manually.',
      );
    } on MissingPluginException {
      throw const ParcelLocationException(
        'Location lookup is unavailable on this device. Enter the pickup address manually.',
      );
    }
  }

  String _formatAddress(Placemark placemark) {
    final road = placemark.street?.trim();
    final primary = road == null || road.isEmpty
        ? placemark.name?.trim()
        : road;
    final localityCandidates = [
      placemark.subLocality,
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
    ];
    final parts = <String>[];
    if (primary != null && primary.isNotEmpty) parts.add(primary);
    for (final candidate in localityCandidates) {
      final locality = candidate?.trim();
      if (locality != null &&
          locality.isNotEmpty &&
          !parts.any((part) => part.toLowerCase() == locality.toLowerCase())) {
        parts.add(locality);
        break;
      }
    }
    return parts.join(', ');
  }

  String _formatPickupAddress(Placemark placemark) {
    final parts =
        [
              placemark.name,
              placemark.street,
              placemark.subLocality,
              placemark.locality,
              placemark.subAdministrativeArea,
              placemark.administrativeArea,
              placemark.postalCode,
              placemark.country,
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(growable: false);
    return parts.toSet().join(', ');
  }
}
