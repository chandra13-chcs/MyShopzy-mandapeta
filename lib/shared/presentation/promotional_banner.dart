import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef PromotionBannerItem = ({String key, String assetPath});

class PromotionalBanner extends StatefulWidget {
  const PromotionalBanner({
    super.key,
    required this.assetPath,
    required this.semanticLabel,
    this.imageKey,
  });

  final String assetPath;
  final String semanticLabel;
  final Key? imageKey;

  @override
  State<PromotionalBanner> createState() => _PromotionalBannerState();
}

class _PromotionalBannerState extends State<PromotionalBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderRotation;

  @override
  void initState() {
    super.initState();
    _borderRotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _borderRotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: AnimatedBuilder(
        animation: _borderRotation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            widget.assetPath,
            key: widget.imageKey,
            width: double.infinity,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            cacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
            semanticLabel: widget.semanticLabel,
          ),
        ),
        builder: (context, image) {
          return CustomPaint(
            foregroundPainter: _RotatingBannerBorderPainter(
              rotation: _borderRotation.value,
            ),
            child: image,
          );
        },
      ),
    );
  }
}

class PromotionalBannerCarousel extends StatefulWidget {
  const PromotionalBannerCarousel({
    super.key,
    required this.banners,
    required this.carouselKey,
    this.onBannerTap,
  });

  final List<PromotionBannerItem> banners;
  final Key carouselKey;
  final void Function(BuildContext context, String key)? onBannerTap;

  @override
  State<PromotionalBannerCarousel> createState() =>
      _PromotionalBannerCarouselState();
}

class _PromotionalBannerCarouselState extends State<PromotionalBannerCarousel> {
  static const _autoAdvanceDuration = Duration(seconds: 3);
  static const _pageTransitionDuration = Duration(milliseconds: 450);

  final _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;
  int _direction = 1;
  bool _isAutoAdvancing = false;
  bool _isPointerDown = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoAdvance();
  }

  @override
  void didUpdateWidget(covariant PromotionalBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _currentPage = 0;
      _direction = 1;
      _pageController.jumpToPage(0);
    }
    _scheduleAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (!mounted || _isPointerDown || widget.banners.length < 2) return;
    _autoAdvanceTimer = Timer(_autoAdvanceDuration, _advancePage);
  }

  Future<void> _advancePage() async {
    if (!mounted || _isPointerDown || !_pageController.hasClients) return;

    var nextPage = _currentPage + _direction;
    if (nextPage >= widget.banners.length) {
      _direction = -1;
      nextPage = widget.banners.length - 2;
    } else if (nextPage < 0) {
      _direction = 1;
      nextPage = 1;
    }

    _isAutoAdvancing = true;
    await _pageController.animateToPage(
      nextPage,
      duration: _pageTransitionDuration,
      curve: Curves.easeInOutCubic,
    );
    _isAutoAdvancing = false;
    _scheduleAutoAdvance();
  }

  void _handlePageChanged(int page) {
    _currentPage = page;
    if (!_isAutoAdvancing) _scheduleAutoAdvance();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _isPointerDown = true;
    _autoAdvanceTimer?.cancel();
  }

  void _handlePointerEnd(PointerEvent event) {
    _isPointerDown = false;
    _scheduleAutoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: PageView.builder(
          key: widget.carouselKey,
          controller: _pageController,
          itemCount: widget.banners.length,
          onPageChanged: _handlePageChanged,
          itemBuilder: (context, index) {
            final banner = widget.banners[index];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBannerTap == null
                  ? null
                  : () => widget.onBannerTap!(context, banner.key),
              child: PromotionalBanner(
                assetPath: banner.assetPath,
                imageKey: ValueKey('home-promotion-banner-${banner.key}'),
                semanticLabel: '${banner.key} promotion banner',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RotatingBannerBorderPainter extends CustomPainter {
  const _RotatingBannerBorderPainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const strokeWidth = 3.0;
    final borderRect = rect.deflate(strokeWidth / 2);
    final gradient = SweepGradient(
      colors: const [
        Color(0xFF006633),
        Color(0xFFFFC900),
        Colors.black,
        Color(0xFFFFC900),
        Color(0xFF006633),
      ],
      stops: const [0, 0.25, 0.5, 0.75, 1],
      transform: GradientRotation(rotation * 2 * math.pi),
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        borderRect,
        const Radius.circular(16 - strokeWidth / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RotatingBannerBorderPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
