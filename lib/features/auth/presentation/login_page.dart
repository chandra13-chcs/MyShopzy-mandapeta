// Put this file at: lib/features/auth/presentation/login_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/data/customer_api.dart';
import '../../home/presentation/home_page.dart';

class _C {
  static const green = Color(0xFF016034);
  static const mango = Color(0xFFF8C800);
  static const ink = Color(0xFF1B1F23);
  static const muted = Color(0xFF6B7680);
  static const mist = Color(0xFFEEF3F1);
  static const error = Color(0xFFC0392B);
}

/// TODO: replace with your real "send OTP" call once the backend has one.
/// Right now the backend only has /auth/development/verify-otp (debug only).
Future<void> sendOtp(String phoneNumber) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
}

// ---------------------------------------------------------------------------
// Page 1: phone number
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_valid || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final full = '+91${_phone.text}';
    try {
      await sendOtp(full);
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpPage(phone: full)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send the code. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.green,
      body: Column(
        children: [
          Expanded(child: _Hero()),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              28,
              24,
              20 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log in or sign up',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'We will text you a 6-digit code.',
                  style: TextStyle(fontSize: 14, color: _C.muted),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: _C.mist,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _error != null ? _C.error : Colors.transparent,
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _C.ink,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 26, color: Colors.black12),
                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _continue(),
                          style: const TextStyle(
                            fontSize: 17,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: _C.ink,
                          ),
                          decoration: const InputDecoration(
                            hintText: '10-digit mobile number',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w400,
                              color: _C.muted,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 13, color: _C.error),
                  ),
                ],
                const SizedBox(height: 18),
                _PrimaryButton(
                  label: 'Get code',
                  busy: _busy,
                  onPressed: _valid ? _continue : null,
                ),
                const SizedBox(height: 14),
                const Text(
                  'By continuing you agree to our Terms of Service and Privacy Policy.',
                  style: TextStyle(fontSize: 12, color: _C.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxHeight < 230;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) ...[
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Image.asset(
                      'assets/category_tiles/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.shopping_bag_rounded,
                        color: _C.green,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                const Text(
                  'Groceries, food and\nparcels at your door',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Container(width: 44, height: 4, color: _C.mango),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: OTP
// ---------------------------------------------------------------------------
class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.phone});

  final String phone;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  static const _length = 6;
  static const _resendSeconds = 30;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _left = _resendSeconds;
  bool _busy = false;
  String? _error;

  String get _code => _controller.text;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
      }
      setState(() => _left = _left - 1);
    });
  }

  Future<void> _resend() async {
    if (_left > 0) return;
    setState(() => _error = null);
    try {
      await sendOtp(widget.phone);
      _controller.clear();
      _startTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not resend the code. Try again.');
    }
  }

  Future<void> _verify() async {
    if (_code.length != _length || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CustomerApi.instance.verifyDevelopmentOtp(
        phoneNumber: widget.phone,
        otp: _code,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage()),
        (route) => false,
      );
    } on CustomerApiException catch (e) {
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _busy = false;
        _error = e.message;
      });
      _focus.requestFocus();
    }
  }

  String get _prettyPhone {
    final d = widget.phone.replaceFirst('+91', '');
    if (d.length != 10) return widget.phone;
    return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _C.ink,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the 6-digit code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _C.ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Sent to $_prettyPhone',
                      style: const TextStyle(fontSize: 15, color: _C.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _OtpBoxes(
                controller: _controller,
                focus: _focus,
                length: _length,
                hasError: _error != null,
                enabled: !_busy,
                onChanged: () {
                  setState(() => _error = null);
                  if (_code.length == _length) _verify();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: _C.error),
                ),
              ],
              const SizedBox(height: 24),
              _PrimaryButton(
                label: 'Verify and continue',
                busy: _busy,
                onPressed: _code.length == _length ? _verify : null,
              ),
              const SizedBox(height: 18),
              Center(
                child: _left > 0
                    ? Text(
                        'Resend code in 0:${_left.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14, color: _C.muted),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text(
                          'Resend code',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.green,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One hidden TextField drives six visual boxes. This keeps keyboard
/// paste and Android/iOS one-time-code autofill working.
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controller,
    required this.focus,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final int length;
  final bool hasError;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focus.requestFocus(),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([controller, focus]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(length, (i) {
                  final filled = i < text.length;
                  final active =
                      focus.hasFocus && i == text.length.clamp(0, length - 1);
                  return Container(
                    width: 46,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _C.mist,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasError
                            ? _C.error
                            : active
                            ? _C.green
                            : Colors.transparent,
                        width: 1.6,
                      ),
                    ),
                    child: Text(
                      filled ? text[i] : '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _C.ink,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focus,
                enabled: enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                onChanged: (_) => onChanged(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared button
// ---------------------------------------------------------------------------
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _C.green.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
