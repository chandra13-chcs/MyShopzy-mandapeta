import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/coupons/presentation/coupons_page.dart';
import 'package:myshopzy/features/notifications/presentation/notifications_page.dart';
import 'package:myshopzy/features/profile/presentation/profile_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  setUp(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(
      baseUrl: '',
      enableDevelopmentPreview: true,
    );
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('notification badge follows unread and mark-all state', (
    tester,
  ) async {
    expect(NotificationsPage.unreadCount.value, 4);
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));

    await tester.ensureVisible(find.text('Notifications'));
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(NotificationsPage.unreadCount.value, 4);
    await tester.tap(find.text('Order confirmed'));
    await tester.pumpAndSettle();
    expect(NotificationsPage.unreadCount.value, 3);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(NotificationsPage.unreadCount.value, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('4'), findsNothing);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('coupons show unseen count and mark coupons seen on open', (
    tester,
  ) async {
    expect(CouponsPage.newDemoCouponCount.value, 3);
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));

    await tester.ensureVisible(find.text('Coupons & Offers'));
    expect(find.text('3 New'), findsOneWidget);
    await tester.tap(find.text('Coupons & Offers'));
    await tester.pumpAndSettle();

    expect(find.byType(CouponsPage), findsOneWidget);
    expect(CouponsPage.newDemoCouponCount.value, 0);
    expect(find.text('Available Coupons'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Offers'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('3 New'), findsNothing);
    expect(find.text('Coupons & Offers'), findsOneWidget);
  });
}
