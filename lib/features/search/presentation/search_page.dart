import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../product_details/data/product_availability_store.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = SearchIndex.search(
      _query,
      additionalResults: widget.additionalResults,
    );

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
                              onChanged: (value) =>
                                  setState(() => _query = value),
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
            Expanded(
              child: _query.trim().isEmpty
                  ? const _SearchMessage(
                      icon: Icons.search_rounded,
                      title: 'Search MyShopzy',
                      message: 'Find restaurants, shops and products near you.',
                    )
                  : results.isEmpty
                  ? const _SearchMessage(
                      icon: Icons.search_off_rounded,
                      title: 'No results found',
                      message: 'Try another name, product or category.',
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
                          final destination = widget.destinationBuilder?.call(
                            result,
                          );
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
