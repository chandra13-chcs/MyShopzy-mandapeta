/// Numbers a launch checklist must change. These are PLACEHOLDERS.
class AppConfig {
  /// Show the locally generated OTP while using the mock authentication flow.
  static const showDemoOtp = true;

  /// Demo: only the 3 photos are required; numbers and bank details are optional;
  /// admin approval is automatic. Set to false for real validation.
  static const kycDemoMode = true;

  static const foodMaxPickupKm = 2.0;
  static const foodMaxDropKm = 10.0;
  static const parcelMaxKm = 25.0;
  static const int offerSeconds = 40;
  static const int alertMaxSeconds = 40;

  /// MyShopzy support phone (digits only).
  static const supportPhone = '1800000000';

  /// MyShopzy WhatsApp number with country code, no + sign (e.g. 919876543210).
  static const supportWhatsapp = '911800000000';
}
