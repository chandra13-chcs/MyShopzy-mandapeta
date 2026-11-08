import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_config.dart';
import '../constants/translations.dart';
import '../services/rider_controller.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/kyc_service.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';
import 'kyc_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _creatingAccount = true;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _sending = false;
  bool _signingIn = false;
  bool _retrySend = false;
  bool _retrySignIn = false;
  String? _error;
  Timer? _lockTimer;

  String? get _passwordError => AuthService.validatePassword(
        _passwordCtrl.text,
        phone: _phoneCtrl.text.trim(),
      );

  bool get _validPhone => RegExp(r'^\d{10}$').hasMatch(_phoneCtrl.text.trim());

  bool get _canCreate =>
      _nameCtrl.text.trim().length >= 2 &&
      _validPhone &&
      _passwordError == null &&
      _confirmCtrl.text == _passwordCtrl.text;

  Future<void> _submitRegistration() async {
    if (_sending || !_canCreate) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _retrySend = false;
      _sending = true;
    });
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    try {
      await context
          .read<AuthService>()
          .requestOtp(name: name, phone: phone, password: password);
      if (!mounted) return;
      setState(() => _sending = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(name: name, phone: phone),
        ),
      );
    } catch (_) {
      ConnectivityService.instance.reportRepositoryFailure();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = T.t('err_send_otp');
        _retrySend = true;
      });
    }
  }

  Future<void> _signIn() async {
    if (_signingIn || !_validPhone || _passwordCtrl.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _retrySignIn = false;
      _signingIn = true;
    });
    try {
      final ok = await context.read<AuthService>().signIn(
            phone: _phoneCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      ConnectivityService.instance.reportRepositorySuccess();
      if (!mounted) return;
      setState(() => _signingIn = false);
      if (!ok) {
        final lockedFor = context.read<AuthService>().lockedFor;
        setState(() {
          _error = lockedFor == null
              ? T.t('err_wrong_credentials')
              : T
                  .t('err_locked_wait')
                  .replaceAll('{seconds}', _secondsRemaining(lockedFor));
        });
        if (lockedFor != null) _startLockCountdown();
        return;
      }
      await _openSignedInDestination();
    } catch (_) {
      ConnectivityService.instance.reportRepositoryFailure();
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _error = T.t('err_network');
        _retrySignIn = true;
      });
    }
  }

  Future<void> _openSignedInDestination() async {
    final kyc = context.read<KycService>();
    await kyc.load();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => kyc.isApproved ? const HomeScreen() : const KycScreen(),
      ),
      (route) => false,
    );
  }

  void _startLockCountdown() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = context.read<AuthService>().lockedFor;
      if (remaining == null) {
        timer.cancel();
        setState(() => _error = null);
      } else {
        setState(() {
          _error = T
              .t('err_locked_wait')
              .replaceAll('{seconds}', _secondsRemaining(remaining));
        });
      }
    });
  }

  String _secondsRemaining(Duration duration) =>
      '${(duration.inMilliseconds + 999) ~/ 1000}';

  void _onInputChanged() {
    setState(() {
      if (_retrySend || _retrySignIn) _error = null;
      _retrySend = false;
      _retrySignIn = false;
    });
  }

  Future<void> _showForgotPassword() async {
    final resetDone = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ForgotPasswordSheet(initialPhone: _phoneCtrl.text.trim()),
    );
    if (resetDone == true && mounted) {
      setState(() {
        _creatingAccount = false;
        _passwordCtrl.clear();
        _confirmCtrl.clear();
        _error = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(T.t('password_changed'))));
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riderController = context.watch<RiderController>();
    final password = _passwordCtrl.text;
    final strength = AuthService.passwordStrength(password);
    final strengthColor = switch (strength) {
      1 => Colors.red,
      2 => Colors.orange,
      3 => Colors.green,
      _ => Theme.of(context).colorScheme.outline,
    };

    return Scaffold(
      appBar: AppBar(title: Text(T.t('app_name'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in T.languages.entries)
                    ChoiceChip(
                      label: Text(T.t('language_${entry.key}')),
                      selected: riderController.language == entry.key,
                      onSelected: (_) => riderController.setLanguage(entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(T.t('create_account')),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(T.t('sign_in')),
                  ),
                ],
                selected: {_creatingAccount},
                onSelectionChanged: (value) => setState(() {
                  _creatingAccount = value.first;
                  _error = null;
                  _retrySend = false;
                  _retrySignIn = false;
                }),
              ),
              const SizedBox(height: 16),
              Text(
                T.t('login_title'),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (_creatingAccount) ...[
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  onChanged: (_) => _onInputChanged(),
                  decoration: InputDecoration(
                    labelText: T.t('name_label'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: _creatingAccount
                    ? TextInputAction.next
                    : TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => _onInputChanged(),
                decoration: InputDecoration(
                  labelText: T.t('phone_label'),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                textInputAction: _creatingAccount
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: [
                  _creatingAccount
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onChanged: (_) => _onInputChanged(),
                onSubmitted: _creatingAccount ? null : (_) => _signIn(),
                decoration: InputDecoration(
                  labelText:
                      T.t(_creatingAccount ? 'create_password' : 'password'),
                  border: const OutlineInputBorder(),
                  errorText: _creatingAccount &&
                          password.isNotEmpty &&
                          _passwordError != null
                      ? T.t(_passwordError!)
                      : null,
                  suffixIcon: IconButton(
                    tooltip:
                        T.t(_showPassword ? 'hide_password' : 'show_password'),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(_showPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                  ),
                ),
              ),
              if (_creatingAccount) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: strength / 3,
                        color: strengthColor,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      T.t(switch (strength) {
                        1 => 'password_weak',
                        2 => 'password_medium',
                        3 => 'password_strong',
                        _ => 'password_weak',
                      }),
                      style: TextStyle(color: strengthColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _PasswordRule(
                  label: T.t('rule_8_chars'),
                  valid: password.length >= 8,
                ),
                _PasswordRule(
                  label: T.t('rule_letter'),
                  valid: RegExp(r'[A-Za-z]').hasMatch(password),
                ),
                _PasswordRule(
                  label: T.t('rule_number'),
                  valid: RegExp(r'\d').hasMatch(password),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: !_showConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => _onInputChanged(),
                  onSubmitted: (_) => _submitRegistration(),
                  decoration: InputDecoration(
                    labelText: T.t('confirm_password'),
                    border: const OutlineInputBorder(),
                    errorText: _passwordCtrl.text.isNotEmpty &&
                            _confirmCtrl.text != _passwordCtrl.text
                        ? T.t('err_password_mismatch')
                        : null,
                    suffixIcon: IconButton(
                      tooltip: T.t(_showConfirmPassword
                          ? 'hide_password'
                          : 'show_password'),
                      onPressed: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword),
                      icon: Icon(_showConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              if (_creatingAccount)
                _BusyPrimaryButton(
                  label: T.t('send_otp'),
                  loading: _sending,
                  onPressed:
                      _canCreate && !_sending ? _submitRegistration : null,
                )
              else
                _BusyPrimaryButton(
                  label: T.t('sign_in'),
                  loading: _signingIn,
                  onPressed: _validPhone &&
                          _passwordCtrl.text.isNotEmpty &&
                          !_signingIn
                      ? _signIn
                      : null,
                ),
              if (_retrySend || _retrySignIn)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _retrySend ? _submitRegistration : _signIn,
                    child: Text(T.t('retry')),
                  ),
                ),
              if (!_creatingAccount)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _showForgotPassword,
                    child: Text(T.t('forgot_password')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  final String label;
  final bool valid;

  const _PasswordRule({required this.label, required this.valid});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              valid ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: valid
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: valid
                    ? Colors.green
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
}

class _BusyPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _BusyPrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return PrimaryButton(label: label, onPressed: onPressed);
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD9480F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialPhone;

  const _ForgotPasswordSheet({required this.initialPhone});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _phoneCtrl;
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _otpRequested = false;
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _retrySend = false;
  bool _retryReset = false;
  bool _success = false;
  String? _error;

  String? get _passwordError => AuthService.validatePassword(
        _passwordCtrl.text,
        phone: _phoneCtrl.text.trim(),
      );

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  Future<void> _sendOtp() async {
    if (_busy) return;
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() {
        _error = T.t('err_phone');
        _retrySend = false;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _retrySend = false;
    });
    try {
      await context.read<AuthService>().requestPasswordReset(phone);
      if (!mounted) return;
      setState(() {
        _otpRequested = true;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().contains('phone_not_found')
            ? T.t('err_phone_not_found')
            : T.t('err_send_otp');
        _retrySend = !error.toString().contains('phone_not_found');
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    if (_passwordError != null) {
      setState(() => _error = T.t(_passwordError!));
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = T.t('err_password_mismatch'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _retryReset = false;
    });
    try {
      final ok = await context.read<AuthService>().resetPassword(
            phone: _phoneCtrl.text.trim(),
            otp: _otpCtrl.text.trim(),
            newPassword: _passwordCtrl.text,
          );
      ConnectivityService.instance.reportRepositorySuccess();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          _success = true;
        } else {
          _error = T.t('err_otp');
        }
      });
    } catch (_) {
      ConnectivityService.instance.reportRepositoryFailure();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = T.t('err_network');
        _retryReset = true;
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final paddingBottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + paddingBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              T.t('reset_password'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_success) ...[
              Text(T.t('password_changed')),
              const SizedBox(height: 12),
              PrimaryButton(
                label: T.t('sign_in'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ] else ...[
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: T.t('phone_label'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!_otpRequested)
                _BusyPrimaryButton(
                  label: T.t('send_otp'),
                  loading: _busy,
                  onPressed: _busy ||
                          !RegExp(r'^\d{10}$').hasMatch(_phoneCtrl.text.trim())
                      ? null
                      : _sendOtp,
                ),
              if (_retrySend)
                TextButton(
                  onPressed: _sendOtp,
                  child: Text(T.t('retry')),
                ),
              if (_otpRequested) ...[
                if (AppConfig.showDemoOtp && auth.demoOtp != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('${T.t('demo_code')}: ${auth.demoOtp}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: T.t('otp_title'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: T.t('new_password'),
                    border: const OutlineInputBorder(),
                    errorText:
                        _passwordCtrl.text.isNotEmpty && _passwordError != null
                            ? T.t(_passwordError!)
                            : null,
                    suffixIcon: IconButton(
                      tooltip: T
                          .t(_showPassword ? 'hide_password' : 'show_password'),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: !_showConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _resetPassword(),
                  decoration: InputDecoration(
                    labelText: T.t('confirm_password'),
                    border: const OutlineInputBorder(),
                    errorText: _passwordCtrl.text.isNotEmpty &&
                            _confirmCtrl.text != _passwordCtrl.text
                        ? T.t('err_password_mismatch')
                        : null,
                    suffixIcon: IconButton(
                      tooltip: T.t(_showConfirmPassword
                          ? 'hide_password'
                          : 'show_password'),
                      onPressed: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword),
                      icon: Icon(_showConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _BusyPrimaryButton(
                  label: T.t('reset_password'),
                  loading: _busy,
                  onPressed: _busy ? null : _resetPassword,
                ),
                if (_retryReset)
                  TextButton(
                    onPressed: _resetPassword,
                    child: Text(T.t('retry')),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
