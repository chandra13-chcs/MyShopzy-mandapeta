import 'package:flutter/material.dart';

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// A soft background tint (for cards/boxes) that stays readable in BOTH
/// light and dark mode. Use instead of `Colors.xxx.shade50`.
Color tint(BuildContext context, MaterialColor color) =>
    isDark(context) ? color.shade900.withAlpha(110) : color.shade50;

/// Border colour that matches [tint].
Color tintBorder(BuildContext context, MaterialColor color) =>
    isDark(context) ? color.shade700 : color.shade200;
