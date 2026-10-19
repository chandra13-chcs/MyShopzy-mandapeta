import 'package:flutter/material.dart';

import 'motion.dart';

class PressScaleFeedback extends StatefulWidget {
  const PressScaleFeedback({required this.child, super.key, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScaleFeedback> createState() => _PressScaleFeedbackState();
}

class _PressScaleFeedbackState extends State<PressScaleFeedback> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: !reduceMotion(context) && _pressed ? widget.scale : 1,
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
