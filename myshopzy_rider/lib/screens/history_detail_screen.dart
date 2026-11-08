import 'package:flutter/material.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../utils/format.dart';
import '../utils/theme_colors.dart';
import '../widgets/picked_image.dart';

/// Shows everything saved about one finished delivery, including the
/// proof photo taken at the door (if the file still exists on this
/// phone). Opened by tapping a row in the Earnings history list.
class HistoryDetailScreen extends StatelessWidget {
  final DeliveryRecord record;
  const HistoryDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final path = r.photoPath;
    return Scaffold(
      appBar: AppBar(title: Text('${T.t('history')} · ${r.orderId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (path != null)
            PickedImage(
              path: path,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              radius: 10,
            )
          else
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: tint(context, Colors.grey),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(T.t('no_photo'),
                  style: const TextStyle(color: Colors.grey)),
            ),
          const SizedBox(height: 16),
          Chip(
            avatar: Icon(
              record.type == OrderType.food
                  ? Icons.restaurant
                  : Icons.inventory_2,
              color: record.type == OrderType.food
                  ? Colors.deepOrange
                  : Colors.blue,
            ),
            label: Text(T.t(record.type == OrderType.food ? 'food' : 'parcel')),
          ),
          _row(context, Icons.store, T.t('pickup'), r.shopName,
              sub: r.shopAddress.isNotEmpty ? r.shopAddress : null),
          _row(context, Icons.location_on, T.t('drop'),
              r.customerName.isNotEmpty ? r.customerName : r.customerAddress,
              sub: r.customerName.isNotEmpty ? r.customerAddress : null),
          if (r.items.isNotEmpty)
            _row(context, Icons.shopping_bag_outlined, T.t('items'), r.items),
          _row(context, Icons.payments_outlined, T.t('you_earn'),
              money(r.earning)),
          if (r.codCollected > 0)
            _row(context, Icons.money, T.t('collect_cash'),
                money(r.codCollected)),
          _row(context, Icons.star_outline, T.t('rating'), '${r.rating} ★'),
          _row(context, Icons.schedule, '',
              '${fmtDate(r.completedAt)}, ${fmtTime(r.completedAt)}'),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
          {String? sub}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label.isNotEmpty)
                    Text(label,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (sub != null)
                    Text(sub,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
}
