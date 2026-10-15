import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../local_stores/presentation/local_store_catalog_page.dart';
import 'chicken_page.dart';
import 'mutton_page.dart';

class MeatPage extends StatelessWidget {
  const MeatPage({super.key});

  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  const Text(
                    'Meat',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Fresh cuts from trusted local shops',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Demo chicken and mutton categories',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  _MeatCategoryCard(
                    title: 'Chicken',
                    subtitle: 'Fresh cuts for every meal',
                    icon: Icons.lunch_dining_rounded,
                    background: const Color(0xFFF4E8D8),
                    accent: const Color(0xFF93623F),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const ChickenPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MeatCategoryCard(
                    title: 'Mutton',
                    subtitle: 'Carefully selected premium cuts',
                    icon: Icons.set_meal_rounded,
                    background: const Color(0xFFF0E3DF),
                    accent: const Color(0xFF9B5145),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const MuttonPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _BackendMeatCatalog(),
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
                    'Search meat and fresh cuts...',
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

class _MeatCategoryCard extends StatelessWidget {
  const _MeatCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 164,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -39,
                child: Container(
                  width: 184,
                  height: 184,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                ),
              ),
              Positioned(
                right: 13,
                top: 18,
                bottom: 18,
                child: Container(
                  width: 134,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, color: accent, size: 70),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 144, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Shop now',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: accent,
                          size: 15,
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
    );
  }

}

class _BackendMeatCatalog extends StatefulWidget {
  const _BackendMeatCatalog();

  @override
  State<_BackendMeatCatalog> createState() => _BackendMeatCatalogState();
}

class _BackendMeatCatalogState extends State<_BackendMeatCatalog> {
  List<ApiProduct> _products = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (CustomerApi.instance.isConfigured) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _products = const [];
    });
    try {
      final products = await CustomerApi.instance.getAllProducts(
        partnerType: 'meat_shop',
      );
      if (mounted) {
        setState(() {
          _products = products;
          _loading = false;
        });
      }
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CustomerApi.instance.isConfigured) {
      return const Text(
        'Demo meat products · sample catalog',
        style: TextStyle(color: AppTheme.secondaryText, fontSize: 11),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFA85B5B), fontSize: 12),
          ),
          TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry meat catalog'),
          ),
        ],
      );
    }
    if (_products.isEmpty) {
      return const Text(
        'No live meat products are available right now.',
        style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
      );
    }
    return Column(
      key: const ValueKey('backend-meat-catalog'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live meat shop products',
          style: TextStyle(
            color: AppTheme.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'The catalog does not identify chicken versus mutton.',
          style: TextStyle(color: AppTheme.secondaryText, fontSize: 11),
        ),
        const SizedBox(height: 9),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            mainAxisExtent: 288,
          ),
          itemBuilder: (context, index) {
            final product = _products[index];
            return StoreProductCard(
              key: ValueKey('backend-meat-product-${product.id}'),
              product: StoreProduct(
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
                serviceType: 'meat',
                imageUrl: product.imageUrl,
                badge: product.badge,
                isBackendData: true,
              ),
              placeholderIndex: index,
              storeName: product.shopName ?? '',
              relatedProducts: const [],
            );
          },
        ),
      ],
    );
  }
}
