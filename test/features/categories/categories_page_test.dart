import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/bakery/presentation/bakery_page.dart';
import 'package:myshopzy/features/categories/presentation/categories_page.dart';
import 'package:myshopzy/features/local_stores/presentation/local_stores_page.dart';
import 'package:myshopzy/features/search/presentation/search_page.dart';

void main() {
  const approvedCategories = [
    'Fresh Vegetables',
    'Fresh Fruits',
    'Dairy, Bread and Eggs',
    'Meat and Seafood',
    'Atta, Rice and Dal',
    'Masalas',
    'Oils and Ghee',
    'Cereals and Breakfast',
    'Cold Drinks and Juices',
    'Ice Creams and Frozen Foods',
    'Chips and Namkeens',
    'Chocolates',
    'Biscuits and Cakes',
    'Tea, Coffee and Milk Drinks',
    'Sauces and Spreads',
    'Sweet Corner',
    'Noodles, Pasta, Vermicelli',
    'Frozen Food',
    'Dry Fruits and Seeds Mix',
  ];

  testWidgets('shows requested categories in the requested sections', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    expect(find.text('Fresh items'), findsOneWidget);

    for (final category in approvedCategories) {
      final categoryFinder = category == 'Home Needs'
          ? find.text(category).last
          : find.text(category);
      await tester.scrollUntilVisible(
        categoryFinder,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(categoryFinder, findsOneWidget);
    }

    expect(find.text('Paan Corner'), findsNothing);
    expect(find.text('Cold Drinks & Juices'), findsNothing);
    expect(find.text('Home & Office Needs'), findsNothing);
    expect(find.text('Home Needs'), findsNothing);
    expect(find.text('Shop by Store'), findsNothing);
  });

  testWidgets('category listing navigation remains available', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    await tester.scrollUntilVisible(
      find.text('Chocolates'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Chocolates'));
    final chocolateTile = find.ancestor(
      of: find.text('Chocolates'),
      matching: find.byType(GestureDetector),
    );
    await tester.tapAt(
      tester.getTopLeft(chocolateTile.first) + const Offset(30, 30),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BakeryPage), findsOneWidget);
  });

  testWidgets('Frozen Food opens the existing Local Stores flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final frozenFoodCard = find.ancestor(
      of: find.text('Frozen Food'),
      matching: find.byType(GestureDetector),
    );
    await tester.ensureVisible(frozenFoodCard.first);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(frozenFoodCard.first));
    await tester.pumpAndSettle();

    expect(find.byType(LocalStoresPage), findsOneWidget);
    expect(
      tester.widget<LocalStoresPage>(find.byType(LocalStoresPage)).partnerType,
      'other',
    );
    expect(find.text('Frozen Food near you'), findsOneWidget);
    expect(find.byType(BakeryPage), findsNothing);
  });

  testWidgets('Categories search bar opens the existing SearchPage', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    await tester.tap(find.byTooltip('Search categories'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsOneWidget);
    expect(
      find.text('Search restaurants, groceries, products...'),
      findsOneWidget,
    );
  });

  testWidgets('category grid fits compact screens with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: const MaterialApp(home: CategoriesPage()),
      ),
    );
    await tester.pumpAndSettle();

    final firstTileImage = tester.getRect(find.byType(Image).first);
    final firstTileLabel = tester.getRect(find.text('Fresh Vegetables'));
    expect(firstTileLabel.top, greaterThanOrEqualTo(firstTileImage.bottom));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Masalas'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    final gridDelegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(gridDelegate.crossAxisCount, 3);
    expect(gridDelegate.childAspectRatio, 0.85);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category cards use uniform rounded image areas and labels', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    final imageFinder = find.byType(Image).first;
    final image = tester.widget<Image>(imageFinder);
    expect(image.fit, BoxFit.contain);
    expect(image.filterQuality, FilterQuality.high);

    final imageContainerFinder = find.byKey(
      const ValueKey('category-image-Fresh Vegetables'),
    );
    final imageContainer = tester.widget<Padding>(imageContainerFinder);
    final imageSize = tester.getSize(imageContainerFinder);
    expect(imageContainer.padding, const EdgeInsets.all(10));
    expect(imageSize.height, greaterThan(70));

    final categoryCardFinder = find.byKey(
      const ValueKey('category-card-Fresh Vegetables'),
    );
    final categoryCard = tester.widget<AnimatedContainer>(categoryCardFinder);
    final cardDecoration = categoryCard.decoration! as BoxDecoration;
    expect(cardDecoration.color, const Color(0xFFE1F2E4));
    expect(cardDecoration.borderRadius, BorderRadius.circular(18));
    expect(cardDecoration.border, isNull);
    expect(cardDecoration.boxShadow, hasLength(1));
    expect(cardDecoration.boxShadow!.single.blurRadius, 8);
    expect(cardDecoration.boxShadow!.single.offset, const Offset(0, 3));
    expect(
      cardDecoration.boxShadow!.single.color,
      Colors.black.withValues(alpha: 0.03),
    );

    expect(
      tester.widget<Text>(find.text('Fresh Vegetables')).textAlign,
      TextAlign.center,
    );
    final label = tester.widget<Text>(find.text('Fresh Vegetables'));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.style!.fontSize, 12);
    expect(label.style!.fontWeight, FontWeight.w600);
    expect(label.style!.color, Colors.black87);

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisSpacing, 12);
    expect(delegate.mainAxisSpacing, 12);
  });

  testWidgets('category card animates its fill and scale while pressed', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));
    await tester.pumpAndSettle();

    final categoryCardFinder = find.byKey(
      const ValueKey('category-card-Fresh Vegetables'),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(categoryCardFinder),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final scaleFinder = find.byKey(
      const ValueKey('category-scale-Fresh Vegetables'),
    );
    expect(tester.widget<AnimatedScale>(scaleFinder).scale, 0.94);
    final pressedCard = tester.widget<AnimatedContainer>(categoryCardFinder);
    expect(
      (pressedCard.decoration! as BoxDecoration).color,
      Color.lerp(const Color(0xFFE1F2E4), Colors.black, 0.035),
    );

    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scaleFinder).scale, 1);
    final releasedCard = tester.widget<AnimatedContainer>(categoryCardFinder);
    expect(
      (releasedCard.decoration! as BoxDecoration).color,
      const Color(0xFFE1F2E4),
    );
  });

  testWidgets('categories use their supplied local images', (tester) async {
    const categoryImages = {
      'Fresh Vegetables': 'assets/categories icons/freshvegetables.png.jpeg',
      'Fresh Fruits': 'assets/categories icons/freshfruits.png.jpeg',
      'Dairy, Bread and Eggs':
          'assets/categories icons/dairy,breadandeggs.png.jpeg',
      'Meat and Seafood': 'assets/categories icons/meatandseafood.png.jpeg',
      'Atta, Rice and Dal': 'assets/categories icons/attaand rice.png.jpeg',
      'Masalas': 'assets/categories icons/masala.png.jpeg',
      'Oils and Ghee': 'assets/categories icons/oilandghee.png.jpeg',
      'Cereals and Breakfast':
          'assets/categories icons/cerealsand breakfast.png.jpeg',
      'Cold Drinks and Juices': 'assets/categories icons/colddrinks.png.jpeg',
      'Ice Creams and Frozen Foods':
          'assets/categories icons/icrreams and frozenfood.png.jpeg',
      'Chips and Namkeens':
          'assets/categories icons/chips and namkeens.png.jpeg',
      'Chocolates': 'assets/categories icons/chacolates.png.jpeg',
      'Biscuits and Cakes':
          'assets/categories icons/buscits and cakes.png.jpeg',
      'Tea, Coffee and Milk Drinks':
          'assets/categories icons/tea,cofeeand milkdriks.png.jpeg',
      'Sauces and Spreads': 'assets/categories icons/saucesand spreds.png.jpeg',
      'Sweet Corner': 'assets/categories icons/sweets.png.jpeg',
      'Noodles, Pasta, Vermicelli':
          'assets/categories icons/noodles,pasteand vermicelli.png.jpeg',
      'Frozen Food': 'assets/categories icons/frozenfoods.png.jpeg',
      'Dry Fruits and Seeds Mix':
          'assets/categories icons/dryfruits and seedsmix.com.jpeg',
    };

    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));

    for (final entry in categoryImages.entries) {
      final imageBox = find.byKey(ValueKey('category-image-${entry.key}'));
      await tester.scrollUntilVisible(
        imageBox,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      final image = tester.widget<Image>(
        find.descendant(of: imageBox, matching: find.byType(Image)),
      );
      expect(
        image.image,
        isA<AssetImage>().having(
          (asset) => asset.assetName,
          'assetName',
          entry.value,
        ),
      );
      expect(image.fit, BoxFit.contain);
      expect(image.filterQuality, FilterQuality.high);
    }
  });
}
