import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../cart/presentation/cart_access_button.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../../product_details/models/product_variant.dart';
import '../../wishlist/presentation/save_list_button.dart';
import '../data/local_store_session.dart';
import '../models/local_store.dart';

class CommonCategory {
  const CommonCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final IconData icon;
}

class _BackendLocalStoreCatalog {
  const _BackendLocalStoreCatalog({
    required this.categories,
    required this.products,
  });

  final List<CommonCategory> categories;
  final List<StoreProduct> products;
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.description,
    required this.packSize,
    required this.price,
    required this.mrp,
    required this.discount,
    required this.rating,
    required this.available,
    this.serviceType = 'local_store',
    this.imageUrl,
    this.badge,
    this.variants = const [],
    this.isBackendData = false,
  });

  final String id;
  final String storeId;
  final String categoryId;
  final String name;
  final String brand;
  final String description;
  final String packSize;
  final double price;
  final double mrp;
  final int discount;
  final double rating;
  final bool available;
  final String serviceType;
  final String? imageUrl;
  final String? badge;
  final List<ProductVariant> variants;
  final bool isBackendData;
}

const commonLocalStoreCategories = [
  CommonCategory(id: 'atta', name: 'Atta', icon: Icons.grain_rounded),
  CommonCategory(id: 'rice', name: 'Rice', icon: Icons.rice_bowl_rounded),
  CommonCategory(id: 'dal', name: 'Dal', icon: Icons.soup_kitchen_rounded),
  CommonCategory(id: 'biscuits', name: 'Biscuits', icon: Icons.cookie_rounded),
  CommonCategory(
    id: 'noodles',
    name: 'Noodles',
    icon: Icons.ramen_dining_rounded,
  ),
  CommonCategory(id: 'snacks', name: 'Snacks', icon: Icons.fastfood_rounded),
  CommonCategory(
    id: 'cooking-oil',
    name: 'Cooking Oil',
    icon: Icons.water_drop_rounded,
  ),
  CommonCategory(
    id: 'spices',
    name: 'Spices',
    icon: Icons.local_fire_department_rounded,
  ),
  CommonCategory(
    id: 'beverages',
    name: 'Beverages',
    icon: Icons.local_cafe_rounded,
  ),
  CommonCategory(id: 'dairy', name: 'Dairy', icon: Icons.icecream_rounded),
];

const sampleLocalStoreProducts = [
  StoreProduct(
    id: 'slgs-ashirvad-atta',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'atta',
    name: 'Ashirvad Atta',
    brand: 'Aashirvaad',
    description: 'Whole wheat flour for everyday meals',
    packSize: '',
    price: 70,
    mrp: 80,
    discount: 13,
    rating: 4.6,
    available: true,
    variants: [
      ProductVariant(
        id: '1-kg',
        productId: 'slgs-ashirvad-atta',
        label: '1 KG',
        priceInPaise: 7000,
        mrpInPaise: 8000,
        discountPercent: 13,
        available: true,
        sku: 'DEMO-ATTA-1KG',
      ),
      ProductVariant(
        id: '2-kg',
        productId: 'slgs-ashirvad-atta',
        label: '2 KG',
        priceInPaise: 13500,
        mrpInPaise: 15000,
        discountPercent: 10,
        available: false,
        sku: 'DEMO-ATTA-2KG',
      ),
      ProductVariant(
        id: '5-kg',
        productId: 'slgs-ashirvad-atta',
        label: '5 KG',
        priceInPaise: 31000,
        mrpInPaise: 34000,
        discountPercent: 9,
        available: true,
        sku: 'DEMO-ATTA-5KG',
      ),
    ],
  ),
  StoreProduct(
    id: 'slgs-maggi',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'noodles',
    name: '2-Minute Noodles',
    brand: 'Maggi',
    description: 'Masala instant noodles',
    packSize: '70 g',
    price: 14,
    mrp: 15,
    discount: 7,
    rating: 4.5,
    available: true,
    badge: 'Bestseller',
  ),
  StoreProduct(
    id: 'slgs-yippee',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'noodles',
    name: 'Magic Masala Noodles',
    brand: 'Sunfeast YiPPee!',
    description: 'Instant noodles with masala',
    packSize: '70 g',
    price: 14,
    mrp: 15,
    discount: 7,
    rating: 4.4,
    available: true,
  ),
  StoreProduct(
    id: 'slgs-waiwai',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'noodles',
    name: 'Wai Wai Noodles',
    brand: 'Wai Wai',
    description: 'Ready-to-eat chicken flavour noodles',
    packSize: '75 g',
    price: 20,
    mrp: 22,
    discount: 9,
    rating: 4.3,
    available: true,
  ),
  StoreProduct(
    id: 'slgs-marie',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'biscuits',
    name: 'Marie Gold',
    brand: 'Britannia',
    description: 'Light, crisp tea-time biscuits',
    packSize: '250 g',
    price: 38,
    mrp: 40,
    discount: 5,
    rating: 4.5,
    available: true,
    badge: 'Popular',
  ),
  StoreProduct(
    id: 'slgs-goodday',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'biscuits',
    name: 'Good Day Butter',
    brand: 'Britannia',
    description: 'Crunchy butter cookies',
    packSize: '200 g',
    price: 38,
    mrp: 40,
    discount: 5,
    rating: 4.6,
    available: true,
  ),
  StoreProduct(
    id: 'slgs-rice',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'rice',
    name: 'Classic Basmati Rice',
    brand: 'India Gate',
    description: 'Long-grain aromatic basmati rice',
    packSize: '1 kg',
    price: 149,
    mrp: 175,
    discount: 15,
    rating: 4.6,
    available: true,
  ),
  StoreProduct(
    id: 'slgs-toor-dal',
    storeId: 'sri-lakshmi-general-store',
    categoryId: 'dal',
    name: 'Toor Dal',
    brand: 'Local Select',
    description: 'Cleaned and polished everyday dal',
    packSize: '1 kg',
    price: 155,
    mrp: 170,
    discount: 9,
    rating: 4.2,
    available: true,
  ),
  StoreProduct(
    id: 'vs-maggi',
    storeId: 'venkateswara-stores',
    categoryId: 'noodles',
    name: '2-Minute Noodles',
    brand: 'Maggi',
    description: 'Masala instant noodles',
    packSize: '70 g',
    price: 15,
    mrp: 15,
    discount: 0,
    rating: 4.5,
    available: true,
  ),
  StoreProduct(
    id: 'vs-topramen',
    storeId: 'venkateswara-stores',
    categoryId: 'noodles',
    name: 'Smoodles Masala',
    brand: 'Top Ramen',
    description: 'Instant noodles with a savoury masala taste',
    packSize: '70 g',
    price: 13,
    mrp: 15,
    discount: 13,
    rating: 4.1,
    available: true,
  ),
  StoreProduct(
    id: 'vs-oreo',
    storeId: 'venkateswara-stores',
    categoryId: 'biscuits',
    name: 'Original Chocolate Creme',
    brand: 'Oreo',
    description: 'Chocolate cookies with vanilla creme',
    packSize: '120 g',
    price: 30,
    mrp: 33,
    discount: 9,
    rating: 4.6,
    available: true,
  ),
  StoreProduct(
    id: 'vs-sonamasoori',
    storeId: 'venkateswara-stores',
    categoryId: 'rice',
    name: 'Sona Masoori Rice',
    brand: 'Local Select',
    description: 'Light everyday rice, locally sourced',
    packSize: '5 kg',
    price: 345,
    mrp: 375,
    discount: 8,
    rating: 4.3,
    available: true,
  ),
  StoreProduct(
    id: 'vs-moongdal',
    storeId: 'venkateswara-stores',
    categoryId: 'dal',
    name: 'Moong Dal',
    brand: 'Local Select',
    description: 'Split yellow moong dal',
    packSize: '1 kg',
    price: 139,
    mrp: 155,
    discount: 10,
    rating: 4.2,
    available: true,
  ),
  StoreProduct(
    id: 'sb-maggi',
    storeId: 'sai-balaji-supermarket',
    categoryId: 'noodles',
    name: '2-Minute Noodles',
    brand: 'Maggi',
    description: 'Masala instant noodles',
    packSize: '70 g',
    price: 14,
    mrp: 15,
    discount: 7,
    rating: 4.5,
    available: true,
  ),
  StoreProduct(
    id: 'sb-yippee',
    storeId: 'sai-balaji-supermarket',
    categoryId: 'noodles',
    name: 'Mood Masala Noodles',
    brand: 'Sunfeast YiPPee!',
    description: 'Masala noodles with a smooth, non-sticky texture',
    packSize: '70 g',
    price: 14,
    mrp: 15,
    discount: 7,
    rating: 4.4,
    available: true,
  ),
  StoreProduct(
    id: 'sb-hide-seek',
    storeId: 'sai-balaji-supermarket',
    categoryId: 'biscuits',
    name: 'Hide & Seek',
    brand: 'Parle',
    description: 'Chocolate chip cookies',
    packSize: '200 g',
    price: 48,
    mrp: 55,
    discount: 13,
    rating: 4.5,
    available: true,
  ),
  StoreProduct(
    id: 'sb-rice',
    storeId: 'sai-balaji-supermarket',
    categoryId: 'rice',
    name: 'Sona Masoori Rice',
    brand: 'Local Select',
    description: 'Everyday medium-grain rice',
    packSize: '5 kg',
    price: 329,
    mrp: 360,
    discount: 9,
    rating: 4.4,
    available: true,
    badge: 'Value pack',
  ),
  StoreProduct(
    id: 'sb-attapack',
    storeId: 'sai-balaji-supermarket',
    categoryId: 'atta',
    name: 'Whole Wheat Atta',
    brand: 'Aashirvaad',
    description: 'Stone-ground whole wheat flour',
    packSize: '5 kg',
    price: 289,
    mrp: 315,
    discount: 8,
    rating: 4.6,
    available: true,
  ),
  StoreProduct(
    id: 'sd-maggi',
    storeId: 'sri-durga-general-stores',
    categoryId: 'noodles',
    name: '2-Minute Noodles',
    brand: 'Maggi',
    description: 'Masala instant noodles',
    packSize: '70 g',
    price: 15,
    mrp: 15,
    discount: 0,
    rating: 4.4,
    available: true,
  ),
  StoreProduct(
    id: 'sd-waiwai',
    storeId: 'sri-durga-general-stores',
    categoryId: 'noodles',
    name: 'Wai Wai Noodles',
    brand: 'Wai Wai',
    description: 'Crunchy, ready-to-eat noodle snack',
    packSize: '75 g',
    price: 20,
    mrp: 22,
    discount: 9,
    rating: 4.3,
    available: true,
  ),
  StoreProduct(
    id: 'sd-goodday',
    storeId: 'sri-durga-general-stores',
    categoryId: 'biscuits',
    name: 'Good Day Butter',
    brand: 'Britannia',
    description: 'Crunchy butter cookies',
    packSize: '200 g',
    price: 40,
    mrp: 40,
    discount: 0,
    rating: 4.5,
    available: true,
  ),
];

class LocalStoreCatalogPage extends StatefulWidget {
  const LocalStoreCatalogPage({
    required this.store,
    super.key,
    this.categories = commonLocalStoreCategories,
    this.products = sampleLocalStoreProducts,
    this.initialCategoryId,
  });

  final LocalStore store;
  final List<CommonCategory> categories;
  final List<StoreProduct> products;
  final String? initialCategoryId;

  @override
  State<LocalStoreCatalogPage> createState() => _LocalStoreCatalogPageState();
}

class _LocalStoreCatalogPageState extends State<LocalStoreCatalogPage> {
  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;

  late String _selectedCategoryId;
  late Future<_BackendLocalStoreCatalog>? _backendCatalogFuture;

  @override
  void initState() {
    super.initState();
    LocalStoreSession.instance.select(widget.store);
    final api = CustomerApi.instance;
    _backendCatalogFuture = widget.store.isBackendData && api.isConfigured
        ? _loadBackendCatalog(api)
        : null;
    final initialCategoryIndex = widget.categories.indexWhere(
      (category) => category.id == widget.initialCategoryId,
    );
    _selectedCategoryId = initialCategoryIndex >= 0
        ? widget.categories[initialCategoryIndex].id
        : widget.categories.isEmpty
        ? ''
        : widget.categories.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final catalogFuture = _backendCatalogFuture;
    if (catalogFuture == null) {
      return _buildCatalog(
        widget.categories,
        widget.products,
        sourceLabel: 'Demo catalog',
      );
    }
    return FutureBuilder<_BackendLocalStoreCatalog>(
      future: catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: _page,
            body: const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
            bottomNavigationBar: const CartSummaryBar(),
          );
        }
        if (snapshot.hasError) {
          return _buildBackendCatalogError(snapshot.error);
        }
        final catalog = snapshot.data!;
        return _buildCatalog(
          catalog.categories,
          catalog.products,
          sourceLabel: 'Backend catalog',
        );
      },
    );
  }

  Widget _buildBackendCatalogError(Object? error) {
    return Scaffold(
      backgroundColor: _page,
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
                        'Could not load this store catalog.',
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
                          setState(() {
                            _backendCatalogFuture = _loadBackendCatalog(
                              CustomerApi.instance,
                            );
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry catalog'),
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

  Future<_BackendLocalStoreCatalog> _loadBackendCatalog(CustomerApi api) async {
    final categories = await api.getCategories(widget.store.id);
    final products = await api.getAllProducts(shopId: widget.store.id);
    final categoryIds = categories.map((category) => category.id).toSet();
    final hasUncategorizedProducts = products.any(
      (product) =>
          product.categoryId == null ||
          !categoryIds.contains(product.categoryId),
    );
    final mappedCategories = [
      ...categories.map(
        (category) => CommonCategory(
          id: category.id,
          name: category.name,
          icon: Icons.inventory_2_rounded,
        ),
      ),
      if (hasUncategorizedProducts)
        const CommonCategory(
          id: 'other',
          name: 'Other',
          icon: Icons.category_rounded,
        ),
    ];
    final mappedProducts = products
        .map(
          (product) => StoreProduct(
            id: product.id,
            storeId: product.shopId,
            categoryId:
                product.categoryId != null &&
                    categoryIds.contains(product.categoryId)
                ? product.categoryId!
                    : 'other',
                name: product.name,
                description: product.description,
            packSize: product.packSize ?? '',
            price: product.priceMinor / 100,
            mrp: (product.mrpMinor ?? product.priceMinor) / 100,
            discount: product.discountPercent,
            rating: product.rating ?? -1,
            available: product.available,
            serviceType: switch (product.partnerType) {
              'restaurant' => 'restaurant',
              'meat_shop' => 'meat',
              'bakery' => 'bakery',
              _ => 'local_store',
            },
            imageUrl: product.imageUrl,
            badge: product.badge,
            brand: product.brand ?? '',
            isBackendData: true,
          ),
        )
        .toList(growable: false);
    return _BackendLocalStoreCatalog(
      categories: mappedCategories,
      products: mappedProducts,
    );
  }

  Widget _buildCatalog(
    List<CommonCategory> categories,
    List<StoreProduct> products, {
    required String sourceLabel,
  }) {
    final selectedCategoryId =
        categories.any((category) => category.id == _selectedCategoryId)
        ? _selectedCategoryId
        : categories.isEmpty
        ? ''
        : categories.first.id;
    final visibleProducts = products
        .where(
          (product) =>
              product.storeId == widget.store.id &&
              product.categoryId == selectedCategoryId,
        )
        .toList();
    final selectedCategory = categories.where(
      (category) => category.id == selectedCategoryId,
    );
    final categoryName = selectedCategory.isEmpty
        ? 'Products'
        : selectedCategory.first.name;

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  sourceLabel,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            ),
            _buildToolbar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCategorySidebar(categories, selectedCategoryId),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 14, 18),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => StoreProductCard(
                                product: visibleProducts[index],
                                placeholderIndex: index,
                                storeName: widget.store.name,
                                relatedProducts: visibleProducts
                                    .where(
                                      (related) =>
                                          related.storeId ==
                                              visibleProducts[index].storeId &&
                                          related.categoryId ==
                                              visibleProducts[index]
                                                  .categoryId &&
                                          related.id !=
                                              visibleProducts[index].id,
                                    )
                                    .toList(),
                              ),
                              childCount: visibleProducts.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 288,
                                ),
                          ),
                        ),
                        if (visibleProducts.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  'No $categoryName available at this store yet.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 9, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              widget.store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.25,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded, color: _ink, size: 24),
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return SizedBox(
      height: 53,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        scrollDirection: Axis.horizontal,
        children: [
          _ToolbarPill(
            icon: Icons.tune_rounded,
            label: 'Filter',
            prominent: true,
          ),
          const SizedBox(width: 8),
          const _ToolbarPill(
            label: 'Sort By',
            icon: Icons.keyboard_arrow_down_rounded,
          ),
          const SizedBox(width: 8),
          const _ToolbarPill(
            label: 'Top Deals',
            icon: Icons.bolt_rounded,
            prominent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySidebar(
    List<CommonCategory> categories,
    String selectedCategoryId,
  ) {
    return SizedBox(
      width: 82,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 7, bottom: 10),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.id == selectedCategoryId;
          return InkWell(
            onTap: () => setState(() => _selectedCategoryId = category.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 10),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 62,
                    height: 65,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE9F1E7) : Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFBBD4B7)
                            : const Color(0xFFE9ECE7),
                      ),
                    ),
                    child: Icon(
                      category.icon,
                      color: selected ? _green : const Color(0xFF8B948C),
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? _ink : _muted,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolbarPill extends StatelessWidget {
  const _ToolbarPill({
    required this.label,
    required this.icon,
    this.prominent = false,
  });

  final String label;
  final IconData icon;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE5E9E3)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: prominent
                ? const Color(0xFF315DCE)
                : const Color(0xFF29342D),
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF29342D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreProductCard extends StatefulWidget {
  const StoreProductCard({
    super.key,
    required this.product,
    required this.placeholderIndex,
    required this.storeName,
    required this.relatedProducts,
  });

  final StoreProduct product;
  final int placeholderIndex;
  final String storeName;
  final List<StoreProduct> relatedProducts;

  @override
  State<StoreProductCard> createState() => _StoreProductCardState();
}

class _StoreProductCardState extends State<StoreProductCard> {
  static const _ink = AppTheme.primaryText;
  static const _muted = AppTheme.secondaryText;
  static const _imageColors = [
    [Color(0xFFE9D6B5), Color(0xFFD1B58A)],
    [Color(0xFFE1EAD8), Color(0xFFB9C8A8)],
    [Color(0xFFF0DFD2), Color(0xFFD2B4A0)],
    [Color(0xFFE3E6F1), Color(0xFFB7BED5)],
  ];

  StoreProduct get product => widget.product;
  int get placeholderIndex => widget.placeholderIndex;
  String get storeName => widget.storeName;
  List<StoreProduct> get relatedProducts => widget.relatedProducts;

  String? _selectedVariantId;

  @override
  void initState() {
    super.initState();
    _selectedVariantId = _defaultVariantId(product);
  }

  @override
  void didUpdateWidget(covariant StoreProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != product.id ||
        !_sameVariantIds(oldWidget.product.variants, product.variants)) {
      _selectedVariantId = _defaultVariantId(product);
    }
  }

  String? _defaultVariantId(StoreProduct item) {
    if (item.variants.isEmpty) return null;
    for (final variant in item.variants) {
      if (variant.available) return variant.id;
    }
    return item.variants.first.id;
  }

  bool _sameVariantIds(List<ProductVariant> first, List<ProductVariant> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id) return false;
    }
    return true;
  }

  ProductVariant? get _selectedVariant {
    for (final variant in product.variants) {
      if (variant.id == _selectedVariantId) return variant;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedVariant = _selectedVariant;
    final displayPrice = selectedVariant == null
        ? product.price
        : selectedVariant.priceInPaise / 100;
    final displayMrp = selectedVariant?.mrpInPaise == null
        ? product.mrp
        : selectedVariant!.mrpInPaise! / 100;
    final displayDiscount =
        selectedVariant?.discountPercent ?? product.discount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _openDetails(context),
                  child: _buildProductImage(),
                ),
                if (product.badge != null)
                  Positioned(
                    top: 6,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF54A8E3),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                      ),
                      child: Text(
                        product.badge!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.93),
                      shape: BoxShape.circle,
                    ),
                    child: SaveListButton(
                      product: _toDetails(product, const []),
                      size: 15,
                    ),
                  ),
                ),
                if (product.variants.isEmpty)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: CartProductControl(
                          available: product.available,
                          productId: product.id,
                          serviceType: product.serviceType,
                          merchantId: product.storeId,
                          categoryId: product.categoryId,
                          name: product.name,
                          description: product.isBackendData
                              ? product.description
                              : '${product.brand} · ${product.packSize} · '
                                    '${product.description}',
                          priceInPaise: (product.price * 100).round(),
                          imageUrl: product.imageUrl,
                          icon: Icons.inventory_2_rounded,
                          backendCatalogItem: product.isBackendData,
                          width: 96,
                          height: 31,
                          unavailableLabel: 'OUT OF STOCK',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        if (!product.isBackendData)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E9E3)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              product.variants.isNotEmpty
                  ? selectedVariant?.label ?? 'Select size'
                  : product.packSize,
              style: const TextStyle(
                color: _ink,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '₹${_formatPrice(displayPrice)}',
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            if (displayMrp > displayPrice)
              Text(
                '₹${_formatPrice(displayMrp)}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        if (displayDiscount > 0) ...[
          const SizedBox(height: 2),
          Text(
            '$displayDiscount% OFF',
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDetails(context),
          child: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (product.isBackendData && product.rating < 0)
          Text(
            product.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 9, height: 1.2),
          )
        else
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFF28A36A),
                size: 12,
              ),
              const SizedBox(width: 2),
              Text(
                product.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Color(0xFF328760),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  product.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              ),
            ],
          ),
        if (product.variants.isNotEmpty) ...[
          const SizedBox(height: 3),
          _buildVariantSelector(),
          const SizedBox(height: 3),
          _buildVariantCartControl(selectedVariant),
        ],
      ],
    );
  }

  Widget _buildVariantSelector() {
    return Wrap(
      spacing: 3,
      runSpacing: 0,
      children: [
        for (final variant in product.variants)
          ChoiceChip(
            label: Text(variant.label),
            selected: variant.id == _selectedVariantId,
            onSelected: (_) => setState(() => _selectedVariantId = variant.id),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 3),
            padding: EdgeInsets.zero,
            labelStyle: const TextStyle(fontSize: 9),
            selectedColor: const Color(0xFFE8F3E9),
            side: BorderSide(
              color: variant.id == _selectedVariantId
                  ? AppTheme.primaryGreen
                  : const Color(0xFFE5E9E3),
            ),
          ),
      ],
    );
  }

  Widget _buildVariantCartControl(ProductVariant? variant) {
    if (variant == null) return const SizedBox.shrink();
    return CartProductControl(
      available: variant.available,
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.storeId,
      productVariantId: variant.id,
      variantLabel: variant.label,
      categoryId: product.categoryId,
      name: product.name,
      description: '${product.brand} · ${variant.label} · ${product.description}',
      priceInPaise: variant.priceInPaise,
      imageUrl: variant.imageUrl ?? product.imageUrl,
      icon: Icons.inventory_2_rounded,
      backendCatalogItem: product.isBackendData,
      width: double.infinity,
      height: 29,
      unavailableLabel: 'OUT OF STOCK',
    );
  }

  Widget _buildProductImage() {
    final imageUrl = product.imageUrl;
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
    final colors = _imageColors[placeholderIndex % _imageColors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: 43,
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ProductDetailsPage(product: _toDetails(product, relatedProducts)),
      ),
    );
  }

  ProductDetailsProduct _toDetails(
    StoreProduct item,
    List<StoreProduct> related,
  ) {
    return ProductDetailsProduct(
      id: item.id,
      serviceType: item.serviceType,
      merchantId: item.storeId,
      merchantName: storeName,
      categoryId: item.categoryId,
      name: item.name,
      brand: item.brand,
      description: item.description,
      imageUrl: item.imageUrl,
      priceInPaise: (item.price * 100).round(),
      mrpInPaise: (item.mrp * 100).round(),
      discountPercent: item.discount,
      quantityLabel: item.packSize,
      rating: item.rating < 0 ? 0 : item.rating,
      available: item.available,
      icon: Icons.inventory_2_rounded,
      isBackendProduct: item.isBackendData,
      variants: item.variants,
      relatedProducts: related.map((relatedItem) {
        return ProductDetailsProduct(
          id: relatedItem.id,
          serviceType: relatedItem.serviceType,
          merchantId: relatedItem.storeId,
          merchantName: storeName,
          categoryId: relatedItem.categoryId,
          name: relatedItem.name,
          brand: relatedItem.brand,
          description: relatedItem.description,
          imageUrl: relatedItem.imageUrl,
          priceInPaise: (relatedItem.price * 100).round(),
          mrpInPaise: (relatedItem.mrp * 100).round(),
          discountPercent: relatedItem.discount,
          quantityLabel: relatedItem.packSize,
          rating: relatedItem.rating < 0 ? 0 : relatedItem.rating,
          available: relatedItem.available,
          icon: Icons.inventory_2_rounded,
          isBackendProduct: relatedItem.isBackendData,
          variants: relatedItem.variants,
        );
      }).toList(),
    );
  }

  String _formatPrice(double price) =>
      price.toStringAsFixed(price % 1 == 0 ? 0 : 2);
}
