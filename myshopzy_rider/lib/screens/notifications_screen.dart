import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../services/rider_controller.dart';
import '../utils/format.dart';

/// Feature 9: list of in-app notifications (new orders, deliveries, payouts).
/// Opening it marks everything as read (the red badge on the bell goes away).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so we never notify listeners while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RiderController>().markNotificationsSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderController>();
    final list = c.notifications;
    return Scaffold(
      appBar: AppBar(
        title: Text(T.t('notifications')),
        actions: [
          if (list.isNotEmpty)
            TextButton(
              onPressed: c.clearNotifications,
              child: Text(T.t('clear_all')),
            ),
        ],
      ),
      body: list.isEmpty
          ? Center(child: Text(T.t('no_notif')))
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(list[i].title),
                subtitle: Text(list[i].body),
                trailing: Text(fmtTime(list[i].time),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
    );
  }
}
