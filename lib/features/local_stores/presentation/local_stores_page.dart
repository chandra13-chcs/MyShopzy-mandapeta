import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';

export '../models/local_store.dart';

import '../data/local_store_session.dart';
import '../models/local_store.dart';
import 'local_store_catalog_page.dart';

class LocalStoresPage extends StatefulWidget {
  const LocalStoresPage({
    super.key,
    List<LocalStore>? stores,
    this.initialCategoryId,
  }) : stores = stores ?? sampleLocalStores,
       useDefaultStores = stores == null;

  final List<LocalStore> stores;
  final bool useDefaultStores;
  final String? initialCategoryId;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;
  static const _coverColors = [
    Color(0xFF69805D),
    Color(0xFFAF8751),
    Color(0xFF596F68),
    Color(0xFF887353),
  ];

  @override
  State<LocalStoresPage> createState() => _LocalStoresPageState();
}

class _LocalStoresPageState extends State<LocalStoresPage> {
  static const _ink = LocalStoresPage._ink;
  static const _muted = LocalStoresPage._muted;
  static const _green = LocalStoresPage._green;
  static const _page = LocalStoresPage._page;

  late final Future<List<ApiShop>>? _storesFuture;

  @override
  void initState() {
    super.initState();
    final api = CustomerApi.instance;
    _storesFuture = api.isConfigured && widget.useDefaultStores
        ? api.getShops(partnerType: 'grocery')
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final storesFuture = _storesFuture;
    if (storesFuture == null) {
      return _buildPage(
        widget.stores,
        sourceLabel: 'Demo catalog · sample shops and details',
      );
    }
    return FutureBuilder<List<ApiShop>>(
      future: storesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: _page,
            body: const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return _buildPage(
            widget.stores,
            sourceLabel: 'Demo catalog · backend unavailable',
          );
        }
        final stores = snapshot.data!
            .map(
              (shop) => LocalStore(
                id: shop.id,
                name: shop.name,
                rating: 0,
                deliveryTime: 'Not provided',
                distance: '—',
                locality: shop.address ?? 'Address not provided',
                isOpen: false,
                isBackendData: true,
              ),
            )
            .toList(growable: false);
        return _buildPage(stores, sourceLabel: 'Backend catalog');
      },
    );
  }

  Widget _buildPage(List<LocalStore> stores, {required String sourceLabel}) {
    final nearbyStores = stores.any((store) => store.isBackendData)
        ? stores
        : eligibleLocalStores(stores);
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(
              context,
              showRadius: !stores.any((store) => store.isBackendData),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 19, 16, 24),
                children: [
                  Text(
                    sourceLabel,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Stores near you',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      Text(
                        '${nearbyStores.length} places',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  for (var index = 0; index < nearbyStores.length; index++) ...[
                    _StoreCard(
                      store: nearbyStores[index],
                      recommended: !nearbyStores[index].isBackendData &&
                          index == 0,
                      placeholderColor: LocalStoresPage._coverColors[
                          index % LocalStoresPage._coverColors.length],
                      onTap: () {
                        final store = nearbyStores[index];
                        LocalStoreSession.instance.select(store);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => LocalStoreCatalogPage(
                              store: store,
                              initialCategoryId: widget.initialCategoryId,
                            ),
                          ),
                        );
                      },
                    ),
                    if (index < nearbyStores.length - 1)
                      const SizedBox(height: 14),
                  ],
                  if (nearbyStores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('No stores available.')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool showRadius}) {
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
              if (showRadius)
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
                    'Search local stores, products...',
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

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.recommended,
    required this.placeholderColor,
    required this.onTap,
  });

  final LocalStore store;
  final bool recommended;
  final Color placeholderColor;
  final VoidCallback onTap;

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;

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
                  if (!store.isOpen && !store.isBackendData)
                    ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
                  if (store.offer != null)
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
                          store.offer!,
                          style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  if (recommended)
                    Positioned(
                      bottom: 11,
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
                        child: const Text(
                          'Recommended',
                          style: TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
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
                  if (!store.isOpen && !store.isBackendData)
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
                          store.name,
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
                      if (!store.isBackendData)
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
                              store.rating.toStringAsFixed(1),
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
                        store.deliveryTime,
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
                          '${store.distance} · ${store.locality}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.circle,
                        color: store.isOpen ? _green : const Color(0xFF929892),
                        size: 7,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.isBackendData
                            ? 'Hours not provided'
                            : store.isOpen
                            ? 'Open'
                            : 'Closed',
                        style: TextStyle(
                          color: store.isOpen ? _green : _muted,
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
    final imageUrl = store.imageUrl;
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
            Color.lerp(placeholderColor, const Color(0xFF1D2A20), 0.5)!,
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
            Icons.storefront_rounded,
            size: 54,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ],
      ),
    );
  }
}
