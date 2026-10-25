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

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, this.onMainTabSelected});

  final ValueChanged<int>? onMainTabSelected;

  static const _ink = AppTheme.primaryText;
  static const _page = AppTheme.lightBackground;

  static const _freshCategories = [
    _CategoryTile(
      'Fresh Vegetables',
      Icons.eco_rounded,
      Color(0xFFE1F2E4),
      imagePath: 'assets/categories icons/freshvegetables.png.jpeg',
    ),
    _CategoryTile(
      'Fresh Fruits',
      Icons.apple_rounded,
      Color(0xFFFFE8D9),
      imagePath: 'assets/categories icons/freshfruits.png.jpeg',
    ),
    _CategoryTile(
      'Dairy, Bread and Eggs',
      Icons.breakfast_dining_rounded,
      Color(0xFFF4E8D9),
      imagePath: 'assets/categories icons/dairy,breadandeggs.png.jpeg',
    ),
    _CategoryTile(
      'Meat and Seafood',
      Icons.set_meal_rounded,
      Color(0xFFFFE4E2),
      imagePath: 'assets/categories icons/meatandseafood.png.jpeg',
    ),
  ];

  static const _groceryCategories = [
    _CategoryTile(
      'Atta, Rice and Dal',
      Icons.rice_bowl_rounded,
      Color(0xFFF0E7D8),
      imagePath: 'assets/categories icons/attaand rice.png.jpeg',
    ),
    _CategoryTile(
      'Masalas',
      Icons.local_fire_department_rounded,
      Color(0xFFF6EDD4),
      imagePath: 'assets/categories icons/masala.png.jpeg',
    ),
    _CategoryTile(
      'Oils and Ghee',
      Icons.water_drop_rounded,
      Color(0xFFF6EDD4),
      imagePath: 'assets/categories icons/oilandghee.png.jpeg',
    ),
    _CategoryTile(
      'Cereals and Breakfast',
      Icons.breakfast_dining_rounded,
      Color(0xFFF4E9D3),
      imagePath: 'assets/categories icons/cerealsand breakfast.png.jpeg',
    ),
  ];

  static const _snackCategories = [
    _CategoryTile(
      'Cold Drinks and Juices',
      Icons.local_drink_rounded,
      Color(0xFFE1EAF1),
      imagePath: 'assets/categories icons/colddrinks.png.jpeg',
    ),
    _CategoryTile(
      'Ice Creams and Frozen Foods',
      Icons.icecream_rounded,
      Color(0xFFE9E0D8),
      imagePath: 'assets/categories icons/icrreams and frozenfood.png.jpeg',
    ),
    _CategoryTile(
      'Chips and Namkeens',
      Icons.fastfood_rounded,
      Color(0xFFF4E9D3),
      imagePath: 'assets/categories icons/chips and namkeens.png.jpeg',
    ),
    _CategoryTile(
      'Chocolates',
      Icons.cake_rounded,
      Color(0xFFEBDDD9),
      imagePath: 'assets/categories icons/chacolates.png.jpeg',
    ),
    _CategoryTile(
      'Biscuits and Cakes',
      Icons.bakery_dining_rounded,
      Color(0xFFF2E5D5),
      imagePath: 'assets/categories icons/buscits and cakes.png.jpeg',
    ),
    _CategoryTile(
      'Tea, Coffee and Milk Drinks',
      Icons.coffee_rounded,
      Color(0xFFE9E0D8),
      imagePath: 'assets/categories icons/tea,cofeeand milkdriks.png.jpeg',
    ),
    _CategoryTile(
      'Sauces and Spreads',
      Icons.lunch_dining_rounded,
      Color(0xFFF3E2DD),
      imagePath: 'assets/categories icons/saucesand spreds.png.jpeg',
    ),
    _CategoryTile(
      'Sweet Corner',
      Icons.cake_rounded,
      Color(0xFFEBDDD9),
      imagePath: 'assets/categories icons/sweets.png.jpeg',
    ),
    _CategoryTile(
      'Noodles, Pasta, Vermicelli',
      Icons.ramen_dining_rounded,
      Color(0xFFF1E3D5),
      imagePath: 'assets/categories icons/noodles,pasteand vermicelli.png.jpeg',
    ),
    _CategoryTile(
      'Frozen Food',
      Icons.ac_unit_rounded,
      Color(0xFFE1EAF1),
      imagePath: 'assets/categories icons/frozenfoods.png.jpeg',
    ),
    _CategoryTile(
      'Dry Fruits and Seeds Mix',
      Icons.spa_rounded,
      Color(0xFFE2F0E3),
      imagePath: 'assets/categories icons/dryfruits and seedsmix.com.jpeg',
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
      bottomNavigationBar: onMainTabSelected == null
          ? ShopzyBottomNavigationBar(
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
            )
          : null,
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
          builder: (context, constraints) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final category = categories[index];
                final tile = _GridCategory(
                  category: category,
                  onTap: _gridCategoryAction(context, category.name),
                );
                return fadeSlideItem(
                  itemKey: 'category-${category.name}',
                  index: index,
                  child: tile,
                );
              }, childCount: categories.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
            ),
          ),
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
      'Frozen Food' => () => _pushPage(
        context,
        const LocalStoresPage(
          partnerType: 'other',
          categoryName: 'Frozen Food',
        ),
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

class _GridCategory extends StatefulWidget {
  const _GridCategory({required this.category, required this.onTap});

  final _CategoryTile category;
  final VoidCallback? onTap;

  @override
  State<_GridCategory> createState() => _GridCategoryState();
}

class _GridCategoryState extends State<_GridCategory> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed) return;
    setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        key: ValueKey('category-scale-${widget.category.name}'),
        scale: _isPressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          key: ValueKey('category-card-${widget.category.name}'),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _isPressed
                ? Color.lerp(widget.category.color, Colors.black, 0.035)
                : widget.category.color,
            borderRadius: BorderRadius.circular(16),
            border: null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              _CategoryImage(category: widget.category),
              const SizedBox(height: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    widget.category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color.fromRGBO(0, 0, 0, 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.category});

  final _CategoryTile category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('category-image-${category.name}'),
      height: 70,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: category.imagePath == null
            ? ColoredBox(
                color: category.color,
                child: Center(
                  child: Icon(
                    category.icon,
                    color: const Color(0xFF34453A),
                    size: 30,
                  ),
                ),
              )
            : Image.asset(category.imagePath!, fit: BoxFit.cover),
      ),
    );
  }
}
