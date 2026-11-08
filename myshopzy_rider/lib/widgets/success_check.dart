import 'package:flutter/material.dart';

class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 120, this.onDone});

  final double size;
  final VoidCallback? onDone;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener(_onStatus);
    _scale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onDone?.call();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.scale(
          scale: _scale.value,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _SuccessCheckPainter(progress: _controller.value),
          ),
        ),
      );
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.43;
    final strokeWidth = size.shortestSide * 0.055;
    final circleProgress = (progress / 0.58).clamp(0.0, 1.0);
    final circlePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        6.2832 * circleProgress,
        false,
        circlePaint,
      );
    }

    final tickProgress = ((progress - 0.58) / 0.38).clamp(0.0, 1.0);
    if (tickProgress <= 0) return;
    final start = Offset(size.width * 0.28, size.height * 0.52);
    final corner = Offset(size.width * 0.44, size.height * 0.67);
    final end = Offset(size.width * 0.73, size.height * 0.36);
    final tickPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(start.dx, start.dy);
    if (tickProgress < 0.45) {
      final t = tickProgress / 0.45;
      path.lineTo(
        start.dx + (corner.dx - start.dx) * t,
        start.dy + (corner.dy - start.dy) * t,
      );
    } else {
      path
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(
          corner.dx + (end.dx - corner.dx) * ((tickProgress - 0.45) / 0.55),
          corner.dy + (end.dy - corner.dy) * ((tickProgress - 0.45) / 0.55),
        );
    }
    canvas.drawPath(path, tickPaint);
  }

  @override
  bool shouldRepaint(covariant _SuccessCheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
