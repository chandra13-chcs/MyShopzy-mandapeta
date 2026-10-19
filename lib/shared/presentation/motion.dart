import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kMotionFast = Duration(milliseconds: 150);
const kMotionMed = Duration(milliseconds: 250);
const kMotionSlow = Duration(milliseconds: 350);
const kMotionCurve = Curves.easeOutCubic;

bool reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

Duration staggerDelay(int index) =>
    Duration(milliseconds: 40 * index.clamp(0, 7).toInt());

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 12,
    this.keepAlive = false,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;
  final bool keepAlive;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;
  bool _started = false;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kMotionSlow,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      if (reduceMotion(context) && !_controller.isCompleted) {
        _delayTimer?.cancel();
        _controller.value = 1;
      }
      return;
    }

    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
      return;
    }

    _delayTimer = Timer(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FadeSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) updateKeepAlive();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (reduceMotion(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _controller.value,
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - _controller.value)),
          child: child,
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE8E8E8),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _reduceMotionEnabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldReduceMotion = reduceMotion(context);
    if (_reduceMotionEnabled == shouldReduceMotion) return;

    _reduceMotionEnabled = shouldReduceMotion;
    if (shouldReduceMotion) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final shift = -2 + _controller.value * 4;
          return LinearGradient(
            begin: Alignment(shift, 0),
            end: Alignment(shift + 2, 0),
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFF5F5F5),
              Color(0xFFE8E8E8),
            ],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required Widget page, RouteSettings? settings})
    : super(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (reduceMotion(context)) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: kMotionCurve,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

class AnimatedContentSwitcher extends StatelessWidget {
  const AnimatedContentSwitcher({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: reduceMotion(context) ? Duration.zero : kMotionMed,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: child,
      );
}

class AnimatedBookmarkButton extends StatefulWidget {
  const AnimatedBookmarkButton({
    super.key,
    this.color = const Color(0xFF17251F),
    this.size = 20,
  });

  final Color color;
  final double size;

  @override
  State<AnimatedBookmarkButton> createState() => _AnimatedBookmarkButtonState();
}

class _AnimatedBookmarkButtonState extends State<AnimatedBookmarkButton> {
  bool _isBookmarked = false;

  @override
  Widget build(BuildContext context) {
    final shouldReduceMotion = reduceMotion(context);
    return IconButton(
      tooltip: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _isBookmarked = !_isBookmarked);
      },
      icon: AnimatedSwitcher(
        duration: shouldReduceMotion ? Duration.zero : kMotionFast,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: child,
        ),
        child: Icon(
          _isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          key: ValueKey(_isBookmarked),
          color: _isBookmarked ? const Color(0xFFB63E32) : widget.color,
          size: widget.size,
        ),
      ),
    );
  }
}
