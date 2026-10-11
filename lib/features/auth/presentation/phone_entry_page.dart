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
  final _passwordController = TextEditingController();
  bool _rememberLogin = true;
  String? _phoneError;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  AuthEntrance(
                    scale: true,
                    child: const AuthFormHeader(
                      title: 'Log in or sign up',
                      backKey: ValueKey('login-back'),
                    ),
                  ),
                  AuthEntrance(
                    slideUp: true,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
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
                              'Welcome back',
                              style: TextStyle(
                                color: AuthPalette.darkGreen,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Sign in to continue shopping',
                              style: TextStyle(
                                color: AppTheme.secondaryText,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            AuthPhoneField(
                              fieldKey: const ValueKey('phone-number-field'),
                              controller: _phoneController,
                              validator: (_) => null,
                              errorText: _phoneError,
                              onChanged: (_) {
                                if (_phoneError != null) {
                                  setState(() => _phoneError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 13),
                            AuthPasswordField(
                              controller: _passwordController,
                              label: 'Password',
                              fieldKey: const ValueKey('login-password-field'),
                              toggleKey:
                                  const ValueKey('login-password-toggle'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 4),
                            LayoutBuilder(
                              builder: (context, rowConstraints) {
                                final checkbox = Row(
                                  children: [
                                    Checkbox(
                                      key: const ValueKey(
                                        'remember-login-checkbox',
                                      ),
                                      value: _rememberLogin,
                                      activeColor: AuthPalette.green,
                                      onChanged: (value) => setState(
                                        () => _rememberLogin = value ?? false,
                                      ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Remember my login for faster sign-in',
                                        style: TextStyle(
                                          color: AuthPalette.darkGreen,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                                final forgotPassword = TextButton(
                                  key: const ValueKey('forgot-password-link'),
                                  onPressed: () => Navigator.of(
                                    context,
                                  ).pushNamed('/forgot-password'),
                                  child: const Text('Forgot Password?'),
                                );

                                if (rowConstraints.maxWidth < 370) {
                                  return Column(
                                    children: [
                                      checkbox,
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: forgotPassword,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: checkbox),
                                    forgotPassword,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                key: const ValueKey('login-submit'),
                                onPressed: _login,
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
                            const SizedBox(height: 4),
                            TextButton(
                              key: const ValueKey('login-with-otp'),
                              onPressed: _loginWithOtp,
                              child: const Text('Or log in with OTP'),
                            ),
                            const Center(
                              child: Text(
                                'UI demo only · sign-in is not connected',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            const AuthLegalLinks(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _login() {
    FocusScope.of(context).unfocus();
    final phoneError = AuthPhoneField.validateIndianMobile(
      _phoneController.text,
    );
    setState(() => _phoneError = phoneError);
    if (phoneError != null) return;
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign-in is not connected yet. No account was authenticated.',
        ),
      ),
    );
  }

  void _loginWithOtp() {
    FocusScope.of(context).unfocus();
    final error = AuthPhoneField.validateIndianMobile(_phoneController.text);
    if (error != null) {
      setState(() => _phoneError = error);
      return;
    }
    _passwordController.clear();
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
