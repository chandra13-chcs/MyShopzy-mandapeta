import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/restaurants/presentation/restaurants_page.dart';

void main() {
  testWidgets('restaurant cards reflow metadata on compact screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(240, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: RestaurantsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Spice Route Kitchen'), findsOneWidget);
    expect(find.text('2.1 km · Mandapeta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
