import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class AuthCornerDecoration extends StatelessWidget {
  const AuthCornerDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(
        painter: _AuthCornerPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class MyShopzyBrand extends StatelessWidget {
  const MyShopzyBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 52.0 : 86.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize * 0.8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.shopping_cart_rounded,
                size: iconSize,
                color: AppTheme.primaryGreen,
              ),
              Positioned(
                top: iconSize * 0.11,
                child: Icon(
                  Icons.check_rounded,
                  size: iconSize * 0.43,
                  color: AppTheme.brandYellow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: compact ? 30 : 43,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
              height: 1,
            ),
            children: const [
              TextSpan(
                text: 'My',
                style: TextStyle(color: AppTheme.darkGreen),
              ),
              TextSpan(
                text: 'Shopzy',
                style: TextStyle(color: AppTheme.brandYellow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'P R I V A T E   L I M I T E D',
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontSize: compact ? 10 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AuthCornerPainter extends CustomPainter {
  const _AuthCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paleGreen = Paint()..color = const Color(0xFFE6F5E8);
    final paleYellow = Paint()..color = const Color(0xFFFFF7D6);
    final accent = Paint()
      ..color = AppTheme.brandYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final topLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.28, 0)
      ..cubicTo(
        size.width * 0.21,
        size.height * 0.07,
        size.width * 0.13,
        size.height * 0.06,
        0,
        size.height * 0.13,
      )
      ..close();
    canvas.drawPath(topLeft, paleGreen);

    final topAccent = Path()
      ..moveTo(0, size.height * 0.15)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.07,
        size.width * 0.22,
        size.height * 0.08,
        size.width * 0.30,
        0,
      );
    canvas.drawPath(topAccent, accent);

    final bottomRight = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.72, size.height)
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.92,
        size.width * 0.88,
        size.height * 0.94,
        size.width,
        size.height * 0.86,
      )
      ..close();
    canvas.drawPath(bottomRight, paleYellow);

    final bottomAccent = Path()
      ..moveTo(size.width, size.height * 0.84)
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.91,
        size.width * 0.78,
        size.height * 0.92,
        size.width * 0.70,
        size.height,
      );
    canvas.drawPath(bottomAccent, accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
