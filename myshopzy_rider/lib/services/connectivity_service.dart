import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connectivity_probe_stub.dart'
    if (dart.library.io) 'connectivity_probe_io.dart'
    if (dart.library.js_interop) 'connectivity_probe_web.dart' as probe;

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._() {
    if (kIsWeb) {
      _webSubscription = probe.connectionChanges.listen(_setOnline);
    }
  }

  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool _isChecking = false;
  int _consecutiveFailures = 0;
  StreamSubscription<bool>? _webSubscription;

  bool get isOnline => _isOnline;
  bool get isChecking => _isChecking;

  Future<void> check() async {
    if (_isChecking) return;
    _isChecking = true;
    notifyListeners();
    try {
      final online = await probe.hasInternetConnection();
      if (kIsWeb) {
        _consecutiveFailures = 0;
        _setOnline(online);
      } else if (online) {
        _consecutiveFailures = 0;
        _setOnline(true);
      } else {
        _consecutiveFailures++;
        if (_consecutiveFailures >= 2) _setOnline(false);
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  void reportRepositoryFailure() {
    if (kIsWeb) {
      _setOnline(false);
    } else {
      unawaited(check());
    }
  }

  void reportRepositorySuccess() {
    _consecutiveFailures = 0;
    _setOnline(true);
  }

  void _setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _webSubscription?.cancel();
    super.dispose();
  }
}
