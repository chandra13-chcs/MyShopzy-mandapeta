import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/presentation/motion.dart';
import '../../../shared/presentation/offline_error_state.dart';
import '../../../shared/presentation/press_scale_feedback.dart';
import 'restaurant_menu_page.dart';

enum RestaurantStatus { open, closed, unavailable, unknown }

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.rating,
    required this.deliveryTime,
    required this.cuisine,
    required this.distance,
    required this.location,
    required this.status,
    this.isBackendData = false,
    this.coverImageUrl,
    this.offer,
  });

  final String id;
  final String name;
  final String? coverImageUrl;
  final double rating;
  final String deliveryTime;
  final String cuisine;
  final String distance;
  final String location;
  final String? offer;
  final RestaurantStatus status;
  final bool isBackendData;
}

const sampleRestaurants = [
  Restaurant(
    id: 'spice-route',
    name: 'Spice Route Kitchen',
    rating: 4.5,
    deliveryTime: '25–30 min',
    cuisine: 'Andhra · Biryani · North Indian',
    distance: '2.1 km',
    location: 'Mandapeta',
    offer: '20% OFF',
    status: RestaurantStatus.open,
  ),
  Restaurant(
    id: 'rayalaseema-ruchulu',
    name: 'Rayalaseema Ruchulu',
    rating: 4.4,
    deliveryTime: '30–35 min',
    cuisine: 'Andhra · Meals · Kebabs',
    distance: '3.4 km',
    location: 'Mandapeta',
    offer: 'FREE DELIVERY',
    status: RestaurantStatus.open,
  ),
  Restaurant(
    id: 'tiffin-room',
    name: 'The Tiffin Room',
    rating: 4.3,
    deliveryTime: '20–25 min',
    cuisine: 'South Indian · Breakfast',
    distance: '1.8 km',
    location: 'Mandapeta',
    status: RestaurantStatus.closed,
  ),
  Restaurant(
    id: 'green-leaf-cafe',
    name: 'Green Leaf Cafe',
    rating: 4.6,
    deliveryTime: '25–30 min',
    cuisine: 'Cafe · Vegetarian · Snacks',
    distance: '4.2 km',
    location: 'Mandapeta',
    offer: '₹50 OFF',
    status: RestaurantStatus.open,
  ),
  Restaurant(
    id: 'coastal-kitchen',
    name: 'Coastal Kitchen',
    rating: 4.2,
    deliveryTime: '—',
    cuisine: 'Coastal · Andhra · Seafood',
    distance: '5.6 km',
    location: 'Mandapeta',
    status: RestaurantStatus.unavailable,
  ),
];

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({
    super.key,
    List<Restaurant>? restaurants,
    this.onRestaurantTap,
  }) : restaurants = restaurants ?? sampleRestaurants,
       useDefaultRestaurants = restaurants == null;

  final List<Restaurant> restaurants;
  final bool useDefaultRestaurants;
  final ValueChanged<Restaurant>? onRestaurantTap;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;
  static const _coverColors = [
    Color(0xFF7A4934),
    Color(0xFF45674C),
    Color(0xFFC18A4E),
    Color(0xFF53645E),
  ];

  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  static const _ink = RestaurantsPage._ink;
  static const _muted = RestaurantsPage._muted;
  static const _green = RestaurantsPage._green;

  late Future<List<ApiShop>>? _shopsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final api = CustomerApi.instance;
    _shopsFuture = api.isConfigured && widget.useDefaultRestaurants
        ? api.getShops(partnerType: 'restaurant')
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final shopsFuture = _shopsFuture;
    if (shopsFuture == null) {
      return _buildPage(
        context,
        widget.restaurants,
        sourceLabel: 'Demo catalog · sample shops and details',
      );
    }
    return FutureBuilder<List<ApiShop>>(
      future: shopsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingPage();
        }
        if (snapshot.hasError) {
          return AnimatedContentSwitcher(
            child: KeyedSubtree(
              key: const ValueKey('restaurants-error'),
              child: _buildApiErrorPage(snapshot.error),
            ),
          );
        }
        return _buildPage(
          context,
          snapshot.data!
              .map(
                (shop) => Restaurant(
                  id: shop.id,
                  name: shop.name,
                  rating: 0,
                  deliveryTime: 'Not provided',
                  cuisine: 'Details not provided',
                  distance: '—',
                  location: shop.address ?? 'Address not provided',
                  status: shop.storeOpen
                      ? RestaurantStatus.open
                      : RestaurantStatus.closed,
                  isBackendData: true,
                ),
              )
              .toList(growable: false),
          sourceLabel: 'Backend catalog',
          backendResults: true,
        );
      },
    );
  }

  void _searchRestaurants(String query) {
    final normalizedQuery = query.trim();
    final api = CustomerApi.instance;
    setState(() {
      _searchQuery = normalizedQuery;
      _shopsFuture = api.isConfigured && widget.useDefaultRestaurants
          ? api.getShops(
              partnerType: 'restaurant',
              query: normalizedQuery.isEmpty ? null : normalizedQuery,
            )
          : null;
    });
  }

  Future<void> _refreshRestaurants() async {
    final api = CustomerApi.instance;
    final future = api.getShops(
      partnerType: 'restaurant',
      query: _searchQuery.isEmpty ? null : _searchQuery,
    );
    setState(() => _shopsFuture = future);
    try {
      await future;
    } on CustomerApiException {
      // The FutureBuilder presents the same request error on the page.
    }
  }

  Widget _buildLoadingPage() {
    return AnimatedContentSwitcher(
      child: KeyedSubtree(
        key: const ValueKey('restaurants-loading'),
        child: Scaffold(
          backgroundColor: RestaurantsPage._page,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SkeletonBox(height: 18, width: 170, radius: 6),
                      SizedBox(height: 14),
                      for (var index = 0; index < 3; index++) ...[
                        SkeletonBox(height: 224, radius: 16),
                        SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiErrorPage(Object? error) {
    if (isOfflineApiError(error)) {
      return Scaffold(
        backgroundColor: RestaurantsPage._page,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Center(
                  child: OfflineErrorState(
                    onRetry: () => _searchRestaurants(_searchQuery),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: RestaurantsPage._page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load restaurants.',
                        style: TextStyle(
                          color: RestaurantsPage._ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: RestaurantsPage._muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _searchRestaurants(_searchQuery),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry restaurants'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    List<Restaurant> restaurants, {
    required String sourceLabel,
    bool backendResults = false,
  }) {
    final query = _searchQuery.toLowerCase();
    final visibleRestaurants =
        backendResults ||
            restaurants.any((restaurant) => restaurant.isBackendData)
        ? restaurants
        : restaurants
              .where(
                (restaurant) =>
                    query.isEmpty ||
                    restaurant.name.toLowerCase().contains(query) ||
                    restaurant.cuisine.toLowerCase().contains(query) ||
                    restaurant.location.toLowerCase().contains(query),
              )
              .toList(growable: false);
    final restaurantList = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 19, 16, 24),
      children: [
        Text(
          sourceLabel,
          style: const TextStyle(color: RestaurantsPage._muted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Restaurants near you',
                style: TextStyle(
                  color: RestaurantsPage._ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Text(
              '${visibleRestaurants.length} places',
              style: const TextStyle(
                color: RestaurantsPage._muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (visibleRestaurants.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No restaurants available.')),
          ),
          for (var index = 0; index < visibleRestaurants.length; index++) ...[
            fadeSlideItem(
              itemKey: 'restaurant-${visibleRestaurants[index].id}',
              index: index,
              child: PressScaleFeedback(
                child: _buildRestaurantCard(context, visibleRestaurants, index),
              ),
            ),
            if (index < visibleRestaurants.length - 1) const SizedBox(height: 14),
          ],
      ],
    );

    return AnimatedContentSwitcher(
      child: KeyedSubtree(
      key: ValueKey('restaurants-loaded-${_searchQuery.toLowerCase()}'),
        child: Scaffold(
          backgroundColor: RestaurantsPage._page,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child:
                      backendResults ||
                          restaurants.any(
                            (restaurant) => restaurant.isBackendData,
                          )
                      ? RefreshIndicator(
                          color: const Color(0xFF016034),
                          onRefresh: _refreshRestaurants,
                          child: restaurantList,
                        )
                      : restaurantList,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(
    BuildContext context,
    List<Restaurant> visibleRestaurants,
    int index,
  ) {
    final restaurant = visibleRestaurants[index];
    return _RestaurantCard(
      restaurant: restaurant,
      placeholderColor: RestaurantsPage
          ._coverColors[index % RestaurantsPage._coverColors.length],
      onTap: () {
        if (widget.onRestaurantTap != null) {
          widget.onRestaurantTap!(restaurant);
          return;
        }
        Navigator.of(context).push(
          AppPageRoute<void>.builder(
            builder: (context) => RestaurantMenuPage(restaurant: restaurant),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
      child: Column(
        children: [
          Row(
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
              const SizedBox(width: 8),
              const Icon(Icons.location_on_rounded, color: _green, size: 19),
              const SizedBox(width: 5),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVERING TO',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mandapeta, Andhra Pradesh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3E9),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '25 km',
                  style: TextStyle(
                    color: _green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _RestaurantSearchBar(onSubmitted: _searchRestaurants),
        ],
      ),
    );
  }
}

class _RestaurantSearchBar extends StatefulWidget {
  const _RestaurantSearchBar({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<_RestaurantSearchBar> createState() => _RestaurantSearchBarState();
}

class _RestaurantSearchBarState extends State<_RestaurantSearchBar> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      duration: reduceMotion(context) ? Duration.zero : kMotionFast,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: focused ? RestaurantsPage._green : const Color(0xFFE5E9E3),
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: RestaurantsPage._green.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: RestaurantsPage._muted,
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              key: const ValueKey('restaurant-search'),
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmitted,
              decoration: const InputDecoration(
                hintText: 'Search restaurants...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(color: RestaurantsPage._ink, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.placeholderColor,
    this.onTap,
  });

  final Restaurant restaurant;
  final Color placeholderColor;
  final VoidCallback? onTap;

  static const _ink = RestaurantsPage._ink;
  static const _muted = RestaurantsPage._muted;
  static const _green = RestaurantsPage._green;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 172,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCover(),
                  if (_shouldShowUnavailableState)
                    ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
                  if (restaurant.offer != null)
                    Positioned(
                      top: 11,
                      left: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          restaurant.offer!,
                          style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  if (restaurant.status == RestaurantStatus.closed &&
                      restaurant.isBackendData)
                    Positioned(
                      bottom: 11,
                      left: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Closed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        shape: BoxShape.circle,
                      ),
                      child: const AnimatedBookmarkButton(
                        color: _ink,
                        size: 20,
                      ),
                    ),
                  ),
                  if (_shouldShowUnavailableState)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(restaurant.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!restaurant.isBackendData)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFE4A323),
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                restaurant.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.cuisine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 9),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 300) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildDeliveryTime(),
                                const Spacer(),
                                _buildStatus(restaurant.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: _buildLocation(),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          _buildDeliveryTime(),
                          const SizedBox(width: 9),
                          Expanded(child: _buildLocation()),
                          _buildStatus(restaurant.status),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTime() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_rounded, color: _muted, size: 15),
        const SizedBox(width: 4),
        Text(
          restaurant.deliveryTime,
          style: const TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, color: _muted, size: 15),
        const SizedBox(width: 3),
        Flexible(child: _locationText()),
      ],
    );
  }

  Widget _locationText() {
    return Text(
      '${restaurant.distance} · ${restaurant.location}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: _muted, fontSize: 11),
    );
  }

  Widget _buildCover() {
    final imageUrl = restaurant.coverImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            placeholderColor,
            Color.lerp(placeholderColor, const Color(0xFF1A2922), 0.55)!,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -36,
            right: -18,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: 22,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 20,
                ),
              ),
            ),
          ),
          Icon(
            Icons.restaurant_menu_rounded,
            color: Colors.white.withValues(alpha: 0.88),
            size: 58,
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(RestaurantStatus status) {
    final isOpen = status == RestaurantStatus.open;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          color: isOpen ? _green : const Color(0xFF929892),
          size: 7,
        ),
        const SizedBox(width: 4),
        Text(
          switch (status) {
            RestaurantStatus.open => 'Open',
            RestaurantStatus.closed => 'Closed',
            RestaurantStatus.unavailable => 'Unavailable',
            RestaurantStatus.unknown => 'Hours not provided',
          },
          style: TextStyle(
            color: isOpen ? _green : _muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _statusLabel(RestaurantStatus status) {
    return switch (status) {
      RestaurantStatus.closed => 'Closed right now',
      RestaurantStatus.unavailable => 'Currently unavailable',
      RestaurantStatus.open => 'Open now',
      RestaurantStatus.unknown => 'Hours not provided',
    };
  }

  bool get _shouldShowUnavailableState =>
      !restaurant.isBackendData &&
      (restaurant.status == RestaurantStatus.closed ||
          restaurant.status == RestaurantStatus.unavailable);
}
