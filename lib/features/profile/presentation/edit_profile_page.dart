import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.profile});

  final ApiCustomerProfile? profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
  static const _border = Color(0xFFE7EAE8);

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailController = TextEditingController();
  String? _loadError;
  String? _saveError;
  String? _formError;
  bool _loading = false;
  bool _saving = false;

  bool get _backendMode =>
      CustomerApi.instance.isConfigured &&
      CustomerApi.instance.hasCustomerSession;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _applyProfile(widget.profile!);
    } else if (_backendMode) {
      _loading = true;
      unawaited(_loadProfile());
    }
  }

  void _applyProfile(ApiCustomerProfile profile) {
    _fullNameController.text = profile.displayName;
    _mobileNumberController.text = profile.phone ?? '';
    _emailController.text = profile.email ?? '';
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await CustomerApi.instance.getProfile();
      if (mounted) setState(() => _applyProfile(profile));
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: !CustomerApi.instance.canAccessCustomerFeatures
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Sign in to edit your profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondaryText),
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildLoadError()
          : _buildForm(),
      bottomNavigationBar:
          !CustomerApi.instance.canAccessCustomerFeatures ||
              _loading ||
              _loadError != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('save-profile-button'),
                    onPressed: _saving ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : _loadProfile,
              child: const Text('Retry profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SafeArea(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: [
              const Text(
                'Your account profile',
                key: const ValueKey('profile-data-source'),
                style: const TextStyle(color: _secondaryText, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: _lightGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: _green, width: 1.5),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _green,
                  size: 54,
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: null,
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  disabledForegroundColor: _green,
                ),
                child: const Text(
                  'Change Photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 22),
              _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                key: const ValueKey('profile-name-field'),
                maxLength: 100,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your full name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _mobileNumberController,
                label: 'Mobile Number',
                key: const ValueKey('profile-phone-field'),
                keyboardType: TextInputType.phone,
                maxLength: 32,
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email (Optional)',
                key: const ValueKey('profile-email-field'),
                keyboardType: TextInputType.emailAddress,
                maxLength: 254,
                validator: _validateEmail,
              ),
              if (_formError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _formError!,
                  key: const ValueKey('profile-form-error'),
                  style: const TextStyle(color: Color(0xFFA85B5B)),
                ),
              ],
              if (_saveError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _saveError!,
                  key: const ValueKey('profile-save-error'),
                  style: const TextStyle(color: Color(0xFFA85B5B)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty && _emailController.text.trim().isEmpty) {
      return 'Keep a phone number or email address.';
    }
    if (_backendMode &&
        phone.isNotEmpty &&
        !RegExp(r'^\+?[0-9 ()-]{5,32}$').hasMatch(phone)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty && _mobileNumberController.text.trim().isEmpty) {
      return 'Keep a phone number or email address.';
    }
    if (email.isNotEmpty &&
        (email.length > 254 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    setState(() {
      _formError = null;
      _saveError = null;
    });
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      if (_mobileNumberController.text.trim().isEmpty &&
          _emailController.text.trim().isEmpty) {
        setState(() => _formError = 'Keep a phone number or email address.');
      }
      return;
    }
    final name = _fullNameController.text.trim();
    final phone = _mobileNumberController.text.trim();
    final email = _emailController.text.trim();
    setState(() => _saving = true);
    try {
      final updated = await CustomerApi.instance.updateProfile(
        displayName: name,
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
        clearPhone: phone.isEmpty,
        clearEmail: email.isEmpty,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required Key key,
    required String? Function(String?) validator,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(color: _mainText, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _secondaryText),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
      ),
    );
  }
}
