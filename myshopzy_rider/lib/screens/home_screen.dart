import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../constants/app_config.dart';
import '../constants/translations.dart';
import '../services/rider_controller.dart';
import '../services/auth_service.dart';
import '../services/kyc_service.dart';
import '../utils/format.dart';
import 'active_delivery_screen.dart';
import 'earnings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';
import 'kyc_screen.dart';
import '../utils/theme_colors.dart';

const _brand = Color(0xFFD9480F);

/// Feature 2: main screen with bottom tabs. The incoming-order popup
/// (Feature 3) lives in `widgets/incoming_order_overlay.dart` and floats
/// above every screen, not just this one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _HomeTab(),
      const EarningsScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyShopzy Rider'),
        actions: [
          Consumer<RiderController>(
            builder: (context, c, _) => IconButton(
              icon: Badge(
                isLabelVisible: c.unreadCount > 0,
                label: Text('${c.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined), label: T.t('nav_home')),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart), label: T.t('nav_earnings')),
          NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: T.t('nav_wallet')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              label: T.t('nav_profile')),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderController>();
    final rider = context.watch<AuthService>().rider;
    final kyc = context.watch<KycService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${T.t('hi')}, ${rider?.name ?? ''}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (!kyc.isApproved) ...[
          const SizedBox(height: 12),
          Card(
            color: tint(context, Colors.orange),
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(T.t('kyc_complete_card')),
              subtitle: Text(T.t('kyc_online_blocked')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const KycScreen())),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          color: c.online
              ? tint(context, Colors.green)
              : tint(context, Colors.grey),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(c.online ? T.t('online') : T.t('offline'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(!kyc.isApproved
                    ? T.t('kyc_online_blocked')
                    : c.online && c.queueLength > 0
                        ? '${T.t('online_hint')} ${T.t('orders_waiting')} ${c.queueLength}'
                        : (c.online
                            ? T.t('online_hint')
                            : T.t('offline_hint'))),
                value: c.online,
                onChanged: kyc.isApproved
                    ? (v) async {
                        if (v && c.cashLimitReached) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(T.t('cash_limit_block'))));
                          return;
                        }
                        if (v) {
                          await c.prepareNewOrderAlerts(context);
                          if (!context.mounted) return;
                        }
                        if (!v && c.active == null) {
                          final sure = await confirmDialog(
                              context, T.t('confirm_offline'));
                          if (!sure || !context.mounted) return;
                        }
                        final ok = c.setOnline(v);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(T.t('finish_first'))));
                        }
                      }
                    : null,
              ),
              if (kIsWeb && c.online)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(T.t('keep_tab_open_sound')),
                  ),
                ),
            ],
          ),
        ),
        if (c.online)
          Card(
            color: tint(context, Colors.blue),
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(T.t('dnd_hint')),
            ),
          ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: Text(T.t('alert_volume_hint')),
              ),
              TextButton.icon(
                onPressed: c.alertRinging ? null : c.testNewOrderAlert,
                icon: const Icon(Icons.play_arrow),
                label: Text(T.t('test_alert')),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: tint(context, Colors.blue),
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(T
                .t('distance_rules_info')
                .replaceAll(
                    '{foodPickup}', AppConfig.foodMaxPickupKm.toString())
                .replaceAll('{foodDrop}', AppConfig.foodMaxDropKm.toString())
                .replaceAll('{parcel}', AppConfig.parcelMaxKm.toString())),
          ),
        ),
        if (c.cashLimitReached) ...[
          const SizedBox(height: 12),
          Card(
            color: tint(context, Colors.red),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  '${T.t('cash_limit_warn')} (${money(c.cashInHand)} / ${money(RiderController.codCashLimit)})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        if (c.active != null) ...[
          const SizedBox(height: 12),
          Card(
            color: tint(context, Colors.orange),
            child: ListTile(
              leading: const Icon(Icons.delivery_dining, color: _brand),
              title: Text(T.t('resume_delivery'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  Text('${c.active!.shopName} → ${c.active!.customerName}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ActiveDeliveryScreen())),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _Stat(
                    label: T.t('today_deliveries'),
                    value: '${c.todayDeliveries.length}')),
            const SizedBox(width: 12),
            Expanded(
                child: _Stat(
                    label: T.t('today_earnings'),
                    value: money(c.todayEarnings))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _Stat(
                    label: T.t('rating'),
                    value: c.history.isEmpty
                        ? '-'
                        : '${c.averageRating.toStringAsFixed(1)} ★')),
            const SizedBox(width: 12),
            Expanded(
                child: _Stat(
                    label: T.t('acceptance'),
                    value: c.acceptanceRate == null
                        ? '-'
                        : '${c.acceptanceRate}%')),
          ],
        ),
        const SizedBox(height: 12),
        _Stat(
            label: T.t('online_time'),
            value: fmtHoursMinutes(c.onlineSecondsToday)),
        const SizedBox(height: 12),
        _TargetCard(done: c.todayDeliveries.length),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Daily target: finish N deliveries today for a bonus (display only).
class _TargetCard extends StatelessWidget {
  final int done;
  const _TargetCard({required this.done});

  @override
  Widget build(BuildContext context) {
    const target = RiderController.dailyTarget;
    final reached = done >= target;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${T.t('daily_target')}: $done / $target',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (done / target).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: reached ? Colors.green : _brand,
            ),
            const SizedBox(height: 6),
            Text(
              reached
                  ? T.t('bonus_reached')
                  : '${T.t('bonus_hint')} ${money(RiderController.dailyBonus)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
