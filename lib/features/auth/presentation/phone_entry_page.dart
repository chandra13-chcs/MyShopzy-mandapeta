import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../../privacy_policy/presentation/privacy_policy_page.dart';
import '../../terms_conditions/presentation/terms_conditions_page.dart';
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
  bool _rememberLogin = true;

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
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          const SizedBox(height: 120),
                          const SizedBox(height: 28),
                          const _ServiceCategories(),
                          const SizedBox(height: 35),
                          const Text(
                            'Log in or sign up',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.darkGreen,
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _phoneNumberField(),
                          const SizedBox(height: 13),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(
                                () => _rememberLogin = !_rememberLogin,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberLogin,
                                      activeColor: AppTheme.primaryGreen,
                                      onChanged: (value) => setState(
                                        () => _rememberLogin = value ?? false,
                                      ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Remember my login for faster sign-in',
                                        style: TextStyle(
                                          color: AppTheme.darkGreen,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              key: const ValueKey('phone-entry-continue'),
                              onPressed: _continue,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: AppTheme.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'UI demo only · no SMS will be sent',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 17),
                          const Text(
                            'By continuing, you agree to our',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              _LegalLink(
                                label: 'Terms of Service',
                                page: const TermsConditionsPage(),
                              ),
                              const Text(
                                'and',
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                              _LegalLink(
                                label: 'Privacy Policy',
                                page: const PrivacyPolicyPage(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneNumberField() {
    return TextFormField(
      key: const ValueKey('phone-number-field'),
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: (value) {
        final number = value ?? '';
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(number)) {
          return 'Enter a valid 10-digit Indian mobile number.';
        }
        return null;
      },
      onFieldSubmitted: (_) => _continue(),
      decoration: InputDecoration(
        hintText: 'Enter Phone Number',
        hintStyle: const TextStyle(color: Color(0xFF90989A)),
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇮🇳', style: TextStyle(fontSize: 22)),
              SizedBox(width: 9),
              Text(
                '+91',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 10),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.darkGreen,
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 126),
        filled: true,
        fillColor: AppTheme.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD6DEDD), width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFB63E32)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFB63E32), width: 1.6),
        ),
      ),
    );
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            OtpVerificationPage(phoneNumber: _phoneController.text),
      ),
    );
  }
}

class _ServiceCategories extends StatelessWidget {
  const _ServiceCategories();

  static const _services = [
    ('Parcels', 'assets/category_tiles/parcel.jpg'),
    ('Restaurants', 'assets/category_tiles/restaurants.jpg'),
    ('Groceries', 'assets/category_tiles/fruits_vegetables.jpg'),
    ('Meat', 'assets/category_tiles/meat_only_chicken.jpg'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _services.length; index++) ...[
          if (index > 0)
            Container(
              width: 1,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              color: const Color(0xFFB7D9C2),
            ),
          Expanded(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    _services[index].$2,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    semanticLabel: _services[index].$1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _services[index].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.page});

  final String label;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (context) => page)),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryGreen,
          fontSize: 12,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
