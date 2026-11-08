import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rider.dart';

/// Handles mock login/OTP and remembers the signed-in rider on this phone.
class AuthService extends ChangeNotifier {
  static const _prefsKey = 'myshopzy_rider_profile';
  static const _tokenKey = 'myshopzy_auth_token';
  static const _accountsKey = 'myshopzy_accounts';
  static const _mockToken = 'mock_auth_token';

  Rider? _rider;
  String? _token;
  String? _pendingOtp;
  String? _pendingName;
  String? _pendingPhone;
  String? _pendingPassword;
  String? _pendingResetPhone;
  DateTime? _lockedUntil;
  int _failedSignInAttempts = 0;

  Rider? get rider => _rider;
  String? get token => _token;
  String? get demoOtp => _pendingOtp;
  bool get isLoggedIn => _rider != null;
  Duration? get lockedFor {
    final until = _lockedUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _lockedUntil = null;
      _failedSignInAttempts = 0;
      return null;
    }
    return remaining;
  }

  /// Call this once when the app starts, to see if a rider is already
  /// signed in on this phone (so they don't have to log in every time).
  Future<void> loadSavedRider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      _rider = Rider.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _token = prefs.getString(_tokenKey);
      notifyListeners();
    }
  }

  /// Step 1 of login. Replace the mock implementation with the SMS request.
  Future<void> requestOtp({
    required String name,
    required String phone,
    String? password,
  }) async {
    final pendingPassword = phone == _pendingPhone ? _pendingPassword : null;
    _pendingName = name;
    _pendingPhone = phone;
    _pendingPassword = password ?? pendingPassword;
    _pendingResetPhone = null;
    _pendingOtp = (1000 + Random().nextInt(9000)).toString();
  }

  /// Step 2 of login. A wrong code returns false; storage/network errors throw.
  Future<bool> verifyOtp(String enteredCode) async {
    if (_pendingOtp == null || enteredCode != _pendingOtp) {
      return false;
    }
    final rider = Rider(name: _pendingName!, phone: _pendingPhone!);
    final prefs = await SharedPreferences.getInstance();
    final password = _pendingPassword;
    if (password != null) {
      final accounts = _readAccounts(prefs);
      final salt = _newSalt();
      accounts[rider.phone] = {
        'name': rider.name,
        'passwordHash': _hashPassword(salt, password),
        'salt': salt,
      };
      await prefs.setString(_accountsKey, jsonEncode(accounts));
    }
    await prefs.setString(_prefsKey, jsonEncode(rider.toJson()));
    await prefs.setString(_tokenKey, _mockToken);
    _rider = rider;
    _token = _mockToken;
    _pendingOtp = null;
    _pendingPassword = null;
    notifyListeners();
    return true;
  }

  Future<bool> signIn({
    required String phone,
    required String password,
  }) async {
    if (lockedFor != null) return false;
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final prefs = await SharedPreferences.getInstance();
    final account = _readAccounts(prefs)[phone];
    final salt = account?['salt'];
    final expectedHash = account?['passwordHash'];
    if (account == null ||
        salt is! String ||
        expectedHash is! String ||
        _hashPassword(salt, password) != expectedHash) {
      _failedSignInAttempts++;
      if (_failedSignInAttempts >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      return false;
    }

    _failedSignInAttempts = 0;
    _lockedUntil = null;
    final rider = Rider(name: account['name'] as String, phone: phone);
    await _saveLogin(rider, prefs);
    return true;
  }

  Future<void> requestPasswordReset(String phone) async {
    final account = _readAccounts(await SharedPreferences.getInstance())[phone];
    if (account == null) throw StateError('phone_not_found');
    _pendingResetPhone = phone;
    _pendingOtp = (1000 + Random().nextInt(9000)).toString();
  }

  Future<bool> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    if (_pendingResetPhone != phone ||
        _pendingOtp == null ||
        otp != _pendingOtp) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final accounts = _readAccounts(prefs);
    final account = accounts[phone];
    if (account == null) return false;
    final salt = _newSalt();
    accounts[phone] = {
      'name': account['name'],
      'passwordHash': _hashPassword(salt, newPassword),
      'salt': salt,
    };
    await prefs.setString(_accountsKey, jsonEncode(accounts));
    _pendingOtp = null;
    _pendingResetPhone = null;
    _pendingPassword = null;
    _failedSignInAttempts = 0;
    _lockedUntil = null;
    return true;
  }

  static String? validatePassword(String p, {String? phone}) {
    if (p.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(p) ||
        !RegExp(r'\d').hasMatch(p) ||
        RegExp(r'\s').hasMatch(p) ||
        (phone != null && p == phone)) {
      return 'err_password_rules';
    }
    return null;
  }

  static int passwordStrength(String p) {
    if (p.isEmpty) return 0;
    final basicRules = p.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(p) &&
        RegExp(r'\d').hasMatch(p) &&
        !RegExp(r'\s').hasMatch(p);
    if (!basicRules) return 1;
    final hasVariety = RegExp(r'[a-z]').hasMatch(p) &&
        RegExp(r'[A-Z]').hasMatch(p) &&
        (RegExp(r'\W').hasMatch(p) || p.length >= 12);
    return hasVariety ? 3 : 2;
  }

  static Map<String, Map<String, dynamic>> _readAccounts(
      SharedPreferences prefs) {
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (phone, account) => MapEntry(
        phone,
        Map<String, dynamic>.from(account as Map),
      ),
    );
  }

  static String _newSalt() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _hashPassword(String salt, String password) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  Future<void> _saveLogin(Rider rider, SharedPreferences prefs) async {
    await prefs.setString(_prefsKey, jsonEncode(rider.toJson()));
    await prefs.setString(_tokenKey, _mockToken);
    _rider = rider;
    _token = _mockToken;
    notifyListeners();
  }

  /// Saves a changed name / vehicle for the signed-in rider.
  Future<void> updateProfile({
    required String name,
    required String vehicleType,
    required String vehicleNumber,
  }) async {
    final r = _rider;
    if (r == null) return;
    _rider = r.copyWith(
        name: name, vehicleType: vehicleType, vehicleNumber: vehicleNumber);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_rider!.toJson()));
    final accounts = _readAccounts(prefs);
    final account = accounts[r.phone];
    if (account != null) {
      accounts[r.phone] = {...account, 'name': name};
      await prefs.setString(_accountsKey, jsonEncode(accounts));
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _rider = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_tokenKey);
    _token = null;
    notifyListeners();
  }
}
