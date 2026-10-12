import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import 'auth_visuals.dart';

const _configuredDevelopmentOtp = String.fromEnvironment(
  'MYSHOPZY_DEVELOPMENT_CUSTOMER_OTP',
);

enum OtpVerificationPurpose { accountRegistration, login, passwordReset }

String? developmentOtpHintForBuild({
  required bool isDebugBuild,
  required String configuredOtp,
}) {
  if (!isDebugBuild || !RegExp(r'^\d{6}$').hasMatch(configuredOtp)) {
    return null;
  }
  return configuredOtp;
}

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    required this.phoneNumber,
    this.purpose = OtpVerificationPurpose.accountRegistration,
    super.key,
  });

  final String phoneNumber;
  final OtpVerificationPurpose purpose;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  String? _message;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_handleOtpChanged);
    _otpFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _otpController
      ..removeListener(_handleOtpChanged)
      ..dispose();
    _otpFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleOtpChanged() {
    if (mounted) setState(() => _message = null);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthCornerDecoration()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bannerHeight = AuthBrandBanner.heightForViewport(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: bannerHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AuthBrandBanner(height: bannerHeight),
                          Positioned(
                            top: 4,
                            left: 8,
                            child: IconButton(
                              key: const ValueKey('otp-back'),
                              onPressed: () => Navigator.of(context).maybePop(),
                              tooltip: 'Back',
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: bannerHeight,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                        child: Column(
                          children: [
                            const Text(
                              'OTP Verification',
                              style: TextStyle(
                                color: AppTheme.darkGreen,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Development-only verification · no SMS or '
                              'WhatsApp message is sent.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _verificationReason,
                              key: const ValueKey('otp-verification-reason'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.darkGreen,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'Verification code for',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.darkGreen,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _maskedPhoneNumber(widget.phoneNumber),
                              key: const ValueKey('otp-masked-phone'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.darkGreen,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _otpBoxes(),
                            const SizedBox(height: 15),
                            const Text(
                              'Enter the 6-digit code',
                              style: TextStyle(
                                color: AppTheme.primaryGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _message!,
                                key: const ValueKey('otp-message'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFB63E32),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            _resendRow(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                key: const ValueKey('otp-verify'),
                                onPressed: _verifying ? null : _verify,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: AppTheme.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _verifying ? 'Verifying…' : 'Verify',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text(_backLabel),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryGreen,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBoxes() {
    final digits = _otpController.text;
    return Semantics(
      label: 'Six digit verification code input',
      textField: true,
      child: SizedBox(
        height: 58,
        child: Stack(
          children: [
            Row(
              children: List.generate(6, (index) {
                final active =
                    _otpFocusNode.hasFocus &&
                    (index == digits.length ||
                        (digits.length == 6 && index == 5));
                return Expanded(
                  child: Container(
                    height: 56,
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? AppTheme.primaryGreen
                            : const Color(0xFFD7DEE3),
                        width: active ? 1.7 : 1.3,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      index < digits.length ? digits[index] : '',
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: TextField(
                key: const ValueKey('otp-input'),
                controller: _otpController,
                focusNode: _otpFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resendRow() {
    final developmentOtpHint = developmentOtpHintForBuild(
      isDebugBuild: kDebugMode,
      configuredOtp: _configuredDevelopmentOtp,
    );
    final notice = switch (widget.purpose) {
      OtpVerificationPurpose.accountRegistration =>
        'No SMS or WhatsApp message was sent. Account registration is not connected.',
      OtpVerificationPurpose.login =>
        developmentOtpHint == null
            ? 'Development-only login: no SMS or WhatsApp message was sent. Enter the code configured for this backend.'
            : 'Development-only OTP hint: $developmentOtpHint. No SMS or WhatsApp message is sent.',
      OtpVerificationPurpose.passwordReset =>
        'No SMS or WhatsApp message was sent. Password recovery is not connected.',
    };
    return Text(
      notice,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppTheme.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    if (!RegExp(r'^\d{6}$').hasMatch(_otpController.text)) {
      setState(() => _message = 'Enter the complete 6-digit OTP.');
      return;
    }
    if (widget.purpose == OtpVerificationPurpose.login &&
        kDebugMode &&
        CustomerApi.instance.isConfigured) {
      _verifyDevelopmentOtp();
      return;
    }
    setState(() {
      _message = switch (widget.purpose) {
        OtpVerificationPurpose.accountRegistration => 'OTP verification is not connected. No account was created or verified.',
        OtpVerificationPurpose.login =>
          'OTP verification is not connected. You are not signed in.',
        OtpVerificationPurpose.passwordReset => 'OTP verification and password reset are not connected. No password was changed.',
      };
    });
  }

  Future<void> _verifyDevelopmentOtp() async {
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      await CustomerApi.instance.verifyDevelopmentOtp(
        phoneNumber: '+91${widget.phoneNumber}',
        otp: _otpController.text,
      );
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String get _verificationReason => switch (widget.purpose) {
    OtpVerificationPurpose.accountRegistration => 'Account registration',
    OtpVerificationPurpose.login => 'Login verification',
    OtpVerificationPurpose.passwordReset => 'Password recovery',
  };

  String get _backLabel => switch (widget.purpose) {
    OtpVerificationPurpose.accountRegistration => 'Back to registration',
    OtpVerificationPurpose.login => 'Back to Login',
    OtpVerificationPurpose.passwordReset => 'Back to recovery',
  };

  String _maskedPhoneNumber(String number) {
    final visibleDigits = number.length > 4
        ? number.substring(number.length - 4)
        : number;
    return '+91 •••••• $visibleDigits';
  }
}
