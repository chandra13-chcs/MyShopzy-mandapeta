import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'auth_visuals.dart';
import 'otp_verification_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const ValueKey('forgot-back'),
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                        ),
                        MyShopzyBrand(
                          compact: MediaQuery.sizeOf(context).width < 360,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Reset your password',
                          style: TextStyle(
                            color: AppTheme.darkGreen,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter the mobile number registered to your account. '
                          'We will continue to a UI-only OTP screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        AuthPhoneField(
                          fieldKey: const ValueKey('forgot-phone-field'),
                          controller: _phoneController,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            key: const ValueKey('forgot-continue'),
                            onPressed: _continue,
                            child: const Text('Continue'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'UI demo only · no SMS will be sent',
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OtpVerificationPage(
          phoneNumber: _phoneController.text,
          purpose: OtpVerificationPurpose.passwordReset,
        ),
      ),
    );
  }
}
