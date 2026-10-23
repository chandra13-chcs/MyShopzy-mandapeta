import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';

void main() {
  testWidgets('home promotion banners show three full-fit banners', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final bannerKeys = [
      'home-promotion-banner-restaurants',
      'home-promotion-banner-groceries',
      'home-promotion-banner-bakery',
    ];

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-promotion-banner-restaurants')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    final homeCarousel = tester.widget<PageView>(
      find.byKey(const ValueKey('home-promotions-carousel')),
    );
    expect(homeCarousel.childrenDelegate.estimatedChildCount, 3);

    for (final key in bannerKeys) {
      final bannerFinder = find.byKey(ValueKey(key));
      for (
        var attempt = 0;
        attempt < 3 && !tester.any(bannerFinder);
        attempt++
      ) {
        await tester.drag(
          find.byKey(const ValueKey('home-promotions-carousel')),
          const Offset(-360, 0),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(bannerFinder, findsOneWidget);
      final banner = tester.widget<Image>(find.byKey(ValueKey(key)));
      expect(banner.fit, BoxFit.contain);
      final clip = tester.widget<ClipRRect>(
        find.ancestor(of: bannerFinder, matching: find.byType(ClipRRect)).first,
      );
      expect(clip.borderRadius, BorderRadius.circular(16));
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

  testWidgets('carousel advances every three seconds and reverses at end', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-promotion-banner-restaurants')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('home-promotions-carousel')),
    );
    final pageController = pageView.controller!;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(pageController.page, closeTo(1, 0.01));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(pageController.page, closeTo(2, 0.01));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(pageController.page, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lower home carousel shows parcel then fruits', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final parcelBanner = find.byKey(
      const ValueKey('home-promotion-banner-parcel'),
    );
    await tester.scrollUntilVisible(
      parcelBanner,
      240,
      scrollable: find.byType(Scrollable).first,
    );

    final lowerCarousel = tester.widget<PageView>(
      find.byKey(const ValueKey('home-parcel-fruits-carousel')),
    );
    expect(lowerCarousel.childrenDelegate.estimatedChildCount, 2);
    expect(parcelBanner, findsOneWidget);
    final parcelImage = tester.widget<Image>(parcelBanner);
    expect(
      parcelImage.image,
      isA<ResizeImage>().having(
        (image) => image.imageProvider,
        'imageProvider',
        isA<AssetImage>().having(
          (image) => image.assetName,
          'assetName',
          'assets/myshopzy_banners/parellu.jpeg',
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('home-promotion-banner-fruits')),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const ValueKey('home-parcel-fruits-carousel')),
      const Offset(-320, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('home-promotion-banner-fruits')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner slots fit narrow and standard mobile widths at 2:1', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in [const Size(280, 700), const Size(320, 720)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      final firstBanner = find.byKey(
        const ValueKey('home-promotion-banner-restaurants'),
      );
      await tester.scrollUntilVisible(
        firstBanner,
        240,
        scrollable: find.byType(Scrollable).first,
      );

      final bannerSize = tester.getSize(firstBanner);
      expect(bannerSize.width / bannerSize.height, closeTo(2, 0.01));
      expect(bannerSize.width, closeTo(size.width - 32, 0.01));
      expect(tester.takeException(), isNull);
    }
  });
}
