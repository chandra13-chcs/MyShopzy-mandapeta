import '../models/kyc.dart';

abstract class KycRepository {
  Future<KycData> fetchKyc();

  Future<void> submitKyc(KycData data);

  Future<KycData> approveDemo();

  Stream<KycData> get statusUpdates;

  /// Clears client-side session data without deleting server-side documents.
  Future<void> reset();

  void dispose();
}
