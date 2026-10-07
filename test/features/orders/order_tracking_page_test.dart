import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/orders/presentation/order_tracking_page.dart';
import 'package:myshopzy/features/orders/presentation/orders_page.dart';

void main() {
  testWidgets('ongoing order details opens tracking with demo order details', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Track Order'));
    await tester.tap(find.text('Track Order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderTrackingPage), findsOneWidget);
    expect(find.text('On the way'), findsWidgets);
    expect(find.text('Your delivery partner is on the way'), findsOneWidget);
    expect(find.text('MSZ-DEMO-1042'), findsOneWidget);
    expect(find.text('Green Bowl Kitchen'), findsOneWidget);
    expect(find.text('2 items · Veggie Bowl, Fresh Lime Soda'), findsOneWidget);
    expect(find.text('₹348'), findsOneWidget);
    expect(find.text('+91 9XXXX XXXXX'), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
  });

  testWidgets('delivered order details shows completion and receipt action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
    await tester.tap(find.text('Delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderTrackingPage), findsNothing);
    expect(find.text('Delivered'), findsWidgets);
    expect(find.text('View Receipt'), findsOneWidget);
    expect(find.text('Track Order'), findsNothing);
  });
}
