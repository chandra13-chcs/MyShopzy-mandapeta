import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../cart/presentation/cart_page.dart';
import '../../bakery/presentation/bakery_page.dart';
import '../../local_stores/presentation/local_store_catalog_page.dart';
import '../../local_stores/presentation/local_stores_page.dart';
import '../../local_stores/data/local_store_session.dart';
import '../../meat/presentation/meat_page.dart';
import '../../orders/presentation/orders_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../search/presentation/search_page.dart';
import '../../vegetables_fruits/presentation/vegetables_fruits_page.dart';
import '../../../shared/presentation/bottom_navigation_bar.dart';
import '../../../shared/presentation/motion.dart';
import '../../../shared/presentation/press_scale_feedback.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  static const _ink = AppTheme.primaryText;
  static const _page = AppTheme.lightBackground;

  static const _freshCategories = [
    _CategoryTile(
      'Fresh Vegetables',
      Icons.eco_rounded,
      Color(0xFFE1F2E4),
      imagePath: 'assets/category_tiles/fruits_vegetables.jpg',
    ),
    _CategoryTile(
      'Fresh Fruits',
      Icons.apple_rounded,
      Color(0xFFFFE8D9),
      imagePath: 'assets/category_tiles/fruits_vegetables.jpg',
    ),
    _CategoryTile(
      'Dairy, Bread and Eggs',
      Icons.breakfast_dining_rounded,
      Color(0xFFF4E8D9),
    ),
    _CategoryTile(
      'Meat and Seafood',
      Icons.set_meal_rounded,
      Color(0xFFFFE4E2),
    ),
  ];

  static const _groceryCategories = [
    _CategoryTile(
      'Atta, Rice and Dal',
      Icons.rice_bowl_rounded,
      Color(0xFFF0E7D8),
    ),
    _CategoryTile(
      'Masalas',
      Icons.local_fire_department_rounded,
      Color(0xFFF6EDD4),
    ),
    _CategoryTile('Oils and Ghee', Icons.water_drop_rounded, Color(0xFFF6EDD4)),
    _CategoryTile(
      'Cereals and Breakfast',
      Icons.breakfast_dining_rounded,
      Color(0xFFF4E9D3),
    ),
  ];

  static const _snackCategories = [
    _CategoryTile(
      'Cold Drinks and Juices',
      Icons.local_drink_rounded,
      Color(0xFFE1EAF1),
    ),
    _CategoryTile(
      'Ice Creams and Frozen Foods',
      Icons.icecream_rounded,
      Color(0xFFE9E0D8),
    ),
    _CategoryTile(
      'Chips and Namkeens',
      Icons.fastfood_rounded,
      Color(0xFFF4E9D3),
    ),
    _CategoryTile('Chocolates', Icons.cake_rounded, Color(0xFFEBDDD9)),
    _CategoryTile(
      'Biscuits and Cakes',
      Icons.bakery_dining_rounded,
      Color(0xFFF2E5D5),
      imagePath: 'assets/category_tiles/bakery.jpg',
    ),
    _CategoryTile(
      'Tea, Coffee and Milk Drinks',
      Icons.coffee_rounded,
      Color(0xFFE9E0D8),
    ),
    _CategoryTile(
      'Sauces and Spreads',
      Icons.lunch_dining_rounded,
      Color(0xFFF3E2DD),
    ),
    _CategoryTile('Sweet Corner', Icons.cake_rounded, Color(0xFFEBDDD9)),
    _CategoryTile(
      'Noodles, Pasta, Vermicelli',
      Icons.ramen_dining_rounded,
      Color(0xFFF1E3D5),
    ),
    _CategoryTile('Frozen Food', Icons.ac_unit_rounded, Color(0xFFE1EAF1)),
    _CategoryTile(
      'Dry Fruits and Seeds Mix',
      Icons.spa_rounded,
      Color(0xFFE2F0E3),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            _buildGridSection(context, 'Fresh items', _freshCategories),
            _buildGridSection(context, 'Grocery & Kitchen', _groceryCategories),
            _buildGridSection(context, 'Snacks & Drinks', _snackCategories),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
      bottomNavigationBar: ShopzyBottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) Navigator.of(context).maybePop();
          if (index == 2) {
            Navigator.of(context).push(
              AppPageRoute<void>.builder(
                builder: (context) => const CartPage(),
              ),
            );
          }
          if (index == 3) {
            Navigator.of(context).push(
              AppPageRoute<void>.builder(
                builder: (context) => const OrdersPage(),
              ),
            );
          }
          if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ProfilePage(),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: 'Search categories',
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => const SearchPage()),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EBE6)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: Color(0xFF68746B),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search categories and products',
                      style: TextStyle(
                        color: Color(0xFF68746B),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  SliverMainAxisGroup _buildGridSection(
    BuildContext context,
    String title,
    List<_CategoryTile> categories,
  ) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _SectionHeading(title: title)),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = switch (constraints.crossAxisExtent) {
              < 280 => 2,
              < 320 => 3,
              _ => 4,
            };
            final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
            final mainAxisExtent = (140 + 200 * (textScale - 1))
                .clamp(140.0, double.infinity)
                .toDouble();

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final category = categories[index];
                  final tile = PressScaleFeedback(
                    child: _GridCategory(
                      category: category,
                      onTap: _gridCategoryAction(context, category.name),
                    ),
                  );
                  return fadeSlideItem(
                    itemKey: 'category-${category.name}',
                    index: index,
                    child: tile,
                  );
                }, childCount: categories.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: mainAxisExtent,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  VoidCallback? _gridCategoryAction(BuildContext context, String name) {
    final action = switch (name) {
      'Dairy, Bread and Eggs' => () => _openLocalStoreCategory(
        context,
        'dairy',
      ),
      'Fresh Vegetables' ||
      'Fresh Fruits' => () => _pushPage(context, const VegetablesFruitsPage()),
      'Meat and Seafood' => () => _pushPage(context, const MeatPage()),
      'Cold Drinks and Juices' || 'Tea, Coffee and Milk Drinks' =>
        () => _openLocalStoreCategory(context, 'beverages'),
      'Chips and Namkeens' => () => _openLocalStoreCategory(context, 'snacks'),
      'Chocolates' ||
      'Sweet Corner' => () => _pushPage(context, const BakeryPage()),
      'Biscuits and Cakes' => () => _openLocalStoreCategory(
        context,
        'biscuits',
      ),
      'Atta, Rice and Dal' => () => _openLocalStoreCategory(context, 'rice'),
      'Masalas' => () => _openLocalStoreCategory(context, 'spices'),
      'Oils and Ghee' => () => _openLocalStoreCategory(context, 'cooking-oil'),
      'Noodles, Pasta, Vermicelli' => () => _openLocalStoreCategory(
        context,
        'noodles',
      ),
      _ => null,
    };
    return action ?? () => _showCategoryUnavailable(context);
  }

  void _showCategoryUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This category catalogue is not available in the demo.'),
      ),
    );
  }

  void _openLocalStoreCategory(BuildContext context, String categoryId) {
    final categories = [...commonLocalStoreCategories];
    final selectedIndex = categories.indexWhere(
      (category) => category.id == categoryId,
    );

    if (selectedIndex == -1) {
      _pushPage(context, const LocalStoresPage());
      return;
    }

    final selectedCategory = categories.removeAt(selectedIndex);
    categories.insert(0, selectedCategory);

    final selectedStore = LocalStoreSession.instance.selectedStore;
    _pushPage(
      context,
      selectedStore == null
          ? LocalStoresPage(initialCategoryId: categoryId)
          : LocalStoreCatalogPage(
              store: selectedStore,
              categories: categories,
              initialCategoryId: categoryId,
            ),
    );
  }

  void _pushPage(BuildContext context, Widget page) {
    Navigator.of(context).push(AppPageRoute<void>(page: page));
  }
}

class _CategoryTile {
  const _CategoryTile(this.name, this.icon, this.color, {this.imagePath});

  final String name;
  final IconData icon;
  final Color color;
  final String? imagePath;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 7),
      child: Text(
        title,
        style: const TextStyle(
          color: CategoriesPage._ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
      ),
    );
  }
}

class _GridCategory extends StatelessWidget {
  const _GridCategory({required this.category, required this.onTap});

  final _CategoryTile category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = constraints.maxWidth.clamp(48.0, 88.0).toDouble();
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEBEEE9)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: _CategoryImage(category: category, size: imageSize),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 7),
                  child: Text(
                    category.name,
                    textAlign: TextAlign.left,
                    softWrap: true,
                    style: const TextStyle(
                      color: CategoriesPage._ink,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.category, required this.size});

  final _CategoryTile category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(17),
      ),
      clipBehavior: Clip.antiAlias,
      child: category.imagePath == null
          ? Icon(
              category.icon,
              color: const Color(0xFF34453A),
              size: size * 0.47,
            )
          : Image.asset(category.imagePath!, fit: BoxFit.cover),
    );
  }
}
