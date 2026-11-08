import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_config.dart';
import '../constants/translations.dart';
import '../services/auth_service.dart';
import '../services/kyc_service.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';
import 'kyc_screen.dart';
import '../utils/theme_colors.dart';

/// Step 2 of login: rider types the 4-digit code received on their phone.
class OtpScreen extends StatefulWidget {
  final String name;
  final String phone;

  const OtpScreen({super.key, required this.name, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeCtrl = TextEditingController();
  String? _error;
  bool _verifying = false;
  bool _resending = false;
  int _resendSeconds = 30;
  DateTime? _resendDeadline;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    _resendDeadline = DateTime.now().add(const Duration(seconds: 30));
    _resendSeconds = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _resendDeadline!.difference(DateTime.now()).inSeconds;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds = remaining > 0 ? remaining : 0);
      if (remaining <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_verifying || _resending) return;
    setState(() {
      _error = null;
      _verifying = true;
    });

    bool ok;
    try {
      ok = await context.read<AuthService>().verifyOtp(_codeCtrl.text.trim());
    } catch (_) {
      if (mounted) setState(() => _error = T.t('err_verify_otp'));
      return;
    } finally {
      if (mounted) setState(() => _verifying = false);
    }

    if (!mounted) return;
    if (!ok) {
      setState(() => _error = T.t('err_otp'));
      return;
    }
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

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _resending || _verifying) return;
    setState(() {
      _error = null;
      _resending = true;
    });
    try {
      await context
          .read<AuthService>()
          .requestOtp(name: widget.name, phone: widget.phone);
      if (!mounted) return;
      _codeCtrl.clear();
      _startResendCountdown();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = T.t('err_send_otp'));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demoOtp = context.read<AuthService>().demoOtp;
    return Scaffold(
      appBar: AppBar(title: Text(T.t('otp_title'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tint(context, Colors.orange),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tintBorder(context, Colors.orange)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t('otp_hint'), style: const TextStyle(fontSize: 13)),
                  if (AppConfig.showDemoOtp && demoOtp != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${T.t('demo_code')}: $demoOtp',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), counterText: ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: T.t('verify'),
              onPressed: _verifying || _resending ? null : _verify,
            ),
            if (_verifying || _resending) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resendSeconds == 0 && !_resending && !_verifying
                  ? _resend
                  : null,
              child: Text(_resendSeconds == 0
                  ? T.t('resend_otp')
                  : T
                      .t('resend_countdown')
                      .replaceAll('{seconds}', '$_resendSeconds')),
            ),
          ],
        ),
      ),
    );
  }
}
