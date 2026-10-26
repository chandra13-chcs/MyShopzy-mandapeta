import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/data/money_formatter.dart';
import '../../../shared/presentation/offline_error_state.dart';

class DuesPage extends StatefulWidget {
  const DuesPage({super.key});

  static const supportContactText =
      'For payment assistance, contact MyShopzy support through Help & Support. Payment gateway options will be available later.';

  @override
  State<DuesPage> createState() => _DuesPageState();
}

class _DuesPageState extends State<DuesPage> {
  ApiDues? _dues;
  String? _error;
  bool _loading = true;
  bool _offline = false;
  bool _submittingDispute = false;

  @override
  void initState() {
    super.initState();
    if (CustomerApi.instance.hasCustomerSession) {
      _loadDues();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadDues() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });
    try {
      final dues = await CustomerApi.instance.getDues();
      if (mounted) setState(() => _dues = dues);
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _offline = isOfflineApiError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disputeDue(ApiDueEntry entry) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispute this due'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell us why you are disputing this due',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || !mounted) return;
    setState(() => _submittingDispute = true);
    try {
      await CustomerApi.instance.disputeDue(entry.entryId, message);
      await _loadDues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your dispute was submitted.')),
        );
      }
    } on CustomerApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submittingDispute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dues = _dues;
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'My Dues',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: !CustomerApi.instance.hasCustomerSession
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sign in to access your dues.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondaryText),
                ),
              ),
            )
          : _loading && dues == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && dues == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _offline
                    ? OfflineErrorState(onRetry: _loadDues)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _loadDues,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDues,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _buildBalanceCard(dues!),
                  const SizedBox(height: 16),
                  const Text(
                    'DUE HISTORY',
                    style: TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (dues.entries.isEmpty)
                    _buildEmptyState()
                  else
                    for (final entry in dues.entries) ...[
                      _buildDueCard(entry),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 8),
                  _buildPaymentHelp(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _offline
                        ? OfflineErrorState(onRetry: _loadDues, compact: true)
                        : Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFA85B5B)),
                          ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(ApiDues dues) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EAE8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppTheme.primaryGreen,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Outstanding balance',
                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  formatMinorCurrency(dues.outstandingMinor),
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueCard(ApiDueEntry entry) {
    final canDispute =
        entry.status == 'pending_review' || entry.status == 'confirmed';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Order #${entry.orderId ?? '—'}',
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatMinorCurrency(entry.amountMinor),
                style: const TextStyle(
                  color: AppTheme.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            entry.reason.replaceAll('_', ' '),
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            _statusLabel(entry.status),
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canDispute) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submittingDispute ? null : () => _disputeDue(entry),
                child: const Text('Dispute'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7EAE8)),
      ),
      child: const Text(
        'You have no dues.',
        style: TextStyle(color: AppTheme.secondaryText),
      ),
    );
  }

  Widget _buildPaymentHelp() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7EAE8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to pay',
            style: TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 7),
          Text(
            DuesPage.supportContactText,
            style: TextStyle(
              color: AppTheme.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'pending_review' => 'Pending review',
    'confirmed' => 'Confirmed',
    'paid' => 'Paid',
    'waived' => 'Waived',
    _ => status.replaceAll('_', ' '),
  };
}
