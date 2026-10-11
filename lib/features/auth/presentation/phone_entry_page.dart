import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'auth_visuals.dart';
import 'otp_verification_page.dart';

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bannerHeight = AuthBrandBanner.heightForViewport(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Column(
              children: [
                SizedBox(
                  height: bannerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AuthBrandBanner(height: bannerHeight),
                      Positioned(
                        top: 4,
                        left: 8,
                        child: IconButton(
                          key: const ValueKey('login-back'),
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 40,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x16002211),
                                blurRadius: 22,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Enter your mobile number',
                                  style: TextStyle(
                                    color: AuthPalette.darkGreen,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Log in or sign up with your phone number',
                                  style: TextStyle(
                                    color: AppTheme.secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AuthPhoneField(
                                  fieldKey:
                                      const ValueKey('phone-number-field'),
                                  controller: _phoneController,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: FilledButton(
                                    key: const ValueKey('phone-continue'),
                                    onPressed: _continue,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AuthPalette.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'OTP verification is not connected yet. '
                                  'No SMS will be sent.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                const AuthLegalLinks(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
          purpose: OtpVerificationPurpose.login,
        ),
      ),
    );
  }
}
