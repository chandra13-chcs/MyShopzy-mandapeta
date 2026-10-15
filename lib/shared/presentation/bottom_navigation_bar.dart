import 'package:flutter/material.dart';

import '../../features/cart/presentation/cart_access_button.dart';

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
    (label: 'Home', icon: Icons.home_outlined),
    (label: 'Categories', icon: Icons.grid_view_outlined),
    (label: 'Cart', icon: Icons.shopping_cart_outlined),
    (label: 'Orders', icon: Icons.receipt_long_outlined),
    (label: 'Profile', icon: Icons.person_outline_rounded),
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
                Expanded(child: _buildItem(index)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    final isSelected = currentIndex == index;
    final color = isSelected ? _selected : _inactive;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkWell(
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: color, size: 23),
                child: index == 2
                    ? const CartNavigationIcon()
                    : Icon(item.icon),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
