import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../cart/presentation/cart_access_button.dart';
import '../../cart/presentation/cart_page.dart';
import '../../bakery/presentation/bakery_page.dart';
import '../../local_stores/presentation/local_store_catalog_page.dart';
import '../../local_stores/presentation/local_stores_page.dart';
import '../../local_stores/data/local_store_session.dart';
import '../../meat/presentation/meat_page.dart';
import '../../orders/presentation/orders_page.dart';
import '../../parcel/presentation/parcel_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../restaurants/presentation/restaurants_page.dart';
import '../../search/presentation/search_page.dart';
import '../../vegetables_fruits/presentation/vegetables_fruits_page.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  static const _ink = AppTheme.primaryText;
  static const _page = AppTheme.lightBackground;

  static const _shopCategories = [
    _CategoryTile('Restaurants', Icons.restaurant_rounded, Color(0xFFFFE8D9)),
    _CategoryTile('Bakery', Icons.bakery_dining_rounded, Color(0xFFF8E9D8)),
    _CategoryTile('Meat', Icons.set_meal_rounded, Color(0xFFFFE4E2)),
    _CategoryTile('Fruits & Vegetables', Icons.eco_rounded, Color(0xFFE1F2E4)),
    _CategoryTile('Local Stores', Icons.storefront_rounded, Color(0xFFECE5FA)),
    _CategoryTile('Parcel', Icons.local_shipping_rounded, Color(0xFFE5ECFA)),
  ];

  static const _shoppingCategories = [
    _CategoryTile(
      'Dairy, Bread & Eggs',
      Icons.breakfast_dining_rounded,
      Color(0xFFF4E8D9),
    ),
    _CategoryTile(
      'Fruits & Fresh Vegetables',
      Icons.eco_rounded,
      Color(0xFFE1F0DF),
    ),
    _CategoryTile(
      'Cold Drinks & Juices',
      Icons.local_drink_rounded,
      Color(0xFFE1EAF1),
    ),
    _CategoryTile(
      'Snacks & Munchies',
      Icons.fastfood_rounded,
      Color(0xFFF4E9D3),
    ),
    _CategoryTile(
      'Breakfast & Instant Food',
      Icons.ramen_dining_rounded,
      Color(0xFFF1E3D5),
    ),
    _CategoryTile(
      'Sweet Tooth & Chocolates',
      Icons.cake_rounded,
      Color(0xFFEBDDD9),
    ),
    _CategoryTile(
      'Bakery & Biscuits',
      Icons.bakery_dining_rounded,
      Color(0xFFF2E5D5),
    ),
    _CategoryTile(
      'Tea, Coffee & Milk Drinks',
      Icons.coffee_rounded,
      Color(0xFFE9E0D8),
    ),
    _CategoryTile(
      'Atta, Rice & Dal',
      Icons.rice_bowl_rounded,
      Color(0xFFF0E7D8),
    ),
    _CategoryTile(
      'Masala, Cooking Oil & Ghee',
      Icons.water_drop_rounded,
      Color(0xFFF6EDD4),
    ),
    _CategoryTile(
      'Sauces & Spreads',
      Icons.lunch_dining_rounded,
      Color(0xFFF3E2DD),
    ),
    _CategoryTile(
      'Chicken, Meat & Fresh Fish',
      Icons.set_meal_rounded,
      Color(0xFFFFE4E2),
    ),
    _CategoryTile(
      'Organic & Healthy Living',
      Icons.spa_rounded,
      Color(0xFFE2F0E3),
    ),
    _CategoryTile(
      'Baby Care Essentials',
      Icons.child_care_rounded,
      Color(0xFFE6EDF5),
    ),
    _CategoryTile(
      'Pharma & Wellness',
      Icons.health_and_safety_rounded,
      Color(0xFFE3EAF2),
    ),
    _CategoryTile(
      'Cleaning Essentials',
      Icons.cleaning_services_rounded,
      Color(0xFFE3EAF2),
    ),
    _CategoryTile(
      'Home & Office Needs',
      Icons.home_work_rounded,
      Color(0xFFECE5FA),
    ),
    _CategoryTile(
      'Personal Care & Hygiene',
      Icons.spa_rounded,
      Color(0xFFF1E3EC),
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
            SliverToBoxAdapter(child: _buildShopByStore(context)),
            _buildGridSection(context, 'Shop by Category', _shoppingCategories),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: BottomNavigationBar(
          currentIndex: 1,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.darkGreen,
          selectedItemColor: AppTheme.brandYellow,
          unselectedItemColor: AppTheme.white,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 10,
          onTap: (index) {
            if (index == 0) Navigator.of(context).maybePop();
            if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => const CartPage()),
              );
            }
            if (index == 3) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: CartNavigationIcon(),
              label: '',
              tooltip: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Categories',
              style: TextStyle(
                color: _ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => const SearchPage()),
            ),
            tooltip: 'Search categories',
            icon: const Icon(Icons.search_rounded, color: _ink, size: 25),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE8EBE6)),
              minimumSize: const Size(42, 42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopByStore(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Shop by Store'),
        SizedBox(
          height: 124,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: _shopCategories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 13),
            itemBuilder: (context, index) => _HorizontalCategory(
              category: _shopCategories[index],
              onTap: () =>
                  _openShopCategory(context, _shopCategories[index].name),
            ),
          ),
        ),
      ],
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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _GridCategory(
                category: categories[index],
                onTap: _gridCategoryAction(context, categories[index].name),
              ),
              childCount: categories.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 11,
              mainAxisSpacing: 12,
              mainAxisExtent: 112,
            ),
          ),
        ),
      ],
    );
  }

  void _openShopCategory(BuildContext context, String name) {
    final page = switch (name) {
      'Restaurants' => const RestaurantsPage(),
      'Bakery' => const BakeryPage(),
      'Meat' => const MeatPage(),
      'Fruits & Vegetables' => const VegetablesFruitsPage(),
      'Local Stores' => const LocalStoresPage(),
      'Parcel' => const ParcelPage(),
      _ => null,
    };

    if (page != null) {
      _pushPage(context, page);
    }
  }

  VoidCallback? _gridCategoryAction(BuildContext context, String name) {
    final action = switch (name) {
      'Dairy, Bread & Eggs' => () => _openLocalStoreCategory(context, 'dairy'),
      'Fruits & Fresh Vegetables' => () => _pushPage(
        context,
        const VegetablesFruitsPage(),
      ),
      'Cold Drinks & Juices' || 'Tea, Coffee & Milk Drinks' =>
        () => _openLocalStoreCategory(context, 'beverages'),
      'Snacks & Munchies' => () => _openLocalStoreCategory(context, 'snacks'),
      'Breakfast & Instant Food' => () => _openLocalStoreCategory(
        context,
        'noodles',
      ),
      'Sweet Tooth & Chocolates' => () => _pushPage(
        context,
        const BakeryPage(),
      ),
      'Bakery & Biscuits' => () => _openLocalStoreCategory(context, 'biscuits'),
      'Atta, Rice & Dal' => () => _openLocalStoreCategory(context, 'rice'),
      'Masala, Cooking Oil & Ghee' => () => _openLocalStoreCategory(
        context,
        'cooking-oil',
      ),
      'Chicken, Meat & Fresh Fish' => () => _pushPage(
        context,
        const MeatPage(),
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
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => page));
  }
}

class _CategoryTile {
  const _CategoryTile(this.name, this.icon, this.color);

  final String name;
  final IconData icon;
  final Color color;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 9),
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

class _HorizontalCategory extends StatelessWidget {
  const _HorizontalCategory({required this.category, required this.onTap});

  final _CategoryTile category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 75,
        child: Column(
          children: [
            _CategoryImage(category: category, size: 70),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CategoriesPage._ink,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
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
      child: Column(
        children: [
          _CategoryImage(category: category, size: 63),
          const SizedBox(height: 6),
          Text(
            category.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CategoriesPage._ink,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ],
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
      child: Icon(
        category.icon,
        color: const Color(0xFF34453A),
        size: size * 0.47,
      ),
    );
  }
}
