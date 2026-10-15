import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';

void main() {
  testWidgets('home promotion banners appear in order without cropping', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final bannerKeys = [
      'home-promotion-banner-biryani',
      'home-promotion-banner-cake',
      'home-promotion-banner-vegetables',
    ];
    final horizontalLists = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-promotion-banner-biryani')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    for (final key in bannerKeys) {
      final bannerFinder = find.byKey(ValueKey(key));
      for (
        var attempt = 0;
        attempt < 3 && !tester.any(bannerFinder);
        attempt++
      ) {
        await tester.drag(horizontalLists.first, const Offset(-220, 0));
        await tester.pumpAndSettle();
      }
      expect(bannerFinder, findsOneWidget);
      final banner = tester.widget<Image>(find.byKey(ValueKey(key)));
      expect(banner.fit, BoxFit.contain);
      expect(
        banner.image,
        isA<ResizeImage>().having(
          (image) => image.imageProvider,
          'imageProvider',
          isA<AssetImage>(),
        ),
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('banner slots fit narrow and standard mobile widths', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in [const Size(280, 700), const Size(320, 720)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      final firstBanner = find.byKey(
        const ValueKey('home-promotion-banner-biryani'),
      );
      await tester.scrollUntilVisible(
        firstBanner,
        240,
        scrollable: find.byType(Scrollable).first,
      );

      final bannerSize = tester.getSize(firstBanner);
      expect(bannerSize.width / bannerSize.height, closeTo(2.25, 0.01));
      expect(bannerSize.width, lessThan(size.width));
      expect(tester.takeException(), isNull);
    }
  });
}
