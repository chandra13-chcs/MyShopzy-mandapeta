import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/shared/data/customer_api.dart';
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

  testWidgets('backend tracking refreshes status and delivery details', (
    tester,
  ) async {
    CustomerApi.instance.close();
    final api = CustomerApi(
      baseUrl: 'https://shop.example',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/me/orders/order-123');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'order-123',
              'shop_id': 'shop-123',
              'shop_name': 'Mandapeta Store',
              'status': 'out_for_delivery',
              'currency': 'INR',
              'items_subtotal_minor': '12000',
              'delivery_fee_minor': '0',
              'discount_minor': '0',
              'total_minor': '12000',
              'placed_at': '2026-10-15T06:00:00.000Z',
              'delivery_address_snapshot': {
                'label': 'Work',
                'formattedAddress': '24 Market Street, Mandapeta',
              },
              'items': [
                {
                  'product_name_snapshot': 'Rice',
                  'quantity': 1,
                  'unit_price_minor': '12000',
                  'line_total_minor': '12000',
                  'currency': 'INR',
                  'sku_snapshot': null,
                  'variant_snapshot': null,
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    CustomerApi.instance = api;
    addTearDown(() {
      api.close();
      CustomerApi.instance = CustomerApi(baseUrl: '');
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: OrderTrackingPage(
          order: OrderTrackingData(
            orderId: 'order-123',
            storeName: 'Old Store',
            items: '1 item',
            total: '₹120',
            status: OrderTrackingStatus.orderPlaced,
            isDemo: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Out for delivery'), findsOneWidget);
    expect(find.text('Mandapeta Store'), findsOneWidget);
    expect(find.text('24 Market Street, Mandapeta'), findsOneWidget);
    await tester.ensureVisible(find.text('View item list'));
    await tester.tap(find.text('View item list'));
    await tester.pumpAndSettle();
    expect(find.text('Rice × 1'), findsOneWidget);
  });
}
