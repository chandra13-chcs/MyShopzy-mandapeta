import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../features/cart/presentation/cart_access_button.dart';
import 'motion.dart';

class ShopzyBottomNavigationBar extends StatelessWidget {
  const ShopzyBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _background = Color(0xFF004D2B);
  static const _selected = Color(0xFFFFC900);
  static const _inactive = Colors.white;
  static const _items = [
    (label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
    (
      label: 'Categories',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
    (
      label: 'Cart',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart_rounded,
    ),
    (
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    (
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(11);
    return Container(
      color: _background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 45 + scaledLabelHeight * 1.2,
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(child: _buildItem(context, index)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _items[index];
    final isSelected = currentIndex == index;
    final color = isSelected ? _selected : _inactive;
    final reduceAnimations = reduceMotion(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(index);
        },
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(color: color, size: 23),
                    child: AnimatedScale(
                      scale: isSelected ? 1.06 : 1,
                      duration: reduceAnimations ? Duration.zero : kMotionFast,
                      curve: kMotionCurve,
                      child: index == 2
                          ? const CartNavigationIcon()
                          : AnimatedSwitcher(
                              duration: reduceAnimations
                                  ? Duration.zero
                                  : kMotionFast,
                              child: Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                key: ValueKey('${item.label}-$isSelected'),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 3,
              child: AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: reduceAnimations ? Duration.zero : kMotionFast,
                child: Container(
                  width: 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.navSelected,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
