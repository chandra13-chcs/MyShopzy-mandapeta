import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';

/// Edit the rider's name and vehicle (type + number plate).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _types = ['bike', 'scooter', 'cycle'];
  late final TextEditingController _name;
  late final TextEditingController _vehicleNo;
  late String _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = context.read<AuthService>().rider;
    _name = TextEditingController(text: r?.name ?? '');
    _vehicleNo = TextEditingController(text: r?.vehicleNumber ?? '');
    _type = r?.vehicleType ?? 'bike';
  }

  @override
  void dispose() {
    _name.dispose();
    _vehicleNo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final no = _vehicleNo.text.trim().toUpperCase().replaceAll(' ', '');
    if (name.length < 2) {
      setState(() => _error = T.t('err_name'));
      return;
    }
    // Indian number plate, e.g. TS09AB1234. A cycle needs no plate.
    if (_type != 'cycle' && !RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{0,3}\d{4}$').hasMatch(no)) {
      setState(() => _error = T.t('err_vehicle'));
      return;
    }
    final auth = context.read<AuthService>();
    final nav = Navigator.of(context);
    await auth.updateProfile(
      name: name,
      vehicleType: _type,
      vehicleNumber: _type == 'cycle' ? '' : no,
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(T.t('edit_profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
                labelText: T.t('name_label'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text(T.t('vehicle_type'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in _types)
                ChoiceChip(
                  label: Text(T.t('vehicle_$t')),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          if (_type != 'cycle') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _vehicleNo,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                  labelText: T.t('vehicle_number'),
                  border: const OutlineInputBorder()),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          PrimaryButton(label: T.t('save'), onPressed: _save),
        ],
      ),
    );
  }
}
