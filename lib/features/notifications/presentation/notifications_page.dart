import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  static final List<_DemoNotification> _notifications = [
    _DemoNotification(
      icon: Icons.receipt_long_outlined,
      title: 'Order confirmed',
      description: 'Your order from Green Bowl Kitchen has been confirmed.',
      time: '5 min ago',
      isUnread: true,
    ),
    _DemoNotification(
      icon: Icons.soup_kitchen_outlined,
      title: 'Order is being prepared',
      description: 'The store is preparing your order with care.',
      time: '18 min ago',
      isUnread: true,
    ),
    _DemoNotification(
      icon: Icons.delivery_dining_outlined,
      title: 'Rider has picked up your order',
      description: 'Your order is on its way to you.',
      time: '32 min ago',
      isUnread: true,
    ),
    _DemoNotification(
      icon: Icons.delivery_dining_outlined,
      title: 'Rider is arriving soon',
      description: 'Your delivery is nearly at your door.',
      time: '1 hour ago',
    ),
    _DemoNotification(
      icon: Icons.check_circle_outline_rounded,
      title: 'Order delivered',
      description: 'Your recent order was delivered successfully.',
      time: 'Yesterday',
    ),
    _DemoNotification(
      icon: Icons.local_offer_outlined,
      title: 'New offer available',
      description: 'There are new savings waiting for your next order.',
      time: 'Yesterday',
      isUnread: true,
    ),
    _DemoNotification(
      icon: Icons.discount_outlined,
      title: 'A coupon for you',
      description: 'Check out the latest demo offer in your account.',
      time: '2 days ago',
    ),
    _DemoNotification(
      icon: Icons.payments_outlined,
      title: 'Payment successful',
      description: 'Your demo order payment was completed successfully.',
      time: '2 days ago',
    ),
    _DemoNotification(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payment update',
      description: 'A payment update is available for your recent order.',
      time: '3 days ago',
    ),
  ];

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(
    _notifications.where((notification) => notification.isUnread).length,
  );

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: NotificationsPage._notifications.isEmpty
            ? _buildEmptyState()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _hasUnread
                            ? () {
                                setState(() {
                                  for (final notification
                                      in NotificationsPage._notifications) {
                                    notification.isUnread = false;
                                  }
                                  _updateUnreadCount();
                                });
                              }
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: _green,
                          disabledForegroundColor: _secondaryText,
                        ),
                        child: const Text('Mark all as read'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: NotificationsPage._notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification =
                            NotificationsPage._notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  bool get _hasUnread =>
      NotificationsPage._notifications.any(
        (notification) => notification.isUnread,
      );

  void _updateUnreadCount() {
    NotificationsPage.unreadCount.value = NotificationsPage._notifications
        .where((notification) => notification.isUnread)
        .length;
  }

  Widget _buildNotificationCard(_DemoNotification notification) {
    final unread = notification.isUnread;
    return Material(
      color: unread ? _lightGreen : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: unread
            ? () {
                setState(() {
                  notification.isUnread = false;
                  _updateUnreadCount();
                });
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: unread ? Colors.white : _lightGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(notification.icon, color: _green, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: _mainText,
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.description,
                      style: const TextStyle(
                        color: _secondaryText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.time,
                      style: const TextStyle(
                        color: _secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: _secondaryText,
              size: 50,
            ),
            SizedBox(height: 14),
            Text(
              'No notifications',
              style: TextStyle(
                color: _mainText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "You're all caught up. Check back later for updates.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoNotification {
  _DemoNotification({
    required this.icon,
    required this.title,
    required this.description,
    required this.time,
    this.isUnread = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String time;
  bool isUnread;
}
