import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:myshopzy/customer/order_tracking_screen.dart';

void main() {
  testWidgets('updates rider marker and enables map recentering', (
    tester,
  ) async {
    final riderLocations = StreamController<LatLng>();
    addTearDown(riderLocations.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          storeLocation: LatLng(-18.98, 82.28),
          customerLocation: LatLng(-18.99, 82.29),
          riderLocationStream: riderLocations.stream,
        ),
      ),
    );

    expect(find.text('Waiting for rider location'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );

    riderLocations.add(LatLng(-18.985, 82.285));
    await tester.pump();

    expect(find.text('Rider location live'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byTooltip('Center on rider'));
    await tester.pump();
  });
}
