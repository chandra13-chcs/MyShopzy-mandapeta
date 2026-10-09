import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'bakery_menu_page.dart';

enum BakeryStatus { open, closed }

class BakeryShop {
  const BakeryShop({
    required this.id,
    required this.name,
    required this.rating,
    required this.deliveryTime,
    required this.category,
    required this.distance,
    required this.location,
    required this.status,
    this.coverImageUrl,
    this.offer,
  });

  final String id;
  final String name;
  final double rating;
  final String deliveryTime;
  final String category;
  final String distance;
  final String location;
  final BakeryStatus status;
  final String? coverImageUrl;
  final String? offer;
}

const sampleBakeries = [
  BakeryShop(
    id: 'sri-sai-bakery',
    name: 'Sri Sai Bakery',
    rating: 4.6,
    deliveryTime: '20–25 min',
    category: 'Cakes · Puffs · Fresh bread',
    distance: '1.8 km',
    location: 'Mandapeta',
    status: BakeryStatus.open,
    offer: '10% OFF',
  ),
  BakeryShop(
    id: 'venkateswara-bakery',
    name: 'Venkateswara Bakery',
    rating: 4.4,
    deliveryTime: '25–30 min',
    category: 'Pastries · Biscuits · Snacks',
    distance: '2.6 km',
    location: 'Mandapeta',
    status: BakeryStatus.open,
  ),
  BakeryShop(
    id: 'sweet-treats-bakery',
    name: 'Sweet Treats Bakery',
    rating: 4.7,
    deliveryTime: '25–35 min',
    category: 'Cakes · Desserts · Donuts',
    distance: '3.2 km',
    location: 'Mandapeta',
    status: BakeryStatus.closed,
    offer: '₹50 OFF',
  ),
  BakeryShop(
    id: 'bakers-point',
    name: 'Bakers Point',
    rating: 4.3,
    deliveryTime: '20–30 min',
    category: 'Breads · Puffs · Beverages',
    distance: '4.5 km',
    location: 'Mandapeta',
    status: BakeryStatus.open,
  ),
];

class BakeryPage extends StatelessWidget {
  const BakeryPage({
    super.key,
    this.bakeries = sampleBakeries,
  });

  final List<BakeryShop> bakeries;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;
  static const _coverColors = [
    Color(0xFFAA774B),
    Color(0xFF79604C),
    Color(0xFFA75D50),
    Color(0xFF6A775B),
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
                          'Bakeries near you',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      Text(
                        '${bakeries.length} places',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  for (var index = 0; index < bakeries.length; index++) ...[
                    _BakeryCard(
                      bakery: bakeries[index],
                      placeholderColor:
                          _coverColors[index % _coverColors.length],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              BakeryMenuPage(bakery: bakeries[index]),
                        ),
                      ),
                    ),
                    if (index < bakeries.length - 1)
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
                  '18 km',
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
                    'Search bakeries, cakes, pastries...',
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

class _BakeryCard extends StatelessWidget {
  const _BakeryCard({
    required this.bakery,
    required this.placeholderColor,
    required this.onTap,
  });

  final BakeryShop bakery;
  final Color placeholderColor;
  final VoidCallback onTap;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;

  @override
  Widget build(BuildContext context) {
    final isOpen = bakery.status == BakeryStatus.open;
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
                  if (!isOpen)
                    ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
                  if (bakery.offer != null)
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
                          bakery.offer!,
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
                  if (!isOpen)
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
                        child: const Text(
                          'Closed right now',
                          style: TextStyle(
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
                          bakery.name,
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
                              bakery.rating.toStringAsFixed(1),
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
                    bakery.category,
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
                        bakery.deliveryTime,
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
                      Expanded(
                        child: Text(
                          '${bakery.distance} · ${bakery.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.circle,
                        color: isOpen
                            ? _green
                            : const Color(0xFF929892),
                        size: 7,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: isOpen ? _green : _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
    final imageUrl = bakery.coverImageUrl;
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            placeholderColor,
            Color.lerp(placeholderColor, const Color(0xFF30271F), 0.48)!,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -35,
            right: -20,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Icon(
            Icons.bakery_dining_rounded,
            size: 55,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ],
      ),
    );
  }
}
