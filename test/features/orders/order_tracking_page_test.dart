import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:myshopzy/shared/data/customer_api.dart';
import 'package:myshopzy/features/orders/presentation/live_order_map.dart';
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
    expect(find.text('Picked Up'), findsOneWidget);
    expect(find.text('Your delivery partner is on the way'), findsOneWidget);
    expect(find.text('MSZ-DEMO-1042'), findsOneWidget);
    expect(find.text('Green Bowl Kitchen'), findsOneWidget);
    expect(find.text('2 items · Veggie Bowl, Fresh Lime Soda'), findsOneWidget);
    expect(find.text('₹348'), findsOneWidget);
    expect(find.text('+91 9XXXX XXXXX'), findsNothing);
    expect(find.text('4.8 ★'), findsNothing);
    for (final stage in [
      'Order Confirmed',
      'Packing',
      'Picked Up',
      'Delivered',
    ]) {
      expect(find.text(stage), findsOneWidget);
    }
    expect(find.text('Call'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.text('4821'), findsOneWidget);
  });

  test('maps backend statuses to the four customer stages', () {
    expect(
      orderTrackingStatusFromApi('getting_packed'),
      OrderTrackingStatus.packed,
    );
    expect(
      orderTrackingStatusFromApi('ready_for_pickup'),
      OrderTrackingStatus.packed,
    );
    expect(
      orderTrackingStatusFromApi('rider_assigned'),
      OrderTrackingStatus.riderAssigned,
    );
    expect(
      orderTrackingStatusFromApi('out_for_delivery'),
      OrderTrackingStatus.onTheWay,
    );
    expect(
      orderTrackingStatusFromApi('delivery_failed'),
      OrderTrackingStatus.deliveryFailed,
    );
    expect(
      orderTrackingStatusFromApi('cancelled'),
      OrderTrackingStatus.cancelled,
    );
    expect(
      orderTrackingStatusFromApi('rejected'),
      OrderTrackingStatus.rejected,
    );
  });

  testWidgets('cancelled and failed orders stay outside Delivered progress', (
    tester,
  ) async {
    for (final status in [
      OrderTrackingStatus.cancelled,
      OrderTrackingStatus.deliveryFailed,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingPage(
            order: OrderTrackingData(
              orderId: 'terminal-test',
              storeName: 'Test Store',
              items: '1 item',
              total: '₹100',
              status: status,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Delivered'), findsNothing);
      expect(
        find.text(
          status == OrderTrackingStatus.cancelled
              ? 'Order cancelled'
              : 'Delivery failed',
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('partner actions appear only with real contact details', (
    tester,
  ) async {
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUrls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
          if (call.method == 'launch') {
            launchedUrls.add((call.arguments as Map)['url'] as String);
            return true;
          }
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: OrderTrackingPage(
          order: OrderTrackingData(
            orderId: 'contact-test',
            storeName: 'Test Store',
            items: '1 item',
            total: '₹100',
            status: OrderTrackingStatus.onTheWay,
            partnerName: 'Rider Sample',
            partnerPhone: '+919876543210',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Rider Sample'), findsOneWidget);
    expect(find.text('•••• 3210'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Call'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Message'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.text('Call'));
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Message'));
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(launchedUrls, ['tel:+919876543210', 'sms:+919876543210']);
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

  testWidgets('live map displays home and streamed rider markers', (
    tester,
  ) async {
    final riderUpdates = StreamController<LatLng>.broadcast();
    addTearDown(riderUpdates.close);
    const home = LatLng(16.84, 81.93);
    const rider = LatLng(16.85, 81.94);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveOrderMap(
            initialCustomerLocation: home,
            initialRiderLocation: rider,
            riderLocationStream: riderUpdates.stream,
            tileProvider: _TestTileProvider(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.two_wheeler_rounded), findsOneWidget);
    expect(find.byTooltip('Center on rider'), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );

    const updatedRider = LatLng(16.86, 81.95);
    riderUpdates.add(updatedRider);
    await tester.pump();
    await tester.pump();

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer.markers.last.point, updatedRider);
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
              'updated_at': '2026-10-15T06:02:00.000Z',
              'cancellation_deadline_at': '2026-10-15T06:02:00.000Z',
              'server_now': '2026-10-15T06:03:00.000Z',
              'cancellation_eligible': false,
              'cancellation_reason': null,
              'rider': {
                'name': 'Actual Rider',
                'phone': '+919876543210',
                'latitude': 16.85,
                'longitude': 81.94,
              },
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
    expect(find.text('Actual Rider'), findsOneWidget);
    expect(find.text('•••• 3210'), findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.text('24 Market Street, Mandapeta'), findsOneWidget);
    await tester.ensureVisible(find.text('View item list'));
    await tester.tap(find.text('View item list'));
    await tester.pumpAndSettle();
    expect(find.text('Rice × 1'), findsOneWidget);
  });
}

class _TestTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
      ),
    );
  }
}
