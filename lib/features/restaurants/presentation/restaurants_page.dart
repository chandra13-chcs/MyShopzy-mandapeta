import 'package:flutter/material.dart';

import 'restaurant_menu_page.dart';

enum RestaurantStatus { open, closed, unavailable }

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

class RestaurantsPage extends StatelessWidget {
  const RestaurantsPage({
    super.key,
    this.restaurants = sampleRestaurants,
    this.onRestaurantTap,
  });

  final List<Restaurant> restaurants;
  final ValueChanged<Restaurant>? onRestaurantTap;

  static const _ink = Color(0xFF17251F);
  static const _muted = Color(0xFF727A74);
  static const _green = Color(0xFF16834A);
  static const _page = Color(0xFFF7F8F5);
  static const _coverColors = [
    Color(0xFF7A4934),
    Color(0xFF45674C),
    Color(0xFFC18A4E),
    Color(0xFF53645E),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 19, 16, 24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Restaurants near you',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      Text(
                        '${restaurants.length} places',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  for (var index = 0; index < restaurants.length; index++) ...[
                    _RestaurantCard(
                      restaurant: restaurants[index],
                      placeholderColor:
                          _coverColors[index % _coverColors.length],
                      onTap: () {
                        final restaurant = restaurants[index];
                        if (onRestaurantTap != null) {
                          onRestaurantTap!(restaurant);
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                RestaurantMenuPage(restaurant: restaurant),
                          ),
                        );
                      },
                    ),
                    if (index < restaurants.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
          Container(
            height: 49,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE5E9E3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: _muted, size: 22),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Search restaurants, dishes...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
              ],
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
                  if (restaurant.status != RestaurantStatus.open)
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
                      child: const Icon(
                        Icons.bookmark_border_rounded,
                        color: _ink,
                        size: 20,
                      ),
                    ),
                  ),
                  if (restaurant.status != RestaurantStatus.open)
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
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: _muted,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryTime,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Icon(
                        Icons.location_on_outlined,
                        color: _muted,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${restaurant.distance} · ${restaurant.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                      const Spacer(),
                      _buildStatus(restaurant.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    };
  }
}
