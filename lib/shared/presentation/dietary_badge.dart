import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class DietaryBadge extends StatelessWidget {
  const DietaryBadge({
    required this.isVegetarian,
    super.key,
    this.compact = false,
  });

  final bool isVegetarian;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isVegetarian
        ? AppTheme.primaryGreen
        : const Color(0xFFB63E32);
    final label = isVegetarian ? 'Veg' : 'Non-Veg';

    return Tooltip(
      message: label,
      child: compact
          ? Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
