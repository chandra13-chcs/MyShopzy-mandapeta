import 'package:flutter/material.dart';

import '../features/cart/presentation/cart_page.dart';
import '../features/categories/presentation/categories_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/orders/presentation/orders_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../shared/presentation/bottom_navigation_bar.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(clock: widget.clock, onMainTabSelected: _selectTab),
          CategoriesPage(onMainTabSelected: _selectTab),
          const CartPage(),
          const OrdersPage(),
          ProfilePage(onMainTabSelected: _selectTab),
        ],
      ),
      bottomNavigationBar: ShopzyBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }
}
