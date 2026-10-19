import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/presentation/motion.dart';
import '../../../shared/presentation/offline_error_state.dart';
import '../../cart/presentation/cart_access_button.dart';
import '../../local_stores/presentation/local_store_catalog_page.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../../wishlist/presentation/save_list_button.dart';
import 'restaurants_page.dart';

enum FoodType { vegetarian, nonVegetarian, unknown }

class MenuCategory {
  const MenuCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.foodType,
    required this.isVeg,
    required this.available,
    this.isBackendProduct = false,
    this.dietaryInfoAvailable = true,
    this.imageUrl,
    this.brand,
    this.packSize,
    this.rating,
    this.mrp,
    this.discount = 0,
    this.badge,
  });

  final String id;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final FoodType foodType;
  final bool isVeg;
  final bool available;
  final bool isBackendProduct;
  final bool dietaryInfoAvailable;
  final String? brand;
  final String? packSize;
  final double? rating;
  final double? mrp;
  final int discount;
  final String? badge;
}

const sampleRestaurantMenuCategories = [
  MenuCategory(id: 'recommended', name: 'Recommended'),
  MenuCategory(id: 'starters', name: 'Starters'),
  MenuCategory(id: 'main-course', name: 'Main Course'),
  MenuCategory(id: 'biryani', name: 'Biryani'),
  MenuCategory(id: 'rice-noodles', name: 'Rice & Noodles'),
  MenuCategory(id: 'breads', name: 'Breads'),
  MenuCategory(id: 'desserts', name: 'Desserts'),
  MenuCategory(id: 'beverages', name: 'Beverages'),
];

const sampleRestaurantMenuItems = [
  MenuItem(
    id: 'chicken-dum-biryani',
    restaurantId: 'spice-route',
    categoryId: 'recommended',
    name: 'Chicken Dum Biryani',
    description: 'Fragrant basmati, dum-cooked with tender chicken.',
    price: 249,
    foodType: FoodType.nonVegetarian,
    isVeg: false,
    available: true,
  ),
  MenuItem(
    id: 'paneer-tikka',
    restaurantId: 'spice-route',
    categoryId: 'recommended',
    name: 'Tandoori Paneer Tikka',
    description: 'Smoky paneer, peppers and house-made marinade.',
    price: 219,
    foodType: FoodType.vegetarian,
    isVeg: true,
    available: true,
  ),
  MenuItem(
    id: 'chilli-paneer',
    restaurantId: 'spice-route',
    categoryId: 'starters',
    name: 'Chilli Paneer',
    description: 'Crisp paneer tossed with peppers and a tangy sauce.',
    price: 199,
    foodType: FoodType.vegetarian,
    isVeg: true,
    available: true,
  ),
  MenuItem(
    id: 'chicken-65',
    restaurantId: 'spice-route',
    categoryId: 'starters',
    name: 'Andhra Chicken 65',
    description: 'Spiced, crisp chicken with curry leaves and chilli.',
    price: 229,
    foodType: FoodType.nonVegetarian,
    isVeg: false,
    available: true,
  ),
  MenuItem(
    id: 'andhra-meals',
    restaurantId: 'spice-route',
    categoryId: 'main-course',
    name: 'Andhra Special Meals',
    description: 'A homestyle spread with rice, curries and sides.',
    price: 189,
    foodType: FoodType.vegetarian,
    isVeg: true,
    available: true,
  ),
  MenuItem(
    id: 'veg-dum-biryani',
    restaurantId: 'spice-route',
    categoryId: 'biryani',
    name: 'Veg Dum Biryani',
    description: 'Basmati rice layered with vegetables and whole spices.',
    price: 189,
    foodType: FoodType.vegetarian,
    isVeg: true,
    available: true,
  ),
  MenuItem(
    id: 'chicken-biryani',
    restaurantId: 'spice-route',
    categoryId: 'biryani',
    name: 'Spicy Chicken Biryani',
    description: 'A bold, local-style chicken biryani with raita.',
    price: 269,
    foodType: FoodType.nonVegetarian,
    isVeg: false,
    available: true,
  ),
  MenuItem(
    id: 'butter-naan',
    restaurantId: 'spice-route',
    categoryId: 'breads',
    name: 'Butter Naan',
    description: 'Soft tandoor-baked naan finished with butter.',
    price: 49,
    foodType: FoodType.vegetarian,
    isVeg: true,
    available: true,
  ),
  MenuItem(
    id: 'gulab-jamun',
    restaurantId: 'spice-route',
    categoryId: 'desserts',
    name: 'Gulab Jamun',
    description: 'Warm, soft dumplings in a light cardamom syrup.',
    price: 89,
    foodType: FoodType.vegetarian,
    isVeg: true,
    available: true,
  ),
  MenuItem(
    id: 'masala-butter-milk',
    restaurantId: 'spice-route',
    categoryId: 'beverages',
    name: 'Masala Buttermilk',
    description: 'Chilled and lightly spiced, made in-house.',
    price: 49,
    foodType: FoodType.vegetarian,
    isVeg: true,
    available: false,
  ),
];

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({
    required this.restaurant,
    super.key,
    this.categories = sampleRestaurantMenuCategories,
    this.menuItems = sampleRestaurantMenuItems,
  });

  final Restaurant restaurant;
  final List<MenuCategory> categories;
  final List<MenuItem> menuItems;

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

enum _DietaryFilter { all, veg, nonVeg }

class _RestaurantCatalog {
  const _RestaurantCatalog({required this.categories, required this.items});

  final List<MenuCategory> categories;
  final List<MenuItem> items;
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _page = AppTheme.lightBackground;

  late Future<_RestaurantCatalog>? _catalogFuture;
  Future<List<ApiCategory>>? _categoriesFuture;
  _DietaryFilter _selectedFilter = _DietaryFilter.all;
  String _productQuery = '';

  @override
  void initState() {
    super.initState();
    final api = CustomerApi.instance;
    _catalogFuture = api.isConfigured && widget.restaurant.isBackendData
        ? _loadCatalog(api)
        : null;
  }

  Future<_RestaurantCatalog> _loadCatalog(
    CustomerApi api, {
    String? query,
  }) async {
    final categoriesFuture = _categoriesFuture ??= api.getCategories(
      widget.restaurant.id,
    );
    final productsFuture = api.getAllProducts(
      shopId: widget.restaurant.id,
      query: query,
    );
    late final List<ApiCategory> categories;
    try {
      categories = await categoriesFuture;
    } on CustomerApiException {
      if (identical(_categoriesFuture, categoriesFuture)) {
        _categoriesFuture = null;
      }
      rethrow;
    }
    final products = await productsFuture;
    final menuCategories = categories
        .map((category) => MenuCategory(id: category.id, name: category.name))
        .toList();
    final categoryIds = categories.map((category) => category.id).toSet();
    const uncategorizedId = 'uncategorized';
    if (products.any(
      (product) =>
          product.categoryId == null ||
          !categoryIds.contains(product.categoryId),
    )) {
      menuCategories.add(
        const MenuCategory(id: uncategorizedId, name: 'Uncategorized'),
      );
    }
    final items = products.map((product) {
      final categoryId =
          product.categoryId != null && categoryIds.contains(product.categoryId)
          ? product.categoryId!
          : uncategorizedId;
      return MenuItem(
        id: product.id,
        restaurantId: widget.restaurant.id,
        categoryId: categoryId,
        name: product.name,
        description: product.description,
        price: product.priceMinor / 100,
        foodType: FoodType.unknown,
        isVeg: false,
        available: product.available,
        isBackendProduct: true,
        dietaryInfoAvailable: false,
        imageUrl: product.imageUrl,
        brand: product.brand,
        packSize: product.packSize,
        rating: product.rating,
        mrp: product.mrpMinor == null ? null : product.mrpMinor! / 100,
        discount: product.discountPercent,
        badge: product.badge,
      );
    }).toList();
    return _RestaurantCatalog(categories: menuCategories, items: items);
  }

  Future<void> _refreshCatalog() async {
    final api = CustomerApi.instance;
    final future = _loadCatalog(
      api,
      query: _productQuery.isEmpty ? null : _productQuery,
    );
    setState(() => _catalogFuture = future);
    try {
      await future;
    } on CustomerApiException {
      // The FutureBuilder presents the same request error on the page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogFuture = _catalogFuture;
    if (catalogFuture == null) {
      return _buildMenu(
        widget.categories,
        widget.menuItems,
        sourceLabel: 'Demo menu · sample products and prices',
      );
    }
    return FutureBuilder<_RestaurantCatalog>(
      future: catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AnimatedContentSwitcher(
            child: Scaffold(
              key: const ValueKey('restaurant-menu-loading'),
              backgroundColor: _page,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildRestaurantHeader(context),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (var index = 0; index < 3; index++) ...[
                            const SkeletonBox(height: 180, radius: 16),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: const CartSummaryBar(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _buildCatalogError(snapshot.error);
        }
        return _buildMenu(
          snapshot.data!.categories,
          snapshot.data!.items,
          sourceLabel: 'Backend catalog',
        );
      },
    );
  }

  Widget _buildCatalogError(Object? error) {
    if (isOfflineApiError(error)) {
      return Scaffold(
        backgroundColor: _page,
        body: SafeArea(
          child: Column(
            children: [
              _buildRestaurantHeader(context),
              Expanded(
                child: Center(
                  child: OfflineErrorState(onRetry: _refreshCatalog),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const CartSummaryBar(),
      );
    }
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(context),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load the backend menu.',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          final api = CustomerApi.instance;
                          setState(() {
                            _catalogFuture = _loadCatalog(
                              api,
                              query: _productQuery.isEmpty
                                  ? null
                                  : _productQuery,
                            );
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry menu'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _buildMenu(
    List<MenuCategory> categories,
    List<MenuItem> items, {
    required String sourceLabel,
  }) {
    final query = _productQuery.toLowerCase();
    final restaurantItems = items
        .where(
          (item) =>
              item.restaurantId == widget.restaurant.id &&
              (query.isEmpty ||
                  item.name.toLowerCase().contains(query) ||
                  item.description.toLowerCase().contains(query)),
        )
        .toList();
    final filteredItems = restaurantItems.where((item) {
      return switch (_selectedFilter) {
        _DietaryFilter.all => true,
        _DietaryFilter.veg => item.dietaryInfoAvailable && item.isVeg,
        _DietaryFilter.nonVeg => item.dietaryInfoAvailable && !item.isVeg,
      };
    }).toList();
    final menuCategories = categories
        .where(
          (category) =>
              filteredItems.any((item) => item.categoryId == category.id),
        )
        .toList();

    final menuScrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildRestaurantHeader(context)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
            child: Text(
              sourceLabel,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildMenuHeading(filteredItems.length)),
        SliverToBoxAdapter(child: _buildProductSearch()),
        if (items.any((item) => !item.dietaryInfoAvailable))
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                'Dietary details are not provided by the catalog.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ),
          ),
        SliverToBoxAdapter(child: _buildDietaryFilters()),
        for (final category in menuCategories)
          SliverToBoxAdapter(
            child: _buildCategorySection(
              category,
              filteredItems
                  .where((item) => item.categoryId == category.id)
                  .toList(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: sourceLabel == 'Backend catalog'
            ? RefreshIndicator(
                color: const Color(0xFF016034),
                onRefresh: _refreshCatalog,
                child: menuScrollView,
              )
            : menuScrollView,
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _buildProductSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE5E9E3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: _muted, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                key: const ValueKey('restaurant-product-search'),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  final query = value.trim();
                  final api = CustomerApi.instance;
                  setState(() {
                    _productQuery = query;
                    _catalogFuture =
                        api.isConfigured && widget.restaurant.isBackendData
                        ? _loadCatalog(api, query: query.isEmpty ? null : query)
                        : null;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search dishes...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(color: _ink, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 212,
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
                right: 12,
                child: _HeaderAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share restaurant',
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
                      widget.restaurant.name,
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
                  if (!widget.restaurant.isBackendData) ...[
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
                            widget.restaurant.rating.toStringAsFixed(1),
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
                ],
              ),
              const SizedBox(height: 5),
              Text(
                widget.restaurant.cuisine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoTag(
                    icon: Icons.schedule_rounded,
                    label: widget.restaurant.deliveryTime,
                  ),
                  const SizedBox(width: 13),
                  _InfoTag(
                    icon: Icons.location_on_outlined,
                    label:
                        '${widget.restaurant.distance} · ${widget.restaurant.location}',
                  ),
                  const Spacer(),
                  _OpenStatus(status: widget.restaurant.status),
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
    final imageUrl = widget.restaurant.coverImageUrl;
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
          colors: [Color(0xFF80604A), Color(0xFF354D40)],
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
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Icon(
            Icons.restaurant_rounded,
            size: 68,
            color: Colors.white.withValues(alpha: 0.8),
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

  Widget _buildDietaryFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          _dietaryFilterChip('All', _DietaryFilter.all),
          const SizedBox(width: 8),
          _dietaryFilterChip(
            'Veg',
            _DietaryFilter.veg,
            dotColor: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 8),
          _dietaryFilterChip(
            'Non-Veg',
            _DietaryFilter.nonVeg,
            dotColor: const Color(0xFFB63E32),
          ),
        ],
      ),
    );
  }

  Widget _dietaryFilterChip(
    String label,
    _DietaryFilter filter, {
    Color? dotColor,
  }) {
    final selected = _selectedFilter == filter;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF5EA) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF9FC6A2) : const Color(0xFFE5E9E3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF245E39) : _ink,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(MenuCategory category, List<MenuItem> items) {
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
                  '${items.length} items',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (items.every((item) => item.isBackendProduct))
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                mainAxisExtent: 288,
              ),
              itemBuilder: (context, index) => StoreProductCard(
                key: ValueKey('backend-restaurant-product-${items[index].id}'),
                product: _asStoreProduct(items[index]),
                placeholderIndex: index,
                storeName: widget.restaurant.name,
                relatedProducts: items
                    .where(
                      (related) =>
                          related.restaurantId == items[index].restaurantId &&
                          related.categoryId == items[index].categoryId &&
                          related.id != items[index].id,
                    )
                    .map(_asStoreProduct)
                    .toList(growable: false),
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _MenuItemCard(
                item: items[index],
                restaurantName: widget.restaurant.name,
                relatedItems: items
                    .where(
                      (related) =>
                          related.restaurantId == items[index].restaurantId &&
                          related.categoryId == items[index].categoryId &&
                          related.id != items[index].id,
                    )
                    .toList(),
              ),
              if (index < items.length - 1)
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

  StoreProduct _asStoreProduct(MenuItem item) => StoreProduct(
    id: item.id,
    storeId: item.restaurantId,
    categoryId: item.categoryId,
    name: item.name,
    brand: item.brand ?? '',
    description: item.description,
    packSize: item.packSize ?? '',
    price: item.price,
    mrp: item.mrp ?? item.price,
    discount: item.discount,
    rating: item.rating ?? -1,
    available: item.available,
    serviceType: 'restaurant',
    imageUrl: item.imageUrl,
    badge: item.badge,
    isBackendData: item.isBackendProduct,
  );
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

  final RestaurantStatus status;

  @override
  Widget build(BuildContext context) {
    final isOpen = status == RestaurantStatus.open;
    final label = switch (status) {
      RestaurantStatus.open => 'Open',
      RestaurantStatus.closed => 'Closed',
      RestaurantStatus.unavailable => 'Unavailable',
      RestaurantStatus.unknown => 'Hours not provided',
    };
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
          label,
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

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.restaurantName,
    required this.relatedItems,
  });

  final MenuItem item;
  final String restaurantName;
  final List<MenuItem> relatedItems;

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.dietaryInfoAvailable)
                          Padding(
                            padding: const EdgeInsets.only(top: 5, right: 6),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: item.isVeg
                                    ? AppTheme.primaryGreen
                                    : const Color(0xFFB63E32),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '₹${item.price.toStringAsFixed(item.price % 1 == 0 ? 0 : 2)}',
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
                    child: _buildFoodImage(),
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
                        serviceType: 'restaurant',
                        merchantId: item.restaurantId,
                        merchantName: restaurantName,
                        categoryId: item.categoryId,
                        name: item.name,
                        description: item.description,
                        imageUrl: item.imageUrl,
                        priceInPaise: (item.price * 100).round(),
                        available: item.available,
                        icon: Icons.restaurant_rounded,
                        isVegetarian: item.dietaryInfoAvailable
                            ? item.isVeg
                            : null,
                        isBackendProduct: item.isBackendProduct,
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
                    serviceType: 'restaurant',
                    merchantId: item.restaurantId,
                    categoryId: item.categoryId,
                    name: item.name,
                    description: item.description,
                    priceInPaise: (item.price * 100).round(),
                    imageUrl: item.imageUrl,
                    icon: Icons.restaurant_rounded,
                    backendCatalogItem: item.isBackendProduct,
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

  Widget _buildFoodImage() {
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
            serviceType: 'restaurant',
            merchantId: item.restaurantId,
            merchantName: restaurantName,
            categoryId: item.categoryId,
            name: item.name,
            description: item.description,
            imageUrl: item.imageUrl,
            priceInPaise: (item.price * 100).round(),
            available: item.available,
            icon: Icons.restaurant_rounded,
            isVegetarian: item.dietaryInfoAvailable ? item.isVeg : null,
            isBackendProduct: item.isBackendProduct,
            relatedProducts: relatedItems
                .map(
                  (related) => ProductDetailsProduct(
                    id: related.id,
                    serviceType: 'restaurant',
                    merchantId: related.restaurantId,
                    merchantName: restaurantName,
                    categoryId: related.categoryId,
                    name: related.name,
                    description: related.description,
                    imageUrl: related.imageUrl,
                    priceInPaise: (related.price * 100).round(),
                    available: related.available,
                    icon: Icons.restaurant_rounded,
                    isVegetarian: related.dietaryInfoAvailable
                        ? related.isVeg
                        : null,
                    isBackendProduct: related.isBackendProduct,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final colors = switch (item.foodType) {
      FoodType.vegetarian => const [Color(0xFFE2EEDB), Color(0xFFBDCFB3)],
      FoodType.nonVegetarian => const [Color(0xFFF0DFD2), Color(0xFFD3B39B)],
      FoodType.unknown => const [Color(0xFFE8EAE7), Color(0xFFBFC7BF)],
    };
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(
        Icons.restaurant_rounded,
        color: Colors.white.withValues(alpha: 0.9),
        size: 40,
      ),
    );
  }
}
