import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/kyc.dart';
import 'kyc_repository.dart';

class MockKycService implements KycRepository {
  static const _prefsKey = 'myshopzy_kyc';
  static const _realDecisionDelay = Duration(seconds: 15);

  Duration get _decisionDelay =>
      AppConfig.kycDemoMode ? const Duration(seconds: 3) : _realDecisionDelay;

  static String approveMode = 'approve';

  final StreamController<KycData> _updates =
      StreamController<KycData>.broadcast();
  KycData _data = const KycData();
  Timer? _decisionTimer;
  bool _disposed = false;
  bool _decisionRunning = false;

  @override
  Stream<KycData> get statusUpdates => _updates.stream;

  @override
  Future<KycData> fetchKyc() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      _data = const KycData();
    } else {
      _data = KycData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    if (_data.status == KycStatus.pending) {
      _resumeDecision();
    }
    return _data;
  }

  @override
  Future<void> submitKyc(KycData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _data = data.copyWith(
      status: KycStatus.pending,
      submittedAt: DateTime.now(),
      clearRejectReason: true,
    );
    await _save();
    _publish(_data);
    _scheduleDecision(_decisionDelay);
  }

  @override
  Future<KycData> approveDemo() async {
    if (!AppConfig.kycDemoMode) {
      throw StateError('Demo KYC approval is disabled.');
    }
    _decisionTimer?.cancel();
    _data = _data.copyWith(
      status: KycStatus.approved,
      submittedAt: _data.submittedAt ?? DateTime.now(),
      clearRejectReason: true,
    );
    await _save();
    _publish(_data);
    return _data;
  }

  void _resumeDecision() {
    _decisionTimer?.cancel();
    final submittedAt = _data.submittedAt;
    final elapsed = submittedAt == null
        ? _decisionDelay
        : DateTime.now().difference(submittedAt);
    final remaining = _decisionDelay - elapsed;
    if (remaining <= Duration.zero) {
      unawaited(_decide());
    } else {
      _scheduleDecision(remaining);
    }
  }

  void _scheduleDecision(Duration delay) {
    _decisionTimer?.cancel();
    _decisionTimer = Timer(delay, () => unawaited(_decide()));
  }

  Future<void> _decide() async {
    if (_data.status != KycStatus.pending || _decisionRunning) return;
    _decisionRunning = true;
    try {
      final shouldApprove = AppConfig.kycDemoMode
          ? approveMode != 'reject'
          : switch (approveMode) {
              'reject' => false,
              'random' => Random().nextBool(),
              _ => true,
            };
      _data = _data.copyWith(
        status: shouldApprove ? KycStatus.approved : KycStatus.rejected,
        rejectReason: shouldApprove ? null : 'kyc_reject_unclear_aadhaar',
        clearRejectReason: shouldApprove,
      );
      await _save();
      _publish(_data);
    } finally {
      _decisionRunning = false;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_data.toJson()));
  }

  void _publish(KycData data) {
    if (!_disposed) _updates.add(data);
  }

  @override
  Future<void> reset() async {
    _decisionTimer?.cancel();
    _decisionTimer = null;
    _data = const KycData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _publish(_data);
  }

  @override
  void dispose() {
    _disposed = true;
    _decisionTimer?.cancel();
    _updates.close();
  }
}
