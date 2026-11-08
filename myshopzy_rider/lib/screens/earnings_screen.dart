import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';
import '../models/order.dart';
import 'history_detail_screen.dart';

/// Feature 7: earnings summary + delivery history.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _filter = 0; // 0 = today, 1 = last 7 days, 2 = all

  List<DeliveryRecord> _filtered(RiderController c) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case 0:
        return c.history.where((r) => !r.completedAt.isBefore(startOfToday)).toList();
      case 1:
        final from = startOfToday.subtract(const Duration(days: 6));
        return c.history.where((r) => !r.completedAt.isBefore(from)).toList();
      default:
        return c.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderController>();
    final shown = _filtered(c);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _tile(T.t('today_earnings'), money(c.todayEarnings))),
            const SizedBox(width: 8),
            Expanded(child: _tile(T.t('last_7_days'), money(c.weekEarnings))),
            const SizedBox(width: 8),
            Expanded(child: _tile(T.t('total'), money(c.totalEarnings))),
          ],
        ),
        const SizedBox(height: 12),
        _WeekChart(values: c.last7DaysEarnings),
        const SizedBox(height: 16),
        Text(T.t('history'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in [
              [0, 'filter_today'],
              [1, 'filter_week'],
              [2, 'filter_all'],
            ])
              ChoiceChip(
                label: Text(T.t(e[1] as String)),
                selected: _filter == e[0],
                onSelected: (_) => setState(() => _filter = e[0] as int),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(T.t('no_history'))),
          ),
        for (final r in shown)
          Card(
            child: ListTile(
              title: Text('${r.shopName} · ${r.orderId}'),
              subtitle: Text(
                  '${r.customerAddress}\n${fmtDate(r.completedAt)}, ${fmtTime(r.completedAt)}  ·  ${r.rating} ★'
                  '${r.codCollected > 0 ? '  ·  COD ${money(r.codCollected)}' : ''}'),
              isThreeLine: true,
              trailing: Text(money(r.earning),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HistoryDetailScreen(record: r)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}

const _chartBrand = Color(0xFFD9480F);

/// 7 simple bars: earnings for each of the last 7 days (right bar = today).
class _WeekChart extends StatelessWidget {
  final List<double> values;
  const _WeekChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    final now = DateTime.now();
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(values[i] > 0 ? values[i].toStringAsFixed(0) : '',
                          style: const TextStyle(fontSize: 10)),
                      const SizedBox(height: 2),
                      Container(
                        height: maxV == 0 ? 3 : 3 + 80 * (values[i] / maxV),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: i == values.length - 1
                              ? _chartBrand
                              : _chartBrand.withAlpha(120),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          labels[DateTime(now.year, now.month,
                                      now.day - (values.length - 1 - i))
                                  .weekday -
                              1],
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
