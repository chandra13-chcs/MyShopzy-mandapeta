import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/presentation/motion.dart';
import '../../../shared/presentation/press_scale_feedback.dart';
import '../../cart/presentation/cart_access_button.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../../wishlist/presentation/save_list_button.dart';
import 'bakery_page.dart';

enum BakeryFoodType { vegetarian, nonVegetarian }

class BakeryMenuCategory {
  const BakeryMenuCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class BakeryMenuItem {
  const BakeryMenuItem({
    required this.id,
    required this.bakeryId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.foodType,
    required this.available,
    this.imageUrl,
  });

  final String id;
  final String bakeryId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final BakeryFoodType foodType;
  final bool available;
  final String? imageUrl;
}

const sampleBakeryCategories = [
  BakeryMenuCategory(id: 'cakes', name: 'Cakes'),
  BakeryMenuCategory(id: 'pastries', name: 'Pastries'),
  BakeryMenuCategory(id: 'puffs', name: 'Puffs'),
  BakeryMenuCategory(id: 'breads', name: 'Breads'),
  BakeryMenuCategory(id: 'cookies', name: 'Cookies'),
  BakeryMenuCategory(id: 'biscuits', name: 'Biscuits'),
  BakeryMenuCategory(id: 'donuts', name: 'Donuts'),
  BakeryMenuCategory(id: 'desserts', name: 'Desserts'),
  BakeryMenuCategory(id: 'snacks', name: 'Snacks'),
  BakeryMenuCategory(id: 'beverages', name: 'Beverages'),
];

const sampleBakeryMenuItems = [
  BakeryMenuItem(
    id: 'black-forest-cake',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'cakes',
    name: 'Black Forest Cake',
    description: 'Chocolate sponge, cream and cherry topping.',
    price: 499,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'chocolate-cake',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'cakes',
    name: 'Chocolate Cake',
    description: 'Rich chocolate cake finished with smooth ganache.',
    price: 549,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'pineapple-cake',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'cakes',
    name: 'Pineapple Cake',
    description: 'Light sponge with pineapple and fresh cream.',
    price: 449,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'chocolate-pastry',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'pastries',
    name: 'Chocolate Pastry',
    description: 'A soft layered pastry with chocolate cream.',
    price: 89,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'egg-puff',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'puffs',
    name: 'Egg Puff',
    description: 'Flaky pastry filled with seasoned egg.',
    price: 35,
    foodType: BakeryFoodType.nonVegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'veg-puff',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'puffs',
    name: 'Veg Puff',
    description: 'Golden puff pastry with a spiced vegetable filling.',
    price: 25,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'chicken-puff',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'puffs',
    name: 'Chicken Puff',
    description: 'Crisp pastry with a savoury chicken filling.',
    price: 45,
    foodType: BakeryFoodType.nonVegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'fresh-bread',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'breads',
    name: 'Fresh Milk Bread',
    description: 'Soft, freshly baked loaf for everyday meals.',
    price: 55,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'butter-cookies',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'cookies',
    name: 'Butter Cookies',
    description: 'A crisp, buttery bakery favourite.',
    price: 99,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'tea-biscuits',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'biscuits',
    name: 'Tea Biscuits',
    description: 'Lightly sweet and perfect with tea.',
    price: 69,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'glazed-donut',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'donuts',
    name: 'Glazed Donut',
    description: 'Soft ring donut with a light sugar glaze.',
    price: 65,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'chocolate-brownie',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'desserts',
    name: 'Chocolate Brownie',
    description: 'Dense chocolate brownie with a fudgy centre.',
    price: 79,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'veg-samosa',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'snacks',
    name: 'Veg Samosa',
    description: 'Crisp pastry filled with spiced potato and peas.',
    price: 25,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'cold-coffee',
    bakeryId: 'sri-sai-bakery',
    categoryId: 'beverages',
    name: 'Cold Coffee',
    description: 'Chilled coffee blended smooth with milk.',
    price: 119,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'chocolate-pastry-venkateswara',
    bakeryId: 'venkateswara-bakery',
    categoryId: 'pastries',
    name: 'Chocolate Pastry',
    description: 'Fresh chocolate pastry with whipped cream.',
    price: 95,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'egg-puff-venkateswara',
    bakeryId: 'venkateswara-bakery',
    categoryId: 'puffs',
    name: 'Egg Puff',
    description: 'Freshly baked, crisp and savoury.',
    price: 38,
    foodType: BakeryFoodType.nonVegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'pineapple-cake-sweet-treats',
    bakeryId: 'sweet-treats-bakery',
    categoryId: 'cakes',
    name: 'Pineapple Cake',
    description: 'Pineapple cream cake, baked fresh daily.',
    price: 475,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
  BakeryMenuItem(
    id: 'cold-coffee-bakers-point',
    bakeryId: 'bakers-point',
    categoryId: 'beverages',
    name: 'Cold Coffee',
    description: 'Chilled and creamy coffee made to order.',
    price: 110,
    foodType: BakeryFoodType.vegetarian,
    available: true,
  ),
];

class BakeryMenuPage extends StatelessWidget {
  const BakeryMenuPage({
    required this.bakery,
    super.key,
    this.categories = sampleBakeryCategories,
    this.items = sampleBakeryMenuItems,
  });

  final BakeryShop bakery;
  final List<BakeryMenuCategory> categories;
  final List<BakeryMenuItem> items;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _page = AppTheme.lightBackground;

  @override
  Widget build(BuildContext context) {
    final bakeryItems = items.where((item) => item.bakeryId == bakery.id);
    final bakeryItemList = bakeryItems.toList();
    final menuCategories = categories
        .where(
          (category) =>
              bakeryItemList.any((item) => item.categoryId == category.id),
        )
        .toList();

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildBakeryHeader(context)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Demo bakery menu · backend bakery catalog is not supported.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildMenuHeading(bakeryItemList.length)),
            for (var categoryIndex = 0;
                categoryIndex < menuCategories.length;
                categoryIndex++)
                SliverToBoxAdapter(
                  child: fadeSlideItem(
                    itemKey: 'bakery-category-${menuCategories[categoryIndex].id}',
                    index: categoryIndex,
                    child: _buildCategorySection(
                    menuCategories[categoryIndex],
                    bakeryItemList
                        .where((item) =>
                            item.categoryId == menuCategories[categoryIndex].id)
                        .toList(),
                    ),
                  ),
                ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _buildBakeryHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCover(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x55000000), Colors.transparent],
                    stops: [0, 0.48],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                child: _HeaderAction(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const Positioned(
                top: 8,
                right: 58,
                child: _HeaderAction(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Save bakery',
                ),
              ),
              const Positioned(
                top: 8,
                right: 12,
                child: _HeaderAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share bakery',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bakery.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFE4A323),
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          bakery.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                bakery.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoTag(
                    icon: Icons.schedule_rounded,
                    label: bakery.deliveryTime,
                  ),
                  const SizedBox(width: 13),
                  _InfoTag(
                    icon: Icons.location_on_outlined,
                    label: '${bakery.distance} · ${bakery.location}',
                  ),
                  const Spacer(),
                  _OpenStatus(status: bakery.status),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8EBE6)),
      ],
    );
  }

  Widget _buildCover() {
    final imageUrl = bakery.coverImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildCoverPlaceholder(),
      );
    }
    return _buildCoverPlaceholder();
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8865A), Color(0xFF694D3A)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -53,
            right: -21,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Icon(
            Icons.bakery_dining_rounded,
            size: 66,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuHeading(int itemCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Menu',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Text(
            '$itemCount items',
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BakeryMenuCategory category,
    List<BakeryMenuItem> categoryItems,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${categoryItems.length} items',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          for (var index = 0; index < categoryItems.length; index++) ...[
            fadeSlideItem(
              itemKey: 'bakery-menu-${categoryItems[index].id}',
              index: index,
              child: PressScaleFeedback(
                child: _BakeryMenuItemCard(
                  item: categoryItems[index],
                  bakeryName: bakery.name,
                  relatedItems: items
                      .where(
                        (related) =>
                            related.bakeryId == categoryItems[index].bakeryId &&
                            related.categoryId ==
                                categoryItems[index].categoryId &&
                            related.id != categoryItems[index].id,
                      )
                      .toList(),
                ),
              ),
            ),
            if (index < categoryItems.length - 1)
              const Divider(
                height: 1,
                indent: 2,
                endIndent: 2,
                color: Color(0xFFE8EBE6),
              ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon, color: const Color(0xFF17251F), size: 20),
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF727A74), size: 15),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF17251F),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenStatus extends StatelessWidget {
  const _OpenStatus({required this.status});

  final BakeryStatus status;

  @override
  Widget build(BuildContext context) {
    final isOpen = status == BakeryStatus.open;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          color: isOpen ? AppTheme.primaryGreen : const Color(0xFF929892),
          size: 7,
        ),
        const SizedBox(width: 4),
        Text(
          isOpen ? 'Open' : 'Closed',
          style: TextStyle(
            color: isOpen ? AppTheme.primaryGreen : AppTheme.secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BakeryMenuItemCard extends StatelessWidget {
  const _BakeryMenuItemCard({
    required this.item,
    required this.bakeryName,
    required this.relatedItems,
  });

  final BakeryMenuItem item;
  final String bakeryName;
  final List<BakeryMenuItem> relatedItems;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDetails(context),
              child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FoodTypeMark(type: item.foodType),
                  const SizedBox(height: 7),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => _openDetails(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildItemImage(),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                    ),
                    child: SaveListButton(
                      product: ProductDetailsProduct(
                        id: item.id,
                        serviceType: 'bakery',
                        merchantId: item.bakeryId,
                        merchantName: bakeryName,
                        categoryId: item.categoryId,
                        name: item.name,
                        description: item.description,
                        imageUrl: item.imageUrl,
                        priceInPaise: (item.price * 100).round(),
                        available: item.available,
                        icon: Icons.bakery_dining_rounded,
                        isVegetarian:
                            item.foodType == BakeryFoodType.vegetarian,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -9,
                  left: 14,
                  right: 14,
                  child: CartProductControl(
                    available: item.available,
                    productId: item.id,
                    serviceType: 'bakery',
                    merchantId: item.bakeryId,
                    categoryId: item.categoryId,
                    name: item.name,
                    description: item.description,
                    priceInPaise: (item.price * 100).round(),
                    imageUrl: item.imageUrl,
                    icon: Icons.bakery_dining_rounded,
                    width: 84,
                    unavailableLabel: 'OUT OF STOCK',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage() {
    final imageUrl = item.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailsPage(
          product: ProductDetailsProduct(
            id: item.id,
            serviceType: 'bakery',
            merchantId: item.bakeryId,
            merchantName: bakeryName,
            categoryId: item.categoryId,
            name: item.name,
            description: item.description,
            imageUrl: item.imageUrl,
            priceInPaise: (item.price * 100).round(),
            available: item.available,
            icon: Icons.bakery_dining_rounded,
            isVegetarian: item.foodType == BakeryFoodType.vegetarian,
            relatedProducts: relatedItems
                .map(
                  (related) => ProductDetailsProduct(
                    id: related.id,
                    serviceType: 'bakery',
                    merchantId: related.bakeryId,
                    merchantName: bakeryName,
                    categoryId: related.categoryId,
                    name: related.name,
                    description: related.description,
                    imageUrl: related.imageUrl,
                    priceInPaise: (related.price * 100).round(),
                    available: related.available,
                    icon: Icons.bakery_dining_rounded,
                    isVegetarian: related.foodType == BakeryFoodType.vegetarian,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 112,
      height: 112,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4E2CE), Color(0xFFD9B990)],
        ),
      ),
      child: Icon(
        Icons.bakery_dining_rounded,
        size: 42,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}

class _FoodTypeMark extends StatelessWidget {
  const _FoodTypeMark({required this.type});

  final BakeryFoodType type;

  @override
  Widget build(BuildContext context) {
    final color = type == BakeryFoodType.vegetarian
        ? AppTheme.primaryGreen
        : const Color(0xFFB63E32);
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
