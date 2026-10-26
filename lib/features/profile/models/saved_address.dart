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

const demoSavedAddresses = [
  SavedAddress(
    id: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    address: '12 Green Park Road, Ravulapalem',
  ),
  SavedAddress(
    id: 'work',
    label: 'Work',
    icon: Icons.business_outlined,
    address: '24 Market Street, Ravulapalem',
  ),
  SavedAddress(
    id: 'other',
    label: 'Other',
    icon: Icons.location_on_outlined,
    address: '8 River View Lane, Ravulapalem',
  ),
];
