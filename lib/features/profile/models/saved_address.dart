import 'package:flutter/material.dart';

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.icon,
    this.isBackendData = false,
    this.latitude,
    this.longitude,
    this.pincode,
    this.receiverName,
    this.receiverMobile,
    this.landmark,
  });

  final String id;
  final String label;
  final String address;
  final IconData icon;
  final bool isBackendData;
  final double? latitude;
  final double? longitude;
  final String? pincode;
  final String? receiverName;
  final String? receiverMobile;
  final String? landmark;
}
