import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../local_stores/models/local_store.dart';
import '../../local_stores/presentation/local_store_catalog_page.dart';
import '../../product_details/data/product_availability_store.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../../restaurants/presentation/restaurant_menu_page.dart';
import '../../restaurants/presentation/restaurants_page.dart';
import '../data/search_index.dart';
import '../models/search_result.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.additionalResults = const [],
    this.destinationBuilder,
  });

  final List<SearchResult> additionalResults;
  final Widget? Function(SearchResult result)? destinationBuilder;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;

  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;
  int _searchRequestGeneration = 0;
  bool _loading = false;
  Object? _error;
  List<SearchResult> _backendResults = const [];

  bool get _backendMode => CustomerApi.instance.isConfigured;

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _searchRequestGeneration++;
    setState(() {
      _query = value;
      _error = null;
      _backendResults = const [];
      _loading = value.trim().isNotEmpty && _backendMode;
    });
    if (value.trim().isEmpty || !_backendMode) return;
    _debounce = Timer(const Duration(milliseconds: 350), _searchBackend);
  }

  Future<void> _searchBackend() async {
    final query = _query.trim();
    if (query.isEmpty || !_backendMode) return;
    final requestGeneration = ++_searchRequestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _backendResults = const [];
    });
    try {
      final responses = await Future.wait([
        CustomerApi.instance.getShops(query: query),
        CustomerApi.instance.getProducts(query: query),
      ]);
      if (!mounted ||
          requestGeneration != _searchRequestGeneration ||
          query != _query.trim()) {
        return;
      }
      final shops = responses[0] as List<ApiShop>;
      final products = responses[1] as List<ApiProduct>;
      setState(() {
        _backendResults = [
          ...shops.map(_shopResult),
          ...products.map(_productResult),
        ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          requestGeneration != _searchRequestGeneration ||
          query != _query.trim()) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  SearchResult _shopResult(ApiShop shop) => SearchResult(
    id: shop.id,
    type: SearchResultType.backendShop,
    displayName: shop.name,
    subtitle: shop.address ?? shop.partnerName ?? 'Shop',
    merchantId: shop.id,
    merchantName: shop.name,
    partnerType: shop.partnerType,
    isBackendData: true,
    storeOpen: shop.storeOpen,
    searchableText: '${shop.name} ${shop.partnerName ?? ''} ${shop.address ?? ''}',
  );

  SearchResult _productResult(ApiProduct product) => SearchResult(
    id: product.id,
    type: SearchResultType.backendProduct,
    displayName: product.name,
    subtitle: product.shopName,
    imageUrl: product.imageUrl,
    merchantId: product.shopId,
    merchantName: product.shopName,
    categoryId: product.categoryId,
    partnerType: product.partnerType,
    price: product.priceMinor / 100,
    available: product.available,
    isBackendData: true,
    storeOpen: product.storeOpen,
    variants: product.variants,
    searchableText: '${product.name} ${product.description} ${product.shopName ?? ''}',
  );

  Widget? _backendDestination(SearchResult result) {
    if (result.type == SearchResultType.backendShop) {
      if (result.partnerType == 'restaurant') {
        return RestaurantMenuPage(
          restaurant: Restaurant(
            id: result.id,
            name: result.displayName,
            rating: 0,
            deliveryTime: 'Not provided',
            cuisine: 'Details not provided',
            distance: '—',
            location: result.subtitle ?? 'Address not provided',
            status: result.storeOpen
                ? RestaurantStatus.open
                : RestaurantStatus.closed,
            isBackendData: true,
          ),
        );
      }
      if (result.partnerType == 'grocery') {
        final store = LocalStore(
          id: result.id,
          name: result.displayName,
          rating: 0,
          deliveryTime: 'Not provided',
          distance: '—',
          locality: result.subtitle ?? 'Address not provided',
          isOpen: result.storeOpen,
          isBackendData: true,
        );
        return LocalStoreCatalogPage(
          store: store,
          categories: commonLocalStoreCategories,
          products: const [],
        );
      }
      return null;
    }
    if (result.type != SearchResultType.backendProduct) return null;
    final type = result.partnerType;
    return ProductDetailsPage(
      product: ProductDetailsProduct(
        id: result.id,
        serviceType: switch (type) {
          'restaurant' => 'restaurant',
          'grocery' => 'local_store',
          'meat_shop' => 'meat',
          _ => 'other',
        },
        merchantId: result.merchantId,
        merchantName: result.merchantName,
        variants: result.variants,
        categoryId: result.categoryId,
        name: result.displayName,
        description: '',
        imageUrl: result.imageUrl,
        priceInPaise: result.price == null ? null : (result.price! * 100).round(),
        available: result.available,
        icon: switch (type) {
          'restaurant' => Icons.restaurant_menu_rounded,
          'meat_shop' => Icons.set_meal_rounded,
          _ => Icons.shopping_basket_rounded,
        },
        isBackendProduct: true,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _backendMode
        ? _backendResults
        : SearchIndex.search(_query, additionalResults: widget.additionalResults);

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE8EBE6)),
                      minimumSize: const Size(42, 42),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E9E3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: _muted,
                            size: 22,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              onChanged: _onQueryChanged,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: 'Search restaurants, groceries, products...',
                                hintStyle: TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(color: _ink, fontSize: 13),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              tooltip: 'Clear search',
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _muted,
                                size: 19,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_backendMode && _query.trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Demo search · sample results',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
              ),
            if (_backendMode &&
                _query.trim().isNotEmpty &&
                !_loading &&
                _error == null)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Live catalog · shops and products',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
              ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _SearchMessage(
                      icon: Icons.search_rounded,
                      title: 'Search MyShopzy',
                      message: 'Find restaurants, shops and products near you.',
                    )
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _SearchRetry(onRetry: _searchBackend)
                  : results.isEmpty
                  ? _SearchMessage(
                      icon: Icons.search_off_rounded,
                      title: 'No results found',
                      message: _backendMode
                          ? 'Try another name, shop or product. Live category search is not available.'
                          : 'Try another name, product or category.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) => _SearchResultTile(
                        result: results[index],
                        onTap: () {
                          final result = results[index];
                          final destination = _backendMode
                              ? _backendDestination(result)
                              : widget.destinationBuilder?.call(result);
                          if (_backendMode &&
                              result.type == SearchResultType.backendShop &&
                              destination == null) {
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
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  destination ??
                                  SearchIndex.destinationFor(result),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF9AA29C), size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: _SearchPageState._ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _SearchPageState._muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchRetry extends StatelessWidget {
  const _SearchRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF9AA29C),
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Search is unavailable',
              style: TextStyle(
                color: _SearchPageState._ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _SearchPageState._muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final serviceType = result.serviceTypeForAvailability;
    if (!result.isProductResult || serviceType == null) {
      return _buildTile(context, isAvailable: true);
    }
    return AnimatedBuilder(
      animation: ProductAvailabilityStore.instance,
      builder: (context, child) => _buildTile(
        context,
        isAvailable: ProductAvailabilityStore.instance.isAvailable(
          productId: result.id,
          serviceType: serviceType,
          merchantId: result.merchantId,
          defaultAvailable: result.available,
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, {required bool isAvailable}) {
    final icon = switch (result.type) {
      SearchResultType.restaurant => Icons.restaurant_rounded,
      SearchResultType.restaurantProduct => Icons.restaurant_menu_rounded,
      SearchResultType.bakery => Icons.bakery_dining_rounded,
      SearchResultType.bakeryProduct => Icons.cake_rounded,
      SearchResultType.localStore => Icons.storefront_rounded,
      SearchResultType.storeProduct => Icons.shopping_basket_rounded,
      SearchResultType.meatCategory ||
      SearchResultType.meatProduct => Icons.set_meal_rounded,
      SearchResultType.produceCategory ||
      SearchResultType.produceProduct => Icons.eco_rounded,
      SearchResultType.homeRestaurant => Icons.restaurant_rounded,
      SearchResultType.homeRestaurantProduct => Icons.restaurant_menu_rounded,
      SearchResultType.homeStore => Icons.storefront_rounded,
      SearchResultType.homeStoreProduct => Icons.shopping_basket_rounded,
      SearchResultType.backendShop => switch (result.partnerType) {
        'restaurant' => Icons.restaurant_rounded,
        'meat_shop' => Icons.set_meal_rounded,
        _ => Icons.storefront_rounded,
      },
      SearchResultType.backendProduct => switch (result.partnerType) {
        'restaurant' => Icons.restaurant_menu_rounded,
        'meat_shop' => Icons.set_meal_rounded,
        _ => Icons.shopping_basket_rounded,
      },
    };
    final typeLabel = switch (result.type) {
      SearchResultType.restaurant => 'Restaurant',
      SearchResultType.restaurantProduct => 'Restaurant item',
      SearchResultType.bakery => 'Bakery',
      SearchResultType.bakeryProduct => 'Bakery item',
      SearchResultType.localStore => 'Local store',
      SearchResultType.storeProduct => 'Store product',
      SearchResultType.meatCategory => 'Meat category',
      SearchResultType.meatProduct => 'Meat product',
      SearchResultType.produceCategory => 'Produce category',
      SearchResultType.produceProduct => 'Fresh produce',
      SearchResultType.homeRestaurant => 'Restaurant',
      SearchResultType.homeRestaurantProduct => 'Restaurant item',
      SearchResultType.homeStore => 'Local store',
      SearchResultType.homeStoreProduct => 'Store product',
      SearchResultType.backendShop => switch (result.partnerType) {
        'restaurant' => 'Restaurant',
        'grocery' => 'Local store',
        'meat_shop' => 'Meat shop',
        _ => 'Shop',
      },
      SearchResultType.backendProduct => switch (result.partnerType) {
        'restaurant' => 'Restaurant item',
        'grocery' => 'Store product',
        'meat_shop' => 'Meat product',
        _ => 'Product',
      },
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ResultImage(result: result, icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F3E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              color: _SearchPageState._green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF2F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Color(0xFFA85B5B),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (!result.storeOpen) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Closed',
                              style: TextStyle(
                                color: Color(0xFF5B5B5B),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      result.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _SearchPageState._ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (result.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        result.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _SearchPageState._muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (result.price != null) ...[
                const SizedBox(width: 8),
                Text(
                  '₹${result.price!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _SearchPageState._ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.result, required this.icon});

  final SearchResult result;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final imageUrl = result.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: 54,
        height: 54,
        child: imageUrl == null
            ? ColoredBox(
                color: const Color(0xFFE8F3E9),
                child: Icon(icon, color: const Color(0xFF397447), size: 25),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: const Color(0xFFE8F3E9),
                  child: Icon(icon, color: const Color(0xFF397447), size: 25),
                ),
              ),
      ),
    );
  }
}
