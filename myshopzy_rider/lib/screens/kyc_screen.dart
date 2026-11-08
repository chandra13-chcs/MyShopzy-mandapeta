import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants/app_config.dart';
import '../constants/translations.dart';
import '../models/kyc.dart';
import '../services/auth_service.dart';
import '../services/kyc_service.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';
import '../utils/theme_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/picked_image.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _aadhaarFocusNode = FocusNode();
  final _panFocusNode = FocusNode();
  final _imagePicker = ImagePicker();
  String _aadhaarPhoto = '';
  String _panPhoto = '';
  String _passportPhoto = '';
  bool _pickingPhoto = false;
  bool _aadhaarTouched = false;
  bool _panTouched = false;
  bool _populatingForm = false;
  bool _navigatedHome = false;
  Timer? _approvalNavigationTimer;

  @override
  void initState() {
    super.initState();
    final service = context.read<KycService>();
    _populateForm(service.data);
    _aadhaarController.addListener(_onFormChanged);
    _panController.addListener(_onFormChanged);
    _aadhaarFocusNode.addListener(_onAadhaarFocusChanged);
    _panFocusNode.addListener(_onPanFocusChanged);
    service.addListener(_onKycChanged);
    if (service.isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleApprovalNavigation();
      });
    }
    if (!service.loaded) unawaited(_loadKyc());
  }

  void _populateForm(KycData data) {
    _populatingForm = true;
    try {
      _aadhaarController.text = data.aadhaarNumber;
      _panController.text = data.panNumber;
      _aadhaarPhoto = data.aadhaarPhotoPath;
      _panPhoto = data.panPhotoPath;
      _passportPhoto = data.passportPhotoPath;
    } finally {
      _populatingForm = false;
    }
  }

  void _onFormChanged() {
    if (mounted && !_populatingForm) setState(() {});
  }

  void _onAadhaarFocusChanged() {
    if (_aadhaarFocusNode.hasFocus || _aadhaarTouched || !mounted) return;
    setState(() => _aadhaarTouched = true);
    _formKey.currentState?.validate();
  }

  void _onPanFocusChanged() {
    if (_panFocusNode.hasFocus || _panTouched || !mounted) return;
    setState(() => _panTouched = true);
    _formKey.currentState?.validate();
  }

  void _onKycChanged() {
    if (!mounted) return;
    if (context.read<KycService>().isApproved) {
      _scheduleApprovalNavigation();
    } else {
      _approvalNavigationTimer?.cancel();
      _approvalNavigationTimer = null;
    }
  }

  void _scheduleApprovalNavigation() {
    if (!mounted || _navigatedHome || _approvalNavigationTimer != null) return;
    _approvalNavigationTimer = Timer(const Duration(milliseconds: 1500), () {
      _approvalNavigationTimer = null;
      if (!mounted || !context.read<KycService>().isApproved) return;
      _openHome();
    });
  }

  void _openHome() {
    if (!mounted || _navigatedHome) return;
    _navigatedHome = true;
    _approvalNavigationTimer?.cancel();
    _approvalNavigationTimer = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _loadKyc() async {
    final service = context.read<KycService>();
    await service.load();
    if (!mounted || !service.loaded) return;
    setState(() {
      if (_aadhaarController.text.isEmpty) _populateForm(service.data);
    });
  }

  String get _normalizedAadhaar =>
      _aadhaarController.text.trim().replaceAll(RegExp(r'\s+'), '');

  String get _normalizedPan =>
      _panController.text.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  bool _validAadhaar(String value) => RegExp(r'^[0-9]{12}$').hasMatch(value);

  bool _validPan(String value) =>
      RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(value);

  bool get _aadhaarValid => AppConfig.kycDemoMode && _normalizedAadhaar.isEmpty
      ? true
      : _validAadhaar(_normalizedAadhaar);

  bool get _panValid => AppConfig.kycDemoMode && _normalizedPan.isEmpty
      ? true
      : _validPan(_normalizedPan);

  bool get _formValid =>
      _aadhaarValid &&
      _panValid &&
      _aadhaarPhoto.isNotEmpty &&
      _panPhoto.isNotEmpty &&
      _passportPhoto.isNotEmpty;

  String? _aadhaarError(String? value) {
    final normalized = (value ?? '').trim().replaceAll(RegExp(r'\s+'), '');
    if (AppConfig.kycDemoMode && normalized.isEmpty) return null;
    return _validAadhaar(normalized) ? null : T.t('err_aadhaar_12');
  }

  String? _panError(String? value) {
    final normalized =
        (value ?? '').trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (AppConfig.kycDemoMode && normalized.isEmpty) return null;
    return _validPan(normalized) ? null : T.t('err_pan_format');
  }

  Future<void> _pickPhoto(String field) async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      setState(() {
        switch (field) {
          case 'aadhaar':
            _aadhaarPhoto = image.path;
          case 'pan':
            _panPhoto = image.path;
          case 'passport':
            _passportPhoto = image.path;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('kyc_photo_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formValid || !_formKey.currentState!.validate()) return;
    final service = context.read<KycService>();
    await service.submit(
      KycData(
        aadhaarNumber: _normalizedAadhaar,
        panNumber: _normalizedPan,
        aadhaarPhotoPath: _aadhaarPhoto,
        panPhotoPath: _panPhoto,
        passportPhotoPath: _passportPhoto,
      ),
    );
  }

  Future<void> _skipVerificationDemo() async {
    if (!AppConfig.kycDemoMode || !mounted) return;
    await context.read<KycService>().approveDemo();
  }

  Future<void> _signOut() async {
    final sure = await confirmDialog(context, T.t('confirm_logout'));
    if (!sure || !mounted) return;
    final kyc = context.read<KycService>();
    final controller = context.read<RiderController>();
    final auth = context.read<AuthService>();
    await controller.reset();
    await kyc.reset();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _approvalNavigationTimer?.cancel();
    context.read<KycService>().removeListener(_onKycChanged);
    _aadhaarController.removeListener(_onFormChanged);
    _panController.removeListener(_onFormChanged);
    _aadhaarFocusNode
      ..removeListener(_onAadhaarFocusChanged)
      ..dispose();
    _panFocusNode
      ..removeListener(_onPanFocusChanged)
      ..dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(T.t('kyc_title')),
        actions: [
          IconButton(
            tooltip: T.t('logout'),
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: kyc.loading
          ? const Center(child: CircularProgressIndicator())
          : _buildStatus(context, kyc),
    );
  }

  Widget _buildStatus(BuildContext context, KycService kyc) {
    if (kyc.data.status == KycStatus.approved) {
      return _approvedView(context);
    }
    if (kyc.data.status == KycStatus.pending) {
      return _pendingView(context, kyc);
    }
    return _formView(context, kyc);
  }

  Widget _approvedView(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: tint(context, Colors.green),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    T.t('kyc_approved_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    T.t('kyc_approved_opening_home'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: T.t('kyc_start_working'),
            onPressed: _openHome,
          ),
        ],
      );

  Widget _pendingView(BuildContext context, KycService kyc) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (kyc.errorKey != null) ...[
            Card(
              color: tint(context, Colors.red),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(T.t(kyc.errorKey!)),
                    ),
                    IconButton(
                      tooltip: T.t('kyc_refresh'),
                      onPressed: _loadKyc,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            color: tint(context, Colors.orange),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    T.t('kyc_pending_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  if (AppConfig.kycDemoMode)
                    Text(
                      T.t('demo_admin_wait'),
                      textAlign: TextAlign.center,
                    ),
                  if (AppConfig.kycDemoMode) const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadKyc,
                    icon: const Icon(Icons.refresh),
                    label: Text(T.t('kyc_refresh')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _formView(BuildContext context, KycService kyc) {
    final data = kyc.data;
    final rejectReason = data.rejectReason;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (kyc.errorKey != null && kyc.errorKey != 'kyc_submit_error') ...[
          Card(
            color: tint(context, Colors.red),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(T.t(kyc.errorKey!)),
                  TextButton.icon(
                    onPressed:
                        kyc.errorKey == 'kyc_load_error' ? _loadKyc : _submit,
                    icon: Icon(kyc.errorKey == 'kyc_load_error'
                        ? Icons.refresh
                        : Icons.replay),
                    label: Text(T.t(kyc.errorKey == 'kyc_load_error'
                        ? 'kyc_refresh'
                        : 'kyc_retry')),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (data.status == KycStatus.rejected) ...[
          Card(
            color: tint(context, Colors.red),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    T.t('kyc_rejected_message'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (rejectReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(rejectReason.startsWith('kyc_')
                          ? T.t(rejectReason)
                          : rejectReason),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _aadhaarController,
                focusNode: _aadhaarFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                maxLength: 12,
                validator: (value) =>
                    _aadhaarTouched ? _aadhaarError(value) : null,
                decoration: InputDecoration(
                  labelText: T.t('kyc_aadhaar_number'),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _panController,
                focusNode: _panFocusNode,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  UpperCaseTextInputFormatter(),
                  LengthLimitingTextInputFormatter(10),
                ],
                maxLength: 10,
                validator: (value) => _panTouched ? _panError(value) : null,
                decoration: InputDecoration(
                  labelText: T.t('kyc_pan_number'),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PhotoPicker(
          title: T.t('kyc_aadhaar_photo'),
          path: _aadhaarPhoto,
          onPick: () => _pickPhoto('aadhaar'),
        ),
        _PhotoPicker(
          title: T.t('kyc_pan_photo'),
          path: _panPhoto,
          onPick: () => _pickPhoto('pan'),
        ),
        _PhotoPicker(
          title: T.t('kyc_passport_photo'),
          path: _passportPhoto,
          onPick: () => _pickPhoto('passport'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(T.t('kyc_photos_required')),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  T.t('kyc_checklist'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _ChecklistItem(
                  label: T.t('kyc_aadhaar_number'),
                  optional: AppConfig.kycDemoMode,
                  valid: _aadhaarValid,
                  reason: _aadhaarValid ? null : T.t('err_aadhaar_12'),
                ),
                _ChecklistItem(
                  label: T.t('kyc_aadhaar_photo'),
                  valid: _aadhaarPhoto.isNotEmpty,
                  reason: _aadhaarPhoto.isNotEmpty
                      ? null
                      : T.t('err_photo_missing'),
                ),
                _ChecklistItem(
                  label: T.t('kyc_pan_number'),
                  optional: AppConfig.kycDemoMode,
                  valid: _panValid,
                  reason: _panValid ? null : T.t('err_pan_format'),
                ),
                _ChecklistItem(
                  label: T.t('kyc_pan_photo'),
                  valid: _panPhoto.isNotEmpty,
                  reason:
                      _panPhoto.isNotEmpty ? null : T.t('err_photo_missing'),
                ),
                _ChecklistItem(
                  label: T.t('kyc_passport_photo'),
                  valid: _passportPhoto.isNotEmpty,
                  reason: _passportPhoto.isNotEmpty
                      ? null
                      : T.t('err_photo_missing'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9480F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _formValid &&
                    !kyc.submitting &&
                    !_pickingPhoto &&
                    kyc.errorKey != 'kyc_load_error'
                ? _submit
                : null,
            child: kyc.submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    T.t('kyc_submit'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        if (kyc.errorKey == 'kyc_submit_error') ...[
          const SizedBox(height: 8),
          Text(
            T.t(kyc.errorKey!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: _formValid && !kyc.submitting ? _submit : null,
            child: Text(T.t('kyc_retry')),
          ),
        ],
        if (_pickingPhoto) ...[
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
        if (AppConfig.kycDemoMode)
          Center(
            child: TextButton(
              onPressed: kyc.submitting || _pickingPhoto
                  ? null
                  : _skipVerificationDemo,
              child: Text(T.t('skip_verification_demo')),
            ),
          ),
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.label,
    required this.valid,
    required this.reason,
    this.optional = false,
  });

  final String label;
  final bool valid;
  final String? reason;
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              valid ? Icons.check_circle : Icons.circle_outlined,
              color:
                  valid ? Colors.green : Theme.of(context).colorScheme.outline,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label ${optional ? T.t('optional') : '(${T.t('required_field')})'}',
                  ),
                  if (!valid && reason != null)
                    Text(
                      reason!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class UpperCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.title,
    required this.path,
    required this.onPick,
  });

  final String title;
  final String path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: path.isEmpty
                    ? const Icon(Icons.add_a_photo_outlined, size: 32)
                    : PickedImage(
                        path: path,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: onPick,
                child: Text(T.t(path.isEmpty ? 'kyc_add_photo' : 'kyc_retake')),
              ),
            ],
          ),
        ),
      );
}
