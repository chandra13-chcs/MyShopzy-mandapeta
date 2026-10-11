import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'auth_validators.dart';
import 'auth_visuals.dart';
import 'otp_verification_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                      title: 'Create your account',
                      backKey: ValueKey('registration-back'),
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
                              'Create your MyShopzy account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AuthPalette.darkGreen,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              key: const ValueKey('registration-name-field'),
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              validator: AuthValidators.requiredName,
                              decoration: _fieldDecoration('Full name'),
                            ),
                            const SizedBox(height: 12),
                            AuthPhoneField(
                              fieldKey:
                                  const ValueKey('registration-phone-field'),
                              controller: _phoneController,
                            ),
                            const SizedBox(height: 12),
                            AuthPasswordField(
                              controller: _passwordController,
                              label: 'Password',
                              fieldKey:
                                  const ValueKey('registration-password'),
                              toggleKey: const ValueKey(
                                'registration-password-toggle',
                              ),
                              validator: AuthValidators.password,
                            ),
                            const SizedBox(height: 12),
                            AuthPasswordField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              fieldKey: const ValueKey(
                                'registration-confirm-password',
                              ),
                              toggleKey: const ValueKey(
                                'registration-confirm-password-toggle',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Confirm your password.';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                key: const ValueKey('registration-submit'),
                                onPressed: _createAccount,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AuthPalette.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              key: const ValueKey('registration-login-link'),
                              onPressed: () => Navigator.of(
                                context,
                              ).popAndPushNamed('/login'),
                              child: const Text(
                                'Already have an account? Login',
                              ),
                            ),
                            const Text(
                              'OTP verification is required. Account creation '
                              'is not connected yet.',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppTheme.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD6DEDD)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD6DEDD), width: 1.3),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AuthPalette.green, width: 1.6),
    ),
  );

  void _createAccount() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final phoneNumber = _phoneController.text;
    _passwordController.clear();
    _confirmPasswordController.clear();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OtpVerificationPage(
          phoneNumber: phoneNumber,
          purpose: OtpVerificationPurpose.accountRegistration,
        ),
      ),
    );
  }
}
