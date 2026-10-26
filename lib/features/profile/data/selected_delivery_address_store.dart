import 'package:flutter/foundation.dart';

import '../models/saved_address.dart';

class SelectedDeliveryAddressStore {
  SelectedDeliveryAddressStore._();

  static final instance = SelectedDeliveryAddressStore._();

  final ValueNotifier<SavedAddress?> _selectedAddress =
      ValueNotifier<SavedAddress?>(null);

  SavedAddress? get selectedAddress => _selectedAddress.value;

  ValueListenable<SavedAddress?> get listenable => _selectedAddress;

  void select(SavedAddress? address) {
    _selectedAddress.value = address;
  }
}
