import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_config.dart';
import '../models/kyc.dart';
import 'kyc_repository.dart';
import 'rider_controller.dart';

class KycService extends ChangeNotifier {
  KycService({
    required KycRepository repository,
    required RiderController riderController,
  })  : _repository = repository,
        _riderController = riderController {
    _statusSubscription = _repository.statusUpdates.listen(_onStatusUpdate);
  }

  final KycRepository _repository;
  final RiderController _riderController;
  StreamSubscription<KycData>? _statusSubscription;

  KycData data = const KycData();
  bool loading = false;
  bool submitting = false;
  bool loaded = false;
  String? errorKey;
  int _statusRevision = 0;

  bool get isApproved => data.status == KycStatus.approved;
  bool get isPending => data.status == KycStatus.pending;

  Future<void> load() async {
    loading = true;
    errorKey = null;
    notifyListeners();
    final revisionBeforeFetch = _statusRevision;
    try {
      final fetched = await _repository.fetchKyc();
      if (revisionBeforeFetch == _statusRevision) {
        data = fetched;
        _riderController.setKycApproved(isApproved);
      }
      loaded = true;
    } catch (_) {
      errorKey = 'kyc_load_error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> submit(KycData submission) async {
    if (submitting) return 'kyc_submit_error';
    submitting = true;
    errorKey = null;
    notifyListeners();
    try {
      await _repository.submitKyc(submission);
      data = data.copyWith(
        aadhaarNumber: submission.aadhaarNumber,
        panNumber: submission.panNumber,
        aadhaarPhotoPath: submission.aadhaarPhotoPath,
        panPhotoPath: submission.panPhotoPath,
        passportPhotoPath: submission.passportPhotoPath,
        status: KycStatus.pending,
        submittedAt: DateTime.now(),
        clearRejectReason: true,
      );
      loaded = true;
      _riderController.setKycApproved(false);
      return null;
    } catch (_) {
      errorKey = 'kyc_submit_error';
      return errorKey;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<String?> approveDemo() async {
    if (!AppConfig.kycDemoMode || submitting) return 'kyc_submit_error';
    submitting = true;
    errorKey = null;
    notifyListeners();
    try {
      data = await _repository.approveDemo();
      loaded = true;
      _riderController.setKycApproved(isApproved);
      return null;
    } catch (_) {
      errorKey = 'kyc_submit_error';
      return errorKey;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> reset() async {
    if (isApproved) return;
    await _repository.reset();
    data = const KycData();
    loading = false;
    submitting = false;
    loaded = false;
    errorKey = null;
    _riderController.setKycApproved(false);
    notifyListeners();
  }

  void _onStatusUpdate(KycData updated) {
    _statusRevision++;
    data = updated;
    errorKey = null;
    _riderController.setKycApproved(isApproved);
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
