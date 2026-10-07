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

  bool get isProductResult => switch (type) {
    SearchResultType.restaurantProduct ||
    SearchResultType.bakeryProduct ||
    SearchResultType.storeProduct ||
    SearchResultType.meatProduct ||
    SearchResultType.produceProduct ||
    SearchResultType.homeRestaurantProduct ||
    SearchResultType.homeStoreProduct => true,
    _ => false,
  };

  String? get serviceTypeForAvailability => switch (type) {
    SearchResultType.restaurantProduct ||
    SearchResultType.homeRestaurantProduct => 'restaurant',
    SearchResultType.bakeryProduct => 'bakery',
    SearchResultType.storeProduct ||
    SearchResultType.homeStoreProduct => 'local_store',
    SearchResultType.meatProduct => 'meat',
    SearchResultType.produceProduct => 'vegetables_fruits',
    _ => null,
  };
}
