import 'package:flutter/foundation.dart';

import '../models/local_store.dart';

class LocalStoreSession extends ChangeNotifier {
  LocalStoreSession._();

  static final instance = LocalStoreSession._();

  LocalStore? _selectedStore;

  LocalStore? get selectedStore => _selectedStore;
  String? get selectedStoreId => _selectedStore?.id;
  String? get selectedStoreName => _selectedStore?.name;

  void select(LocalStore store) {
    _selectedStore = store;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedStore == null) return;
    _selectedStore = null;
    notifyListeners();
  }
}
