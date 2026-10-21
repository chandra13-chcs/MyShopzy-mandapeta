import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/presentation/bottom_navigation_bar.dart';
import '../../../shared/presentation/dietary_badge.dart';
import '../../../shared/presentation/motion.dart';
import '../../../shared/presentation/offline_error_state.dart';
import '../../../shared/presentation/press_scale_feedback.dart';
import '../../../shared/presentation/promotional_banner.dart';
import '../../bakery/presentation/bakery_page.dart';
import '../../cart/presentation/cart_page.dart';
import '../../checkout/presentation/checkout_page.dart';
import '../../profile/models/saved_address.dart';
import '../../profile/presentation/saved_addresses_page.dart';
import 'delivery_location_bottom_sheet.dart';
import '../../parcel/data/parcel_location_service.dart';
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
  const HomePage({super.key, this.locationService});

  final ParcelLocationService? locationService;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;
  static const _recentlyViewedViewAllThreshold = 4;
  static const _homeIntroChildCount = 8;
  static const _promotionsChildIndex = 6;

  static final _discoverySearchResults = _buildSearchDiscoveryResults();
  static final _homeSliverChildCount =
      _homeIntroChildCount +
      2 * _restaurantDiscoverySections.length +
      2 +
      2 * _groceryDiscoverySections.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        bottom: false,
        child: _HomeCatalogRefreshView(
          childCount: _homeSliverChildCount,
          itemBuilder: _buildHomeSliverChild,
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildHomeSliverChild(
    BuildContext context,
    int index,
    GlobalKey<_HomeCatalogFeedState> catalogKey,
  ) {
    if (index < _homeIntroChildCount) {
      return switch (index) {
        0 => _buildHeader(context),
        1 => const SizedBox(height: 10),
        2 => _buildSearchBar(context),
        3 => const SizedBox(height: 22),
        4 => _buildServiceGrid(),
        5 => const SizedBox(height: 22),
        _promotionsChildIndex => _buildPromotions(),
        7 => AnimatedBuilder(
          animation: RecentlyViewedStore.instance,
          builder: (context, child) {
            final products = RecentlyViewedStore.instance.products;
            if (products.isEmpty) return const SizedBox(height: 24);
            return Column(
              children: [
                _buildRecentlyViewedSection(context, products),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
        _ => const SizedBox.shrink(),
      };
    }

    final restaurantChildIndex = index - _homeIntroChildCount;
    final restaurantChildCount = 2 * _restaurantDiscoverySections.length;
    if (restaurantChildIndex < restaurantChildCount) {
      if (CustomerApi.instance.isConfigured) {
        return restaurantChildIndex == 0
            ? _HomeCatalogFeed(key: catalogKey)
            : const SizedBox.shrink();
      }
      final section = _restaurantDiscoverySections[restaurantChildIndex ~/ 2];
      return restaurantChildIndex.isEven
          ? restaurantChildIndex == 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Demo home catalog · sample shops and products',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      _buildRestaurantDiscoverySection(context, section),
                    ],
                  )
                : _buildRestaurantDiscoverySection(context, section)
          : const SizedBox(height: 22);
    }

    final parcelChildIndex = _homeIntroChildCount + restaurantChildCount;
    if (index == parcelChildIndex) return _buildParcelAdvertisement(context);
    if (index == parcelChildIndex + 1) return const SizedBox(height: 24);

    final groceryChildIndex = index - parcelChildIndex - 2;
    if (CustomerApi.instance.isConfigured) return const SizedBox.shrink();
    final section = _groceryDiscoverySections[groceryChildIndex ~/ 2];
    return groceryChildIndex.isEven
        ? _buildGroceryDiscoverySection(context, section)
        : const SizedBox(height: 20);
  }

  Widget _buildHeader(BuildContext context) {
    return _HomeLocationHeader(locationService: locationService);
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
      case SearchResultType.backendShop:
      case SearchResultType.backendProduct:
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
    return _HomeServiceGrid(
      onServiceTap: (context, service) {
        final destination = service.partnerType == null
            ? switch (service.key) {
                'restaurants' => const RestaurantsPage(),
                'bakery' => const BakeryPage(),
                'meat_only_chicken' => const MeatPage(),
                'parcel' => const ParcelPage(),
                'local_stores' => const LocalStoresPage(),
                'fruits_vegetables' => const VegetablesFruitsPage(),
                _ => const LocalStoresPage(),
              }
            : switch (service.partnerType) {
                'restaurant' => const RestaurantsPage(),
                'meat_shop' => const MeatPage(),
                final partnerType => LocalStoresPage(
                  partnerType: partnerType,
                  categoryName: service.name,
                ),
              };
        Navigator.of(
          context,
        ).push(AppPageRoute<void>.builder(builder: (context) => destination));
      },
    );
  }

  Widget _buildPromotions() {
    const banners = [
      (
        key: 'restaurants',
        assetPath: 'assets/myshopzy_banners/myshopzy restarants.jpeg',
      ),
      (
        key: 'groceries',
        assetPath: 'assets/myshopzy_banners/myshopzy groceries.jpeg',
      ),
      (
        key: 'bakery',
        assetPath: 'assets/myshopzy_banners/myshopzy bakery.jpeg',
      ),
    ];

    return _buildPromotionCarousel(banners: banners);
  }

  Widget _buildPromotionCarousel({
    required List<({String key, String assetPath})> banners,
    void Function(BuildContext context, String key)? onBannerTap,
  }) {
    final promotionCards = SizedBox(
          width: double.infinity,
          child: PromotionalBannerCarousel(
            banners: banners,
            carouselKey: ValueKey(
              onBannerTap == null
                  ? 'home-promotions-carousel'
                  : 'home-parcel-fruits-carousel',
            ),
            onBannerTap: onBannerTap,
          ),
        );
    if (!CustomerApi.instance.isConfigured) return promotionCards;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Demo offers · not verified or redeemable',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ),
            promotionCards,
          ],
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
              return fadeSlideItem(
                itemKey: 'home-restaurant-product-${product.productId}',
                index: index,
                child: _buildRestaurantDiscoveryCard(context, product),
              );
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
            itemBuilder: (context, index) => fadeSlideItem(
              itemKey: 'home-recent-product-${products[index].id}',
              index: index,
              child: RecentlyViewedProductCard(
                product: products[index],
                width: 138,
              ),
            ),
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
    const banners = [
      (
        key: 'parcel',
        assetPath: 'assets/myshopzy_banners/parellu.jpeg',
      ),
      (
        key: 'fruits',
        assetPath: 'assets/myshopzy_banners/myshopzy fresh fruits .jpeg',
      ),
    ];

    return _buildPromotionCarousel(
      banners: banners,
      onBannerTap: (context, key) {
        final destination = key == 'parcel'
            ? const ParcelPage()
            : const VegetablesFruitsPage();
        Navigator.of(
          context,
        ).push(AppPageRoute<void>.builder(builder: (context) => destination));
      },
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
    return ShopzyBottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) {
          Navigator.of(context).push(
            AppPageRoute<void>.builder(
              builder: (context) => const CategoriesPage(),
            ),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            AppPageRoute<void>.builder(builder: (context) => const CartPage()),
          );
        } else if (index == 3) {
          Navigator.of(context).push(
            AppPageRoute<void>.builder(
              builder: (context) => const OrdersPage(),
            ),
          );
        } else if (index == 4) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const ProfilePage()),
          );
        }
      },
    );
  }
}

typedef _HomeSliverBuilder = Widget Function(
  BuildContext context,
  int index,
  GlobalKey<_HomeCatalogFeedState> catalogKey,
);

class _HomeCatalogRefreshView extends StatefulWidget {
  const _HomeCatalogRefreshView({
    required this.childCount,
    required this.itemBuilder,
  });

  final int childCount;
  final _HomeSliverBuilder itemBuilder;

  @override
  State<_HomeCatalogRefreshView> createState() =>
      _HomeCatalogRefreshViewState();
}

class _HomeCatalogRefreshViewState extends State<_HomeCatalogRefreshView> {
  final _catalogKey = GlobalKey<_HomeCatalogFeedState>();

  Future<void> _refreshCatalog() async {
    final catalogState = _catalogKey.currentState;
    if (catalogState != null) await catalogState._load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: const Color(0xFF016034),
    onRefresh: _refreshCatalog,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => fadeSlideItem(
                itemKey: 'home-feed-section-$index',
                index: index,
                child: Padding(
                  padding: index == HomePage._promotionsChildIndex
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 2),
                  child: widget.itemBuilder(context, index, _catalogKey),
                ),
              ),
              childCount: widget.childCount,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _catalogSkeletonSpacing(BuildContext context, int index) =>
    const SizedBox(width: 8);

Widget _catalogSkeletonCard(BuildContext context, int index) => const SizedBox(
  width: 156,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkeletonBox(height: 164, radius: 14),
      SizedBox(height: 10),
      SkeletonBox(width: 112, height: 14, radius: 5),
      SizedBox(height: 8),
      SkeletonBox(width: 82, height: 12, radius: 5),
      Spacer(),
      SkeletonBox(height: 38, radius: 10),
    ],
  ),
);

class _HomeLocationHeader extends StatefulWidget {
  const _HomeLocationHeader({this.locationService});

  final ParcelLocationService? locationService;

  @override
  State<_HomeLocationHeader> createState() => _HomeLocationHeaderState();
}

class _HomeLocationHeaderState extends State<_HomeLocationHeader>
    with WidgetsBindingObserver {
  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;

  SavedAddress? _selectedAddress;
  bool _isDetectingLocation = false;
  bool _isLocationSheetOpen = false;
  bool _isRefreshingLocation = false;
  bool _hasChosenManualLocation = false;
  int _selectionRevision = 0;

  late final ParcelLocationService _locationService =
      widget.locationService ?? ParcelLocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshCurrentLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLocationSheetOpen) {
      unawaited(_refreshCurrentLocation());
    }
  }

  String get _locationLabel {
    if (_isDetectingLocation) return 'Detecting location...';
    final selectedAddress = _selectedAddress;
    if (selectedAddress == null) return 'Choose your location';
    if (selectedAddress.id == 'current-location') {
      return selectedAddress.address;
    }
    if (demoSavedAddresses.any((address) => address.id == selectedAddress.id)) {
      return '${selectedAddress.label} · Demo address: ${selectedAddress.address}';
    }
    return '${selectedAddress.label} · ${selectedAddress.address}';
  }

  Future<void> _refreshCurrentLocation() async {
    if (_isRefreshingLocation || _isLocationSheetOpen) return;
    _isRefreshingLocation = true;
    final selectionRevision = _selectionRevision;
    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      final permission = await _locationService.checkPermission();
      if (!mounted) return;
      if (!serviceEnabled ||
          (permission != LocationPermission.whileInUse &&
              permission != LocationPermission.always) ||
          _hasChosenManualLocation ||
          (_selectedAddress != null &&
              _selectedAddress!.id != 'current-location')) {
        return;
      }
      await _fetchCurrentLocation(selectionRevision);
    } on ParcelLocationException catch (error) {
      debugPrint('Unable to refresh home location: ${error.message}');
    } on PlatformException catch (error) {
      debugPrint('Unable to check home location permission: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Location is unavailable on this platform: $error');
    } on Exception catch (error) {
      debugPrint('Unable to refresh home location: $error');
    } finally {
      _isRefreshingLocation = false;
    }
  }

  Future<void> _fetchCurrentLocation(int selectionRevision) async {
    if (!mounted || selectionRevision != _selectionRevision) return;
    setState(() => _isDetectingLocation = true);
    try {
      final location = await _locationService.detectCurrentLocation();
      if (!mounted || selectionRevision != _selectionRevision) return;
      setState(() {
        _selectedAddress = SavedAddress(
          id: 'current-location',
          label: 'Current location',
          address: location.address,
          icon: Icons.my_location_rounded,
          latitude: location.latitude,
          longitude: location.longitude,
        );
      });
    } on ParcelLocationException catch (error) {
      debugPrint('Unable to fetch home location: ${error.message}');
    } on PlatformException catch (error) {
      debugPrint('Unable to fetch home location: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Location is unavailable on this platform: $error');
    } on Exception catch (error) {
      debugPrint('Unable to fetch home location: $error');
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('home-delivery-address-selector'),
                  onTap: _showLocationSelector,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 1,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: _green,
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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
                  ),
                ),
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

  Future<void> _showLocationSelector() async {
    _isLocationSheetOpen = true;
    SavedAddress? selectedAddress;
    try {
      selectedAddress = await showModalBottomSheet<SavedAddress>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => DeliveryLocationBottomSheet(
          locationService: _locationService,
          onViewAll: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const SavedAddressesPage(),
              ),
            );
          },
          onEnterManually: () {
            _selectionRevision++;
            _hasChosenManualLocation = true;
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => CheckoutPage(
                  openNewAddressOnLoad: true,
                  onAddressSelected: _selectManualAddress,
                ),
              ),
            );
          },
        ),
      );
    } finally {
      _isLocationSheetOpen = false;
    }
    if (!mounted || selectedAddress == null) return;
    setState(() {
      _selectionRevision++;
      _selectedAddress = selectedAddress;
    });
  }

  void _selectManualAddress(CheckoutDeliveryAddress address) {
    if (!mounted) return;
    setState(() {
      _selectionRevision++;
      _hasChosenManualLocation = true;
      _selectedAddress = SavedAddress(
        id: 'manual-${address.id}',
        label: address.addressType,
        address: address.formattedAddress,
        icon: switch (address.addressType) {
          'Home' => Icons.home_outlined,
          'Work' => Icons.business_outlined,
          _ => Icons.location_on_outlined,
        },
        latitude: address.latitude,
        longitude: address.longitude,
      );
    });
  }
}

class _HomeCatalogFeed extends StatefulWidget {
  const _HomeCatalogFeed({super.key});

  @override
  State<_HomeCatalogFeed> createState() => _HomeCatalogFeedState();
}

class _HomeCatalogFeedState extends State<_HomeCatalogFeed> {
  List<ApiShop> _shops = const [];
  List<ApiProduct> _products = const [];
  bool _loading = false;
  String? _error;
  bool _offlineError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Widget? _shopDestination(ApiShop shop) {
    if (shop.partnerType == 'restaurant') {
      return RestaurantMenuPage(
        restaurant: Restaurant(
          id: shop.id,
          name: shop.name,
          rating: 0,
          deliveryTime: 'Not provided',
          cuisine: 'Details not provided',
          distance: '—',
          location: shop.address ?? 'Address not provided',
          status: RestaurantStatus.unknown,
          isBackendData: true,
        ),
      );
    }
    if (shop.partnerType == 'grocery') {
      return LocalStoreCatalogPage(
        store: LocalStore(
          id: shop.id,
          name: shop.name,
          rating: 0,
          deliveryTime: 'Not provided',
          distance: '—',
          locality: shop.address ?? 'Address not provided',
          isOpen: false,
          isBackendData: true,
        ),
        categories: commonLocalStoreCategories,
        products: const [],
      );
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offlineError = false;
      _shops = const [];
      _products = const [];
    });
    try {
      final responses = await Future.wait<Object>([
        CustomerApi.instance.getShops(),
        CustomerApi.instance.getAllProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _shops = responses[0] as List<ApiShop>;
        _products = responses[1] as List<ApiProduct>;
        _loading = false;
      });
    } on CustomerApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _offlineError = isOfflineApiError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AnimatedContentSwitcher(child: _catalogSkeleton());
    }
    if (_error != null) {
      return AnimatedContentSwitcher(
        child: KeyedSubtree(
          key: const ValueKey('home-live-catalog-error'),
          child: _offlineError
              ? OfflineErrorState(onRetry: _load)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live catalog unavailable',
                        style: TextStyle(
                          color: HomePage._ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: HomePage._muted,
                          fontSize: 12,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry catalog'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    if (_shops.isEmpty && _products.isEmpty) {
      return AnimatedContentSwitcher(
        child: Padding(
          key: ValueKey('home-live-catalog-empty'),
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No live shops or products are available right now.',
            style: TextStyle(color: HomePage._muted, fontSize: 13),
          ),
        ),
      );
    }
    return AnimatedContentSwitcher(
      child: Column(
        key: const ValueKey('home-live-catalog-content'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_shops.isNotEmpty) ...[
            _sectionTitle('Live shops'),
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _shops.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final shop = _shops[index];
                  return fadeSlideItem(
                    itemKey: 'home-live-shop-${shop.id}',
                    index: index,
                    child: Stack(
                      children: [
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: ValueKey('home-live-shop-${shop.id}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              final destination = _shopDestination(shop);
                              if (destination == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This shop type does not have a customer catalog screen yet.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context).push(
                                AppPageRoute<void>.builder(
                                  builder: (context) => destination,
                                ),
                              );
                            },
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E9E3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    shop.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: HomePage._ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    shop.partnerType,
                                    style: const TextStyle(
                                      color: HomePage._muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!shop.storeOpen)
                          Positioned(
                            top: 3,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5B5B5B),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'Closed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_products.isNotEmpty) ...[
            _sectionTitle('Live products'),
            const SizedBox(height: 8),
            SizedBox(
              height: 288,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _products.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return fadeSlideItem(
                    itemKey: 'home-live-product-${product.id}',
                    index: index,
                    child: PressScaleFeedback(
                      child: SizedBox(
                        key: ValueKey('home-live-product-${product.id}'),
                        width: 156,
                        child: StoreProductCard(
                          product: _mapProduct(product),
                          placeholderIndex: index,
                          storeName: product.shopName ?? '',
                          relatedProducts: const [],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _catalogSkeleton() => Shimmer(
    child: SizedBox(
      key: ValueKey('home-live-catalog-loading'),
      height: 288,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: _catalogSkeletonSpacing,
        itemBuilder: _catalogSkeletonCard,
      ),
    ),
  );

  StoreProduct _mapProduct(ApiProduct product) => StoreProduct(
    id: product.id,
    storeId: product.shopId,
    categoryId: product.categoryId ?? 'other',
    name: product.name,
    brand: product.brand ?? '',
    description: product.description,
    packSize: product.packSize ?? '',
    price: product.priceMinor / 100,
    mrp: (product.mrpMinor ?? product.priceMinor) / 100,
    discount: product.discountPercent,
    rating: product.rating ?? -1,
    available: product.available,
    variants: product.variants,
    serviceType: switch (product.partnerType) {
      'restaurant' => 'restaurant',
      'meat_shop' => 'meat',
      'bakery' => 'bakery',
      _ => 'local_store',
    },
    imageUrl: product.imageUrl,
    badge: product.badge,
    isBackendData: true,
    storeOpen: product.storeOpen,
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: HomePage._ink,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
  );
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
  const _Service(
    this.name,
    this.key,
    this.assetPath, {
    this.partnerType,
  });

  factory _Service.forPartnerCategory(ApiPartnerCategory category) {
    final partnerType = category.partnerType;
    final assetPath = switch (partnerType) {
      'restaurant' => 'assets/category_tiles/restarant tile.jpeg',
      'grocery' => 'assets/category_tiles/local stores tiles.jpeg',
      'meat_shop' => 'assets/category_tiles/meat tiles.jpeg',
      'other' => 'assets/category_tiles/local stores tiles.jpeg',
      'bakery' => 'assets/category_tiles/bakery tile.jpeg',
      'vegetables_fruits' => 'assets/category_tiles/fruits nd vegetables tile.jpeg',
      _ => 'assets/category_tiles/local stores tiles.jpeg',
    };
    return _Service(
      category.displayName,
      'partner-${category.partnerType}',
      assetPath,
      partnerType: category.partnerType,
    );
  }

  final String name;
  final String key;
  final String assetPath;
  final String? partnerType;
}

const _demoHomeServices = [
  _Service(
    'Meat Only Chicken',
    'meat_only_chicken',
    'assets/category_tiles/meat tiles.jpeg',
  ),
  _Service('Bakery', 'bakery', 'assets/category_tiles/bakery tile.jpeg'),
  _Service('Parcel', 'parcel', 'assets/category_tiles/parcel tiles.jpeg'),
  _Service(
    'Local Stores',
    'local_stores',
    'assets/category_tiles/local stores tiles.jpeg',
  ),
  _Service(
    'Fruits & Vegetables',
    'fruits_vegetables',
    'assets/category_tiles/fruits nd vegetables tile.jpeg',
  ),
  _Service(
    'Restaurants',
    'restaurants',
    'assets/category_tiles/restarant tile.jpeg',
  ),
];

class _HomeServiceGrid extends StatefulWidget {
  const _HomeServiceGrid({required this.onServiceTap});

  final void Function(BuildContext context, _Service service) onServiceTap;

  @override
  State<_HomeServiceGrid> createState() => _HomeServiceGridState();
}

class _HomeServiceGridState extends State<_HomeServiceGrid> {
  late Future<List<_Service>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  void _loadServices() {
    final api = CustomerApi.instance;
    _servicesFuture = api.isConfigured
        ? _loadPartnerServices(api)
        : Future<List<_Service>>.value(_demoHomeServices);
  }

  Future<List<_Service>> _loadPartnerServices(CustomerApi api) async {
    final categories = await api.getPartnerCategories();
    return categories.map(_Service.forPartnerCategory).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Service>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AnimatedContentSwitcher(
            child: GridView.builder(
              key: const ValueKey('home-partner-categories-loading'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) =>
                  const SkeletonBox(height: 110, radius: 12),
            ),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (isOfflineApiError(error)) {
            return OfflineErrorState(onRetry: () => setState(_loadServices));
          }
          final message = error is CustomerApiException
              ? error.message
              : 'Please try again.';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partner categories unavailable',
                  style: TextStyle(
                    color: HomePage._ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(color: HomePage._muted, fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () => setState(_loadServices),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry categories'),
                ),
              ],
            ),
          );
        }

        final services = snapshot.data!;
        if (services.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No partner categories are available right now.',
              style: TextStyle(color: HomePage._muted, fontSize: 13),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 310 ? 2 : 3;
            final tileWidth =
                (constraints.maxWidth - 8 * (crossAxisCount - 1)) /
                crossAxisCount;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final service = services[index];
                return fadeSlideItem(
                  itemKey: 'home-category-${service.key}',
                  index: index,
                  child: PressScaleFeedback(
                    child: Material(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('home-category-${service.key}'),
                        onTap: () => widget.onServiceTap(context, service),
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    service.assetPath,
                                    fit: BoxFit.contain,
                                    cacheWidth:
                                        (tileWidth *
                                                MediaQuery.devicePixelRatioOf(
                                                  context,
                                                ))
                                            .round(),
                                    semanticLabel: service.name,
                                  ),
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: IgnorePointer(
                                      child: Container(
                                        key: ValueKey(
                                          'home-category-arrow-${service.key}',
                                        ),
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(5, 2, 5, 6),
                              child: Text(
                                service.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: HomePage._ink,
                                  fontSize: 12,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
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
