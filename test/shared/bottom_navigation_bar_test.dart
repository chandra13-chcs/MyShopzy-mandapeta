import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/shared/presentation/bottom_navigation_bar.dart';

void main() {
  testWidgets(
    'shows five evenly spaced tabs with selected and inactive colors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ShopzyBottomNavigationBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsNWidgets(1));
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Cart'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      final homeText = tester.widget<Text>(find.text('Home'));
      final categoriesText = tester.widget<Text>(find.text('Categories'));
      expect(homeText.style?.color, const Color(0xFFFFC900));
      expect(categoriesText.style?.color, Colors.white);
      expect(
        tester
            .widget<Container>(
              find
                  .ancestor(
                    of: find.byType(SafeArea),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .color,
        const Color(0xFF004D2B),
      );
    },
  );

  testWidgets('reports the selected tab tap index', (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ShopzyBottomNavigationBar(
            currentIndex: 1,
            onTap: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cart'));
    expect(tappedIndex, 2);
  });
}
