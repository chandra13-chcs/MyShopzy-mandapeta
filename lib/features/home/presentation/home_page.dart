import 'package:flutter/material.dart';

import '../../bakery/presentation/bakery_page.dart';
import '../../../app/theme/app_theme.dart';
import '../../cart/presentation/cart_access_button.dart';
import '../../cart/presentation/cart_page.dart';
import '../../../shared/presentation/dietary_badge.dart';
import '../../../shared/presentation/press_scale_feedback.dart';
import 'free_delivery_progress_strip.dart';
import '../../local_stores/presentation/local_stores_page.dart';
import '../../local_stores/presentation/local_store_catalog_page.dart';
import '../../local_stores/data/local_store_session.dart';
import '../../meat/presentation/meat_page.dart';
import '../../parcel/presentation/parcel_page.dart';
import '../../restaurants/presentation/restaurants_page.dart';
import '../../vegetables_fruits/presentation/vegetables_fruits_page.dart';
import '../../categories/presentation/categories_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../orders/presentation/orders_page.dart';
import '../../product_details/data/recently_viewed_store.dart';
import '../../product_details/presentation/product_availability_badge.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../../recently_viewed/presentation/recently_viewed_page.dart';
import '../../recently_viewed/presentation/recently_viewed_product_card.dart';
import '../../restaurants/presentation/restaurant_menu_page.dart';
import '../../search/models/search_result.dart';
import '../../search/presentation/search_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;
  static const _recentlyViewedViewAllThreshold = 4;

  static final _discoverySearchResults = _buildSearchDiscoveryResults();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(context),
                  const SizedBox(height: 10),
                  const FreeDeliveryProgressStrip(),
                  const SizedBox(height: 18),
                  _buildSearchBar(context),
                  const SizedBox(height: 22),
                  _buildServiceGrid(),
                  const SizedBox(height: 22),
                  _buildPromotions(),
                  AnimatedBuilder(
                    animation: RecentlyViewedStore.instance,
                    builder: (context, child) {
                      if (RecentlyViewedStore.instance.products.isEmpty) {
                        return const SizedBox(height: 24);
                      }
                      return Column(
                        children: [
                          _buildRecentlyViewedSection(
                            context,
                            RecentlyViewedStore.instance.products,
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  for (final section in _restaurantDiscoverySections) ...[
                    _buildRestaurantDiscoverySection(context, section),
                    const SizedBox(height: 22),
                  ],
                  _buildParcelAdvertisement(context),
                  const SizedBox(height: 24),
                  for (final section in _groceryDiscoverySections) ...[
                    _buildGroceryDiscoverySection(context, section),
                    const SizedBox(height: 20),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: _green, size: 20),
                  const SizedBox(width: 5),
                  const Text(
                    '30 mins',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'delivery',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: _green,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text(
                      'Mandapeta, Andhra Pradesh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _muted,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppTheme.primaryGreen,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ProfilePage(),
              ),
            ),
            customBorder: const CircleBorder(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8EBE6)),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.brandYellow,
                size: 23,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SearchPage(
            additionalResults: _discoverySearchResults,
            destinationBuilder: _searchDestinationFor,
          ),
        ),
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E9E3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: _muted, size: 23),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Search restaurants, groceries, products...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _searchDestinationFor(SearchResult result) {
    switch (result.type) {
      case SearchResultType.homeRestaurant:
        final product = _restaurantDiscoverySections
            .expand((section) => section.products)
            .firstWhere((item) => item.restaurantId == result.merchantId);
        return _restaurantDiscoveryMenu(product);
      case SearchResultType.homeRestaurantProduct:
        final product = _restaurantDiscoverySections
            .expand((section) => section.products)
            .firstWhere((item) => item.productId == result.id);
        return ProductDetailsPage(
          product: _restaurantDiscoveryProductDetails(product),
        );
      case SearchResultType.homeStoreProduct:
        final product = _groceryDiscoverySections
            .expand((section) => section.products)
            .firstWhere((item) => item.productId == result.id);
        return ProductDetailsPage(
          product: _groceryDiscoveryProductDetails(product),
        );
      case SearchResultType.homeStore:
        final product = _groceryDiscoverySections
            .expand((section) => section.products)
            .firstWhere((item) => item.storeId == result.merchantId);
        return _groceryDiscoveryCatalog(product);
      case SearchResultType.restaurant:
      case SearchResultType.restaurantProduct:
      case SearchResultType.bakery:
      case SearchResultType.bakeryProduct:
      case SearchResultType.localStore:
      case SearchResultType.storeProduct:
      case SearchResultType.meatCategory:
      case SearchResultType.meatProduct:
      case SearchResultType.produceCategory:
      case SearchResultType.produceProduct:
        return null;
    }
  }

  static List<SearchResult> _buildSearchDiscoveryResults() {
    final results = <SearchResult>[];
    final seenRestaurantIds = <String>{};
    for (final section in _restaurantDiscoverySections) {
      for (final product in section.products) {
        final category = _restaurantDiscoveryCategories.firstWhere(
          (item) => item.id == product.categoryId,
        );
        if (seenRestaurantIds.add(product.restaurantId)) {
          results.add(
            SearchResult(
              id: 'home-restaurant:${product.restaurantId}',
              type: SearchResultType.homeRestaurant,
              displayName: product.restaurantName,
              subtitle: 'Restaurant · ${section.title}',
              merchantId: product.restaurantId,
              merchantName: product.restaurantName,
              searchableText: '${product.restaurantName} ${section.title}',
            ),
          );
        }
        results.add(
          SearchResult(
            id: product.productId,
            type: SearchResultType.homeRestaurantProduct,
            displayName: product.productName,
            subtitle: '${product.restaurantName} · ${category.name}',
            price: product.price,
            merchantId: product.restaurantId,
            merchantName: product.restaurantName,
            categoryId: product.categoryId,
            searchableText:
                '${product.productName} ${product.description} ${product.restaurantName} ${category.name} ${section.title}',
          ),
        );
      }
    }
    final seenStoreIds = <String>{};
    for (final section in _groceryDiscoverySections) {
      for (final product in section.products) {
        final category = _groceryDiscoveryCategories.firstWhere(
          (item) => item.id == product.categoryId,
        );
        if (seenStoreIds.add(product.storeId)) {
          results.add(
            SearchResult(
              id: 'home-store:${product.storeId}',
              type: SearchResultType.homeStore,
              displayName: product.storeName,
              subtitle: 'Local store · Mandapeta',
              merchantId: product.storeId,
              merchantName: product.storeName,
              searchableText: '${product.storeName} Mandapeta',
            ),
          );
        }
        results.add(
          SearchResult(
            id: product.productId,
            type: SearchResultType.homeStoreProduct,
            displayName: product.productName,
            subtitle: '${product.storeName} · ${category.name}',
            price: product.price,
            merchantId: product.storeId,
            merchantName: product.storeName,
            categoryId: product.categoryId,
            searchableText:
                '${product.productName} ${product.brand} ${product.description} ${product.packSize} ${product.storeName} ${category.name} ${section.title}',
          ),
        );
      }
    }
    return List.unmodifiable(results);
  }

  Widget _buildServiceGrid() {
    const services = [
      _Service(
        'Meat Only Chicken',
        'meat_only_chicken',
        'assets/category_tiles/meat_only_chicken.jpg',
      ),
      _Service('Bakery', 'bakery', 'assets/category_tiles/bakery.jpg'),
      _Service('Parcel', 'parcel', 'assets/category_tiles/parcel.jpg'),
      _Service(
        'Local Stores',
        'local_stores',
        'assets/category_tiles/local_stores.jpg',
      ),
      _Service(
        'Fruits & Vegetables',
        'fruits_vegetables',
        'assets/category_tiles/fruits_vegetables.jpg',
      ),
      _Service(
        'Restaurants',
        'restaurants',
        'assets/category_tiles/restaurants.jpg',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 310 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            final onTap = switch (service.key) {
              'restaurants' => () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const RestaurantsPage(),
                ),
              ),
              'bakery' => () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const BakeryPage(),
                ),
              ),
              'meat_only_chicken' => () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => const MeatPage()),
              ),
              'parcel' => () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ParcelPage(),
                ),
              ),
              'local_stores' => () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const LocalStoresPage(),
                ),
              ),
              'fruits_vegetables' => () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const VegetablesFruitsPage(),
                ),
              ),
              _ => null,
            };
            return PressScaleFeedback(
              child: Material(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('home-category-${service.key}'),
                  onTap: onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        service.assetPath,
                        fit: BoxFit.cover,
                        semanticLabel: service.name,
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: IgnorePointer(
                          child: Container(
                            key: ValueKey('home-category-arrow-${service.key}'),
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppTheme.brandYellow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: AppTheme.darkGreen,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPromotions() {
    const promos = [
      _Promotion(
        'Fresh picks',
        'Goodness for every day',
        'UP TO 30% OFF',
        Color(0xFFE0F1D8),
        Color(0xFF397447),
        Icons.spa_rounded,
      ),
      _Promotion(
        'Meal time, sorted',
        'Your favourites are near',
        'FROM ₹99',
        Color(0xFFFFE8D7),
        Color(0xFF9A5633),
        Icons.lunch_dining_rounded,
      ),
      _Promotion(
        'Local love',
        'Shop your neighbourhood',
        'DELIVERED FAST',
        Color(0xFFE5EAF8),
        Color(0xFF4B5C91),
        Icons.store_mall_directory_rounded,
      ),
    ];

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: promos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 11),
        itemBuilder: (context, index) => _buildPromotionCard(promos[index]),
      ),
    );
  }

  Widget _buildPromotionCard(_Promotion promotion) {
    return Container(
      width: 258,
      padding: const EdgeInsets.fromLTRB(15, 13, 12, 11),
      decoration: BoxDecoration(
        color: promotion.background,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  promotion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: promotion.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  promotion.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: promotion.foreground.withValues(alpha: 0.82),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    promotion.offer,
                    style: TextStyle(
                      color: promotion.foreground,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Icon(promotion.icon, color: promotion.foreground, size: 50),
        ],
      ),
    );
  }

  Widget _buildRestaurantDiscoverySection(
    BuildContext context,
    _RestaurantDiscoverySection section,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            section.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final product = section.products[index];
              return _buildRestaurantDiscoveryCard(context, product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyViewedSection(
    BuildContext context,
    List<ProductDetailsProduct> products,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recently Viewed',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (products.length >= _recentlyViewedViewAllThreshold)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const RecentlyViewedPage(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                RecentlyViewedProductCard(product: products[index], width: 138),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantDiscoveryCard(
    BuildContext context,
    _RestaurantDiscoveryProduct product,
  ) {
    return SizedBox(
      width: 96,
      child: PressScaleFeedback(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => ProductDetailsPage(
                  product: _restaurantDiscoveryProductDetails(product),
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFEBEEE9)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: product.imageColor,
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              product.imageIcon,
                              color: _ink.withValues(alpha: 0.68),
                              size: 35,
                            ),
                          ),
                          Positioned(
                            top: 5,
                            left: 4,
                            child: ProductAvailabilityBadge(
                              productId: product.productId,
                              serviceType: 'restaurant',
                              merchantId: product.restaurantId,
                              defaultAvailable: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: _green,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            DietaryBadge(
                              isVegetarian: product.isVeg,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
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

  ProductDetailsProduct _restaurantDiscoveryProductDetails(
    _RestaurantDiscoveryProduct product,
  ) {
    return ProductDetailsProduct(
      id: product.productId,
      serviceType: 'restaurant',
      merchantId: product.restaurantId,
      merchantName: product.restaurantName,
      categoryId: product.categoryId,
      name: product.productName,
      description: product.description,
      priceInPaise: (product.price * 100).round(),
      available: true,
      icon: product.imageIcon,
      isVegetarian: product.isVeg,
    );
  }

  Widget _restaurantDiscoveryMenu(_RestaurantDiscoveryProduct product) {
    final restaurantMenu = _restaurantDiscoverySections
        .expand((section) => section.products)
        .where((item) => item.restaurantId == product.restaurantId)
        .map(
          (item) => MenuItem(
            id: item.productId,
            restaurantId: item.restaurantId,
            categoryId: item.categoryId,
            name: item.productName,
            description: item.description,
            price: item.price,
            foodType: item.isVeg ? FoodType.vegetarian : FoodType.nonVegetarian,
            isVeg: item.isVeg,
            available: true,
          ),
        )
        .toList();
    return RestaurantMenuPage(
      restaurant: product.restaurant,
      categories: _restaurantDiscoveryCategories,
      menuItems: restaurantMenu,
    );
  }

  Widget _buildParcelAdvertisement(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (context) => const ParcelPage()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE5E9E3)),
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF3F8), Color(0xFFF5F8F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFDCE7E9)),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF486B78),
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARCEL · PROMO SLOT',
                      style: TextStyle(
                        color: Color(0xFF64808A),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Send a Parcel',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Temporary banner placeholder',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF486B78),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroceryDiscoverySection(
    BuildContext context,
    _GroceryDiscoverySection section,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(
            section.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: 137,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) =>
                _buildGroceryDiscoveryCard(context, section.products[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildGroceryDiscoveryCard(
    BuildContext context,
    _GroceryDiscoveryProduct product,
  ) {
    return SizedBox(
      width: 84,
      child: PressScaleFeedback(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => ProductDetailsPage(
                  product: _groceryDiscoveryProductDetails(product),
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEBEEE9)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: product.imageColor,
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              product.imageIcon,
                              color: _ink.withValues(alpha: 0.65),
                              size: 33,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 3,
                            child: ProductAvailabilityBadge(
                              productId: product.productId,
                              serviceType: 'local_store',
                              merchantId: product.storeId,
                              defaultAvailable: true,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.packSize,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 8),
                        ),
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

  ProductDetailsProduct _groceryDiscoveryProductDetails(
    _GroceryDiscoveryProduct product,
  ) {
    LocalStoreSession.instance.select(product.store);
    return ProductDetailsProduct(
      id: product.productId,
      serviceType: 'local_store',
      merchantId: product.storeId,
      merchantName: product.storeName,
      categoryId: product.categoryId,
      name: product.productName,
      brand: product.brand,
      description: product.description,
      quantityLabel: product.packSize,
      priceInPaise: (product.price * 100).round(),
      available: true,
      icon: product.imageIcon,
    );
  }

  Widget _groceryDiscoveryCatalog(_GroceryDiscoveryProduct selectedProduct) {
    final storeProducts = _groceryDiscoverySections
        .expand((section) => section.products)
        .where((product) => product.storeId == selectedProduct.storeId)
        .map(
          (product) => StoreProduct(
            id: product.productId,
            storeId: product.storeId,
            categoryId: product.categoryId,
            name: product.productName,
            brand: product.brand,
            description: product.description,
            packSize: product.packSize,
            price: product.price,
            mrp: product.price,
            discount: 0,
            rating: 4.5,
            available: true,
          ),
        )
        .toList();
    final orderedCategories = [
      ..._groceryDiscoveryCategories.where(
        (category) => category.id == selectedProduct.categoryId,
      ),
      ..._groceryDiscoveryCategories.where(
        (category) => category.id != selectedProduct.categoryId,
      ),
    ];

    return LocalStoreCatalogPage(
      store: selectedProduct.store,
      categories: orderedCategories,
      products: storeProducts,
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const CategoriesPage(),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => const CartPage()),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => const OrdersPage()),
            );
          } else if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ProfilePage(),
              ),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.darkGreen,
        selectedItemColor: AppTheme.brandYellow,
        unselectedItemColor: AppTheme.white,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 10,
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
    );
  }
}

const _restaurantDiscoveryCategories = [
  MenuCategory(id: 'biryani', name: 'Biryani'),
  MenuCategory(id: 'snacks', name: 'Snacks'),
  MenuCategory(id: 'party-combos', name: 'Party Combos'),
  MenuCategory(id: 'top-picks', name: 'Top Picks'),
];

// Demo discovery records keep restaurant and product IDs together for a future
// REST-backed source. Names are explicitly demo venues, not partner claims.
const _restaurantDiscoverySections = [
  _RestaurantDiscoverySection(
    title: 'Best in Biryani',
    products: [
      _RestaurantDiscoveryProduct(
        productId: 'demo-chicken-biryani',
        restaurantId: 'demo-biryani-kitchen',
        restaurantName: 'Demo Biryani Kitchen',
        productName: 'Chicken Biryani',
        description: 'Demo chicken biryani with aromatic rice.',
        categoryId: 'biryani',
        price: 249,
        isVeg: false,
        imageColor: Color(0xFFF0DFD2),
        imageIcon: Icons.ramen_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-mutton-biryani',
        restaurantId: 'demo-biryani-kitchen',
        restaurantName: 'Demo Biryani Kitchen',
        productName: 'Mutton Biryani',
        description: 'Demo dum biryani with tender mutton.',
        categoryId: 'biryani',
        price: 329,
        isVeg: false,
        imageColor: Color(0xFFEADBC7),
        imageIcon: Icons.ramen_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-special-chicken-biryani',
        restaurantId: 'demo-biryani-kitchen',
        restaurantName: 'Demo Biryani Kitchen',
        productName: 'Special Chicken Biryani',
        description: 'A demo special chicken biryani.',
        categoryId: 'biryani',
        price: 289,
        isVeg: false,
        imageColor: Color(0xFFF2E3D4),
        imageIcon: Icons.ramen_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-family-biryani',
        restaurantId: 'demo-biryani-kitchen',
        restaurantName: 'Demo Biryani Kitchen',
        productName: 'Family Biryani',
        description: 'A shareable demo biryani portion.',
        categoryId: 'biryani',
        price: 599,
        isVeg: false,
        imageColor: Color(0xFFE8D8C3),
        imageIcon: Icons.ramen_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-veg-dum-biryani',
        restaurantId: 'demo-biryani-kitchen',
        restaurantName: 'Demo Biryani Kitchen',
        productName: 'Veg Dum Biryani',
        description: 'Demo basmati biryani with vegetables.',
        categoryId: 'biryani',
        price: 189,
        isVeg: true,
        imageColor: Color(0xFFE2EEDB),
        imageIcon: Icons.rice_bowl_rounded,
      ),
    ],
  ),
  _RestaurantDiscoverySection(
    title: 'Snacks',
    products: [
      _RestaurantDiscoveryProduct(
        productId: 'demo-french-fries',
        restaurantId: 'demo-snack-kitchen',
        restaurantName: 'Demo Snack Kitchen',
        productName: 'French Fries',
        description: 'Crispy demo fries.',
        categoryId: 'snacks',
        price: 119,
        isVeg: true,
        imageColor: Color(0xFFF7EBC9),
        imageIcon: Icons.fastfood_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-chicken-65',
        restaurantId: 'demo-snack-kitchen',
        restaurantName: 'Demo Snack Kitchen',
        productName: 'Chicken 65',
        description: 'Demo spicy fried chicken bites.',
        categoryId: 'snacks',
        price: 229,
        isVeg: false,
        imageColor: Color(0xFFF0DFD2),
        imageIcon: Icons.restaurant_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-samosa',
        restaurantId: 'demo-snack-kitchen',
        restaurantName: 'Demo Snack Kitchen',
        productName: 'Samosa',
        description: 'Demo crisp potato samosa.',
        categoryId: 'snacks',
        price: 35,
        isVeg: true,
        imageColor: Color(0xFFF5E6C9),
        imageIcon: Icons.local_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-chicken-wings',
        restaurantId: 'demo-snack-kitchen',
        restaurantName: 'Demo Snack Kitchen',
        productName: 'Chicken Wings',
        description: 'Demo saucy chicken wings.',
        categoryId: 'snacks',
        price: 249,
        isVeg: false,
        imageColor: Color(0xFFEBD7C9),
        imageIcon: Icons.restaurant_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-paneer-pakora',
        restaurantId: 'demo-snack-kitchen',
        restaurantName: 'Demo Snack Kitchen',
        productName: 'Paneer Pakora',
        description: 'Demo paneer fritters with spices.',
        categoryId: 'snacks',
        price: 159,
        isVeg: true,
        imageColor: Color(0xFFE2EEDB),
        imageIcon: Icons.local_dining_rounded,
      ),
    ],
  ),
  _RestaurantDiscoverySection(
    title: 'Party Mood',
    products: [
      _RestaurantDiscoveryProduct(
        productId: 'demo-margherita-pizza',
        restaurantId: 'demo-party-kitchen',
        restaurantName: 'Demo Party Kitchen',
        productName: 'Margherita Pizza',
        description: 'Demo cheesy vegetarian pizza.',
        categoryId: 'party-combos',
        price: 299,
        isVeg: true,
        imageColor: Color(0xFFE2EEDB),
        imageIcon: Icons.local_pizza_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-burger-combo',
        restaurantId: 'demo-party-kitchen',
        restaurantName: 'Demo Party Kitchen',
        productName: 'Burger Combo',
        description: 'Demo burger with sides and drink.',
        categoryId: 'party-combos',
        price: 249,
        isVeg: false,
        imageColor: Color(0xFFF0DFD2),
        imageIcon: Icons.lunch_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-fries-combo',
        restaurantId: 'demo-party-kitchen',
        restaurantName: 'Demo Party Kitchen',
        productName: 'French Fries Combo',
        description: 'Demo party-size fries combo.',
        categoryId: 'party-combos',
        price: 199,
        isVeg: true,
        imageColor: Color(0xFFF7EBC9),
        imageIcon: Icons.fastfood_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-family-pizza',
        restaurantId: 'demo-party-kitchen',
        restaurantName: 'Demo Party Kitchen',
        productName: 'Family Pizza',
        description: 'Large demo pizza for sharing.',
        categoryId: 'party-combos',
        price: 649,
        isVeg: true,
        imageColor: Color(0xFFEDE4CF),
        imageIcon: Icons.local_pizza_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-party-platter',
        restaurantId: 'demo-party-kitchen',
        restaurantName: 'Demo Party Kitchen',
        productName: 'Party Platter',
        description: 'Demo sharing platter with mixed bites.',
        categoryId: 'party-combos',
        price: 499,
        isVeg: false,
        imageColor: Color(0xFFEBD7C9),
        imageIcon: Icons.dinner_dining_rounded,
      ),
    ],
  ),
  _RestaurantDiscoverySection(
    title: 'Top Picks',
    products: [
      _RestaurantDiscoveryProduct(
        productId: 'demo-paneer-tikka',
        restaurantId: 'demo-top-picks-kitchen',
        restaurantName: 'Demo Top Picks Kitchen',
        productName: 'Paneer Tikka',
        description: 'Demo char-grilled paneer tikka.',
        categoryId: 'top-picks',
        price: 219,
        isVeg: true,
        imageColor: Color(0xFFE2EEDB),
        imageIcon: Icons.restaurant_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-chicken-burger',
        restaurantId: 'demo-top-picks-kitchen',
        restaurantName: 'Demo Top Picks Kitchen',
        productName: 'Chicken Burger',
        description: 'Demo grilled chicken burger.',
        categoryId: 'top-picks',
        price: 189,
        isVeg: false,
        imageColor: Color(0xFFF0DFD2),
        imageIcon: Icons.lunch_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-veg-noodles',
        restaurantId: 'demo-top-picks-kitchen',
        restaurantName: 'Demo Top Picks Kitchen',
        productName: 'Veg Noodles',
        description: 'Demo wok-tossed vegetable noodles.',
        categoryId: 'top-picks',
        price: 169,
        isVeg: true,
        imageColor: Color(0xFFE3E9D8),
        imageIcon: Icons.ramen_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-chicken-roll',
        restaurantId: 'demo-top-picks-kitchen',
        restaurantName: 'Demo Top Picks Kitchen',
        productName: 'Chicken Roll',
        description: 'Demo chicken roll with house spices.',
        categoryId: 'top-picks',
        price: 149,
        isVeg: false,
        imageColor: Color(0xFFEBD7C9),
        imageIcon: Icons.lunch_dining_rounded,
      ),
      _RestaurantDiscoveryProduct(
        productId: 'demo-veg-meals',
        restaurantId: 'demo-top-picks-kitchen',
        restaurantName: 'Demo Top Picks Kitchen',
        productName: 'Veg Meals',
        description: 'Demo homestyle vegetarian meal.',
        categoryId: 'top-picks',
        price: 189,
        isVeg: true,
        imageColor: Color(0xFFF7EBC9),
        imageIcon: Icons.rice_bowl_rounded,
      ),
    ],
  ),
];

const _groceryDiscoveryCategories = [
  CommonCategory(
    id: 'cooking-oil',
    name: 'Cooking Oils',
    icon: Icons.water_drop_rounded,
  ),
  CommonCategory(
    id: 'soft-drinks',
    name: 'Soft Drinks',
    icon: Icons.local_drink_rounded,
  ),
  CommonCategory(id: 'biscuits', name: 'Biscuits', icon: Icons.cookie_rounded),
  CommonCategory(
    id: 'personal-care',
    name: 'Personal Care',
    icon: Icons.spa_rounded,
  ),
  CommonCategory(id: 'snacks', name: 'Snacks', icon: Icons.fastfood_rounded),
  CommonCategory(
    id: 'chocolates',
    name: 'Chocolates',
    icon: Icons.cake_rounded,
  ),
  CommonCategory(
    id: 'noodles',
    name: 'Noodles',
    icon: Icons.ramen_dining_rounded,
  ),
  CommonCategory(
    id: 'ice-creams',
    name: 'Ice Creams',
    icon: Icons.icecream_rounded,
  ),
  CommonCategory(
    id: 'dairy',
    name: 'Dairy & Milk',
    icon: Icons.icecream_rounded,
  ),
  CommonCategory(
    id: 'spices',
    name: 'Spices & Masalas',
    icon: Icons.local_fire_department_rounded,
  ),
];

const _groceryDiscoverySections = [
  _GroceryDiscoverySection('Cooking Oils', [
    _GroceryDiscoveryProduct(
      'home-oil-sunflower',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Sunflower Oil',
      'Fortune',
      '1 L',
      'Refined sunflower cooking oil',
      'cooking-oil',
      145,
      Color(0xFFF4EBCB),
      Icons.water_drop_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-oil-groundnut',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Groundnut Oil',
      'Freedom',
      '1 L',
      'Filtered groundnut cooking oil',
      'cooking-oil',
      188,
      Color(0xFFF1E5C7),
      Icons.water_drop_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-oil-mustard',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Mustard Oil',
      'Emami Healthy & Tasty',
      '1 L',
      'Mustard oil for everyday cooking',
      'cooking-oil',
      172,
      Color(0xFFF2E7CC),
      Icons.water_drop_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-oil-ricebran',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Rice Bran Oil',
      'Saffola',
      '1 L',
      'Rice bran cooking oil',
      'cooking-oil',
      169,
      Color(0xFFEFE6D2),
      Icons.water_drop_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-oil-coconut',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Coconut Oil',
      'Parachute',
      '500 ml',
      'Coconut oil for kitchen use',
      'cooking-oil',
      124,
      Color(0xFFF5EFD9),
      Icons.water_drop_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Soft Drinks', [
    _GroceryDiscoveryProduct(
      'home-drink-cola',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Cola',
      'Coca-Cola',
      '750 ml',
      'Chilled cola soft drink',
      'soft-drinks',
      40,
      Color(0xFFF0DFD2),
      Icons.local_drink_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-drink-lemon',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Lemon Drink',
      'Sprite',
      '750 ml',
      'Refreshing lemon-lime drink',
      'soft-drinks',
      40,
      Color(0xFFE4EED9),
      Icons.local_drink_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-drink-orange',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Orange Drink',
      'Fanta',
      '750 ml',
      'Orange flavoured soft drink',
      'soft-drinks',
      40,
      Color(0xFFF5E5CA),
      Icons.local_drink_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-drink-thumsup',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Thums Up',
      'Thums Up',
      '750 ml',
      'Strong cola soft drink',
      'soft-drinks',
      40,
      Color(0xFFE8D9D5),
      Icons.local_drink_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-drink-limca',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Limca',
      'Limca',
      '750 ml',
      'Lime flavoured sparkling drink',
      'soft-drinks',
      40,
      Color(0xFFE7EED8),
      Icons.local_drink_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Biscuits', [
    _GroceryDiscoveryProduct(
      'home-biscuit-marie',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Marie Gold',
      'Britannia',
      '250 g',
      'Light crisp tea-time biscuits',
      'biscuits',
      38,
      Color(0xFFF2E5D5),
      Icons.cookie_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-biscuit-goodday',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Good Day Butter',
      'Britannia',
      '200 g',
      'Crunchy butter cookies',
      'biscuits',
      38,
      Color(0xFFEBDDD2),
      Icons.cookie_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-biscuit-darkfantasy',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Dark Fantasy',
      'Sunfeast',
      '300 g',
      'Chocolate-filled cookies',
      'biscuits',
      99,
      Color(0xFFE9DAD6),
      Icons.cookie_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-biscuit-glucose',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Glucose Biscuits',
      'Parle-G',
      '250 g',
      'Classic glucose biscuits',
      'biscuits',
      25,
      Color(0xFFF2E8CF),
      Icons.cookie_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-biscuit-oreo',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Oreo Original',
      'Oreo',
      '120 g',
      'Chocolate sandwich biscuits',
      'biscuits',
      30,
      Color(0xFFE3E5EC),
      Icons.cookie_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Personal Care', [
    _GroceryDiscoveryProduct(
      'home-care-soap',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Bathing Soap',
      'Dove',
      '100 g',
      'Moisturising bathing bar',
      'personal-care',
      58,
      Color(0xFFE4EAF0),
      Icons.spa_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-care-shampoo',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Daily Shampoo',
      'Clinic Plus',
      '180 ml',
      'Everyday hair shampoo',
      'personal-care',
      112,
      Color(0xFFE4EEDC),
      Icons.spa_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-care-toothpaste',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Toothpaste',
      'Colgate',
      '150 g',
      'Mint toothpaste',
      'personal-care',
      96,
      Color(0xFFE1EAF1),
      Icons.cleaning_services_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-care-facewash',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Face Wash',
      'Himalaya',
      '100 ml',
      'Gentle daily face wash',
      'personal-care',
      145,
      Color(0xFFE2EEDB),
      Icons.spa_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-care-lotion',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Body Lotion',
      'Vaseline',
      '200 ml',
      'Daily moisturising lotion',
      'personal-care',
      165,
      Color(0xFFF0E8D7),
      Icons.spa_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Snacks', [
    _GroceryDiscoveryProduct(
      'home-snack-potato-chips',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Potato Chips',
      'Lay’s',
      '52 g',
      'Crispy salted potato chips',
      'snacks',
      20,
      Color(0xFFF2E5D5),
      Icons.fastfood_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-snack-mixture',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Spicy Mixture',
      'Haldiram’s',
      '200 g',
      'Crunchy savoury snack mix',
      'snacks',
      78,
      Color(0xFFF0E3CF),
      Icons.fastfood_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-snack-namkeen',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Aloo Bhujia',
      'Haldiram’s',
      '200 g',
      'Crispy spiced potato snack',
      'snacks',
      72,
      Color(0xFFF4E5CC),
      Icons.fastfood_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-snack-popcorn',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Cheese Popcorn',
      'Act II',
      '40 g',
      'Ready-to-eat cheese popcorn',
      'snacks',
      30,
      Color(0xFFF2EBCF),
      Icons.fastfood_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-snack-kurkure',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Masala Munch',
      'Kurkure',
      '75 g',
      'Crunchy masala snack',
      'snacks',
      20,
      Color(0xFFF0DFD2),
      Icons.fastfood_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Chocolates', [
    _GroceryDiscoveryProduct(
      'home-choc-dairy-milk',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Dairy Milk',
      'Cadbury',
      '80 g',
      'Smooth milk chocolate',
      'chocolates',
      50,
      Color(0xFFE9DAD6),
      Icons.cake_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-choc-kitkat',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'KitKat',
      'Nestlé',
      '42 g',
      'Crispy wafer chocolate',
      'chocolates',
      30,
      Color(0xFFEBDDD2),
      Icons.cake_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-choc-five-star',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      '5 Star',
      'Cadbury',
      '40 g',
      'Caramel chocolate bar',
      'chocolates',
      20,
      Color(0xFFF0E2CE),
      Icons.cake_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-choc-munch',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Munch',
      'Nestlé',
      '38 g',
      'Crunchy wafer chocolate',
      'chocolates',
      20,
      Color(0xFFE7E9DB),
      Icons.cake_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-choc-perk',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Perk',
      'Cadbury',
      '34 g',
      'Light crispy wafer chocolate',
      'chocolates',
      20,
      Color(0xFFE4EAF0),
      Icons.cake_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Noodles', [
    _GroceryDiscoveryProduct(
      'home-noodle-maggi',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Masala Noodles',
      'Maggi',
      '70 g',
      'Instant masala noodles',
      'noodles',
      14,
      Color(0xFFF2E5D5),
      Icons.ramen_dining_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-noodle-yippee',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Magic Masala',
      'Sunfeast YiPPee!',
      '70 g',
      'Instant noodles with masala',
      'noodles',
      14,
      Color(0xFFF0E3CF),
      Icons.ramen_dining_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-noodle-waiwai',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Wai Wai Noodles',
      'Wai Wai',
      '75 g',
      'Crunchy ready-to-eat noodle snack',
      'noodles',
      20,
      Color(0xFFE7E9DB),
      Icons.ramen_dining_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-noodle-topramen',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Top Ramen',
      'Nissin',
      '70 g',
      'Savoury masala instant noodles',
      'noodles',
      15,
      Color(0xFFE4EAF0),
      Icons.ramen_dining_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-noodle-ching',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Hakka Noodles',
      'Ching’s Secret',
      '150 g',
      'Everyday hakka noodles',
      'noodles',
      35,
      Color(0xFFE2EEDB),
      Icons.ramen_dining_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Ice Creams', [
    _GroceryDiscoveryProduct(
      'home-ice-vanilla',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Vanilla Tub',
      'Amul',
      '500 ml',
      'Classic vanilla ice cream',
      'ice-creams',
      125,
      Color(0xFFF0EADB),
      Icons.icecream_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-ice-chocolate',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Chocolate Tub',
      'Amul',
      '500 ml',
      'Chocolate ice cream tub',
      'ice-creams',
      145,
      Color(0xFFE9DAD6),
      Icons.icecream_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-ice-butter-scotch',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Butterscotch Tub',
      'Vadilal',
      '500 ml',
      'Butterscotch flavoured ice cream',
      'ice-creams',
      165,
      Color(0xFFF2E5D5),
      Icons.icecream_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-ice-cone',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Choco Cone',
      'Kwality Wall’s',
      '1 pc',
      'Chocolate topped ice cream cone',
      'ice-creams',
      40,
      Color(0xFFE4EAF0),
      Icons.icecream_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-ice-kulfi',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Malai Kulfi',
      'Amul',
      '1 pc',
      'Traditional malai kulfi',
      'ice-creams',
      35,
      Color(0xFFE7EED9),
      Icons.icecream_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Dairy & Milk', [
    _GroceryDiscoveryProduct(
      'home-dairy-milk',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Toned Milk',
      'Amul',
      '500 ml',
      'Pasteurised toned milk',
      'dairy',
      29,
      Color(0xFFE4EAF0),
      Icons.local_drink_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-dairy-curd',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Fresh Curd',
      'Amul',
      '400 g',
      'Thick set curd',
      'dairy',
      36,
      Color(0xFFF0EADB),
      Icons.icecream_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-dairy-butter',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Butter',
      'Amul',
      '100 g',
      'Salted table butter',
      'dairy',
      58,
      Color(0xFFF4EBCB),
      Icons.icecream_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-dairy-paneer',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Fresh Paneer',
      'Amul',
      '200 g',
      'Soft fresh paneer cubes',
      'dairy',
      92,
      Color(0xFFE2EEDB),
      Icons.icecream_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-dairy-cheese',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Cheese Slices',
      'Amul',
      '200 g',
      'Processed cheese slices',
      'dairy',
      125,
      Color(0xFFF2E5D5),
      Icons.icecream_rounded,
    ),
  ]),
  _GroceryDiscoverySection('Spices & Masalas', [
    _GroceryDiscoveryProduct(
      'home-spice-chilli',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Red Chilli Powder',
      'Everest',
      '100 g',
      'Ground red chilli powder',
      'spices',
      48,
      Color(0xFFF0DFD2),
      Icons.local_fire_department_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-spice-turmeric',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Turmeric Powder',
      'Aashirvaad',
      '100 g',
      'Ground turmeric powder',
      'spices',
      36,
      Color(0xFFF4EBCB),
      Icons.local_fire_department_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-spice-garam',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Garam Masala',
      'MDH',
      '100 g',
      'Aromatic blended spice mix',
      'spices',
      82,
      Color(0xFFEBDDD2),
      Icons.local_fire_department_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-spice-cumin',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Cumin Seeds',
      'Tata Sampann',
      '100 g',
      'Whole cumin seeds',
      'spices',
      54,
      Color(0xFFE7EED9),
      Icons.local_fire_department_rounded,
    ),
    _GroceryDiscoveryProduct(
      'home-spice-sambar',
      'sri-lakshmi-general-store',
      'Sri Lakshmi General Store',
      'Sambar Masala',
      'Everest',
      '100 g',
      'South Indian sambar spice blend',
      'spices',
      62,
      Color(0xFFF0E3CF),
      Icons.local_fire_department_rounded,
    ),
  ]),
];

class _Service {
  const _Service(this.name, this.key, this.assetPath);

  final String name;
  final String key;
  final String assetPath;
}

class _RestaurantDiscoverySection {
  const _RestaurantDiscoverySection({
    required this.title,
    required this.products,
  });

  final String title;
  final List<_RestaurantDiscoveryProduct> products;
}

class _RestaurantDiscoveryProduct {
  const _RestaurantDiscoveryProduct({
    required this.productId,
    required this.restaurantId,
    required this.restaurantName,
    required this.productName,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.isVeg,
    required this.imageColor,
    required this.imageIcon,
  });

  final String productId;
  final String restaurantId;
  final String restaurantName;
  final String productName;
  final String description;
  final String categoryId;
  final double price;
  final bool isVeg;
  final Color imageColor;
  final IconData imageIcon;

  Restaurant get restaurant => Restaurant(
    id: restaurantId,
    name: restaurantName,
    rating: 4.5,
    deliveryTime: 'Demo estimate',
    cuisine: 'Demo restaurant menu',
    distance: '—',
    location: 'Mandapeta',
    status: RestaurantStatus.open,
  );
}

class _GroceryDiscoverySection {
  const _GroceryDiscoverySection(this.title, this.products);

  final String title;
  final List<_GroceryDiscoveryProduct> products;
}

class _GroceryDiscoveryProduct {
  const _GroceryDiscoveryProduct(
    this.productId,
    this.storeId,
    this.storeName,
    this.productName,
    this.brand,
    this.packSize,
    this.description,
    this.categoryId,
    this.price,
    this.imageColor,
    this.imageIcon,
  );

  final String productId;
  final String storeId;
  final String storeName;
  final String productName;
  final String brand;
  final String packSize;
  final String description;
  final String categoryId;
  final double price;
  final Color imageColor;
  final IconData imageIcon;

  LocalStore get store => LocalStore(
    id: storeId,
    name: storeName,
    rating: 4.6,
    deliveryTime: '15–20 min',
    distance: '1.2 km',
    locality: 'Mandapeta',
    isOpen: true,
  );
}

class _Promotion {
  const _Promotion(
    this.title,
    this.subtitle,
    this.offer,
    this.background,
    this.foreground,
    this.icon,
  );

  final String title;
  final String subtitle;
  final String offer;
  final Color background;
  final Color foreground;
  final IconData icon;
}
