import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';
import '../widgets/primary_button.dart';
import '../utils/theme_colors.dart';

/// Feature 8: cash-on-delivery in hand, deposit, and withdraw earnings.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountCtrl = TextEditingController();
  final _payoutIdCtrl = TextEditingController();
  String? _error;
  bool _prefilled = false;
  bool _busy = false; // a server call is running

  @override
  void dispose() {
    _amountCtrl.dispose();
    _payoutIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final c = context.read<RiderController>();
    final payoutId = _payoutIdCtrl.text.trim();
    if (payoutId.isEmpty) {
      setState(() => _error = T.t('err_payout_id'));
      return;
    }
    await c.setPayoutId(payoutId);
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await c.withdraw(amount);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err == null ? null : T.t(err);
    });
    if (err == null) {
      _amountCtrl.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(T.t('withdraw_ok'))));
    }
  }

  Future<void> _deposit() async {
    final c = context.read<RiderController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await c.depositCash();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(T.t(err ?? 'deposit_ok'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderController>();
    if (!_prefilled && (c.payoutId ?? '').isNotEmpty) {
      _payoutIdCtrl.text = c.payoutId!;
      _prefilled = true;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) const LinearProgressIndicator(),
        Card(
          color: tint(context, Colors.red),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(T.t('cash_in_hand'), style: const TextStyle(color: Colors.grey)),
                Text(money(c.cashInHand),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(T.t('cash_hint'), style: const TextStyle(fontSize: 12)),
                if (c.cashLimitReached)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(T.t('cash_limit_warn'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                  ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: T.t('deposit_cash'),
                  onPressed: c.cashInHand > 0 && !_busy ? _deposit : null,
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(T.t('balance'), style: const TextStyle(color: Colors.grey)),
                Text(money(c.balance),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                const SizedBox(height: 12),
                TextField(
                  controller: _payoutIdCtrl,
                  decoration: InputDecoration(
                      labelText: T.t('payout_id_label'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: T.t('amount'),
                      helperText: T.t('min_withdraw'),
                      border: const OutlineInputBorder()),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
                PrimaryButton(label: T.t('withdraw'), onPressed: _busy ? null : _withdraw),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(T.t('payout_history'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (c.payouts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(T.t('no_payouts'))),
          ),
        for (final p in c.payouts)
          ListTile(
            leading: Icon(p.kind == PayoutRecord.withdraw
                ? Icons.arrow_upward
                : Icons.arrow_downward),
            title: Text(p.kind == PayoutRecord.withdraw
                ? T.t('withdrawal')
                : T.t('cod_deposit')),
            subtitle: Text('${fmtDate(p.date)}, ${fmtTime(p.date)}'),
            trailing: Text(money(p.amount),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
