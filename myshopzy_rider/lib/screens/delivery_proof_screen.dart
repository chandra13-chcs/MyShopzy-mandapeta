import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';
import '../utils/theme_colors.dart';
import '../widgets/picked_image.dart';
import 'delivery_success_screen.dart';

/// Features 6 + 8: customer's delivery OTP, photo proof and (for
/// cash orders) confirming the cash was collected.
class DeliveryProofScreen extends StatefulWidget {
  const DeliveryProofScreen({super.key});

  @override
  State<DeliveryProofScreen> createState() => _DeliveryProofScreenState();
}

class _DeliveryProofScreenState extends State<DeliveryProofScreen>
    with TickerProviderStateMixin {
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  late final AnimationController _shakeController;
  late final Animation<double> _shake;
  String? _photoPath;
  String? _error;
  bool _cashCollected = false;
  bool _busy = false;
  bool _successRouteOpened = false;
  bool _wrongOtpError = false;
  int _wrongAttempts = 0;

  bool get _otpComplete => RegExp(r'^\d{4}$').hasMatch(_otpCtrl.text.trim());

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(_shakeController);
    _otpCtrl.addListener(_onOtpChanged);
  }

  void _onOtpChanged() {
    if (!mounted) return;
    setState(() {
      if (_wrongOtpError && _otpCtrl.text.isNotEmpty) {
        _wrongOtpError = false;
        _error = null;
      }
    });
  }

  @override
  void dispose() {
    _otpCtrl.removeListener(_onOtpChanged);
    _otpCtrl.dispose();
    _otpFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_busy) return;
    try {
      final f = await ImagePicker().pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 60,
        maxWidth: 1280,
      );
      if (f != null && mounted) setState(() => _photoPath = f.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('photo_picker_failed'))),
      );
    }
  }

  Future<void> _confirm() async {
    if (_busy || _successRouteOpened) return;
    final controller = context.read<RiderController>();
    final order = controller.active;
    if (order == null || !_otpComplete || _photoPath == null) return;

    setState(() {
      _error = null;
      _wrongOtpError = false;
      _busy = true;
    });
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    if (!controller.otpMatches(_otpCtrl.text.trim())) {
      _wrongAttempts++;
      _otpCtrl.clear();
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _error = T.t('wrong_otp_ask_again');
        _wrongOtpError = true;
        _busy = false;
      });
      return;
    }

    if (order.payment == PaymentType.cod && !_cashCollected) {
      setState(() {
        _error = T.t('cod_needed');
        _busy = false;
      });
      return;
    }

    _successRouteOpened = true;
    final photoPath = _photoPath!;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DeliverySuccessScreen(
          order: order,
          onComplete: () => controller.completeDelivery(photoPath: photoPath),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RiderController>();
    final order = controller.active;
    if (order == null) {
      return Scaffold(appBar: AppBar(title: Text(T.t('proof_title'))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(T.t('proof_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(T.t('enter_otp')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint(context, Colors.orange),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tintBorder(context, Colors.orange)),
            ),
            child: Text(
              '${T.t('demo_otp')}: ${order.deliveryOtp}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
                offset: Offset(_shake.value, 0), child: child),
            child: TextField(
              controller: _otpCtrl,
              focusNode: _otpFocus,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                counterText: '',
                errorText: _wrongOtpError ? T.t('wrong_otp_ask_again') : null,
              ),
            ),
          ),
          if (_wrongAttempts >= 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                T.t('contact_support_hint'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          if (_photoPath != null)
            PickedImage(path: _photoPath!, height: 200, fit: BoxFit.cover),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(
              kIsWeb ? Icons.photo_library_outlined : Icons.photo_camera,
            ),
            label: Text(
              kIsWeb
                  ? T.t('choose_photo')
                  : _photoPath == null
                      ? T.t('take_photo')
                      : T.t('retake_photo'),
            ),
            onPressed: _busy ? null : _takePhoto,
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                T.t('camera_not_on_web'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (order.payment == PaymentType.cod) ...[
            const SizedBox(height: 12),
            Card(
              color: tint(context, Colors.red),
              child: CheckboxListTile(
                value: _cashCollected,
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _cashCollected = value ?? false),
                title: Text(
                  '${T.t('collect_cash')}: ${money(order.codAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(T.t('cod_check')),
              ),
            ),
          ],
          if (_error != null && !_wrongOtpError) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9480F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _busy || !_otpComplete || _photoPath == null
                  ? null
                  : _confirm,
              child: _busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          T.t('verifying_otp'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : Text(
                      T.t('confirm_delivery'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
