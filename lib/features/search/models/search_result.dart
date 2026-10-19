import '../../product_details/models/product_variant.dart';

enum SearchResultType {
  restaurant,
  restaurantProduct,
  bakery,
  bakeryProduct,
  localStore,
  storeProduct,
  meatCategory,
  meatProduct,
  produceCategory,
  produceProduct,
  homeRestaurant,
  homeRestaurantProduct,
  homeStore,
  homeStoreProduct,
  backendShop,
  backendProduct,
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.displayName,
    required this.searchableText,
    this.subtitle,
    this.imageUrl,
    this.price,
    this.merchantId,
    this.merchantName,
    this.categoryId,
    this.available = true,
    this.isBackendData = false,
    this.partnerType,
    this.storeOpen = true,
    this.variants = const [],
  });

  final String id;
  final SearchResultType type;
  final String displayName;
  final String searchableText;
  final String? subtitle;
  final String? imageUrl;
  final double? price;
  final String? merchantId;
  final String? merchantName;
  final String? categoryId;
  final bool available;
  final bool isBackendData;
  final String? partnerType;
  final bool storeOpen;
  final List<ProductVariant> variants;

  bool get isProductResult => switch (type) {
    SearchResultType.restaurantProduct ||
    SearchResultType.bakeryProduct ||
    SearchResultType.storeProduct ||
    SearchResultType.meatProduct ||
    SearchResultType.produceProduct ||
    SearchResultType.homeRestaurantProduct ||
    SearchResultType.homeStoreProduct ||
    SearchResultType.backendProduct => true,
    _ => false,
  };

  String? get serviceTypeForAvailability => switch (type) {
    SearchResultType.restaurantProduct ||
    SearchResultType.homeRestaurantProduct => 'restaurant',
    SearchResultType.bakeryProduct => 'bakery',
    SearchResultType.storeProduct ||
    SearchResultType.homeStoreProduct => 'local_store',
    SearchResultType.backendProduct => switch (partnerType) {
      'restaurant' => 'restaurant',
      'grocery' => 'local_store',
      'meat_shop' => 'meat',
      _ => null,
    },
    SearchResultType.meatProduct => 'meat',
    SearchResultType.produceProduct => 'vegetables_fruits',
    _ => null,
  };
}
