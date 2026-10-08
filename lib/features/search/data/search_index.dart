import 'package:flutter/material.dart';

import '../../bakery/presentation/bakery_menu_page.dart';
import '../../bakery/presentation/bakery_page.dart';
import '../../local_stores/presentation/local_store_catalog_page.dart';
import '../../local_stores/data/local_store_session.dart';
import '../../local_stores/models/local_store.dart';
import '../../meat/presentation/chicken_page.dart';
import '../../meat/presentation/meat_catalog_page.dart';
import '../../meat/presentation/mutton_page.dart';
import '../../restaurants/presentation/restaurant_menu_page.dart';
import '../../restaurants/presentation/restaurants_page.dart';
import '../../product_details/presentation/product_details_page.dart';
import '../../vegetables_fruits/presentation/produce_catalog_page.dart';
import '../models/search_result.dart';

class SearchIndex {
  SearchIndex._();

  static final List<SearchResult> _results = _buildResults();

  static List<SearchResult> search(
    String query, {
    List<SearchResult> additionalResults = const [],
  }) {
    final normalizedQuery = query.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (normalizedQuery.isEmpty) return const [];

    final terms = normalizedQuery.split(' ');
    return [..._results, ...additionalResults]
        .where(
          (result) => terms.every(
            (term) => result.searchableText.toLowerCase().contains(term),
          ),
        )
        .toList(growable: false);
  }

  static Widget destinationFor(SearchResult result) {
    switch (result.type) {
      case SearchResultType.restaurant:
        final restaurant = sampleRestaurants.firstWhere(
          (item) => item.id == (result.merchantId ?? result.id),
        );
        return RestaurantMenuPage(
          restaurant: restaurant,
          categories: sampleRestaurantMenuCategories,
          menuItems: sampleRestaurantMenuItems
              .where((item) => item.restaurantId == restaurant.id)
              .toList(),
        );
      case SearchResultType.restaurantProduct:
        return ProductDetailsPage(product: productFor(result));
      case SearchResultType.bakery:
        final bakery = sampleBakeries.firstWhere(
          (item) => item.id == (result.merchantId ?? result.id),
        );
        return BakeryMenuPage(
          bakery: bakery,
          categories: sampleBakeryCategories,
          items: sampleBakeryMenuItems,
        );
      case SearchResultType.bakeryProduct:
        return ProductDetailsPage(product: productFor(result));
      case SearchResultType.localStore:
        final store = sampleLocalStores.firstWhere(
          (item) => item.id == (result.merchantId ?? result.id),
        );
        final categories = _categoriesWithFirst(
          commonLocalStoreCategories,
          result.categoryId,
        );
        return LocalStoreCatalogPage(
          store: store,
          categories: categories,
          products: sampleLocalStoreProducts,
        );
      case SearchResultType.storeProduct:
        return ProductDetailsPage(product: productFor(result));
      case SearchResultType.meatCategory:
        final isChicken = result.type == SearchResultType.meatProduct
            ? sampleChickenProducts.any((item) => item.id == result.id)
            : sampleChickenCategories.any((item) => item.id == result.id);
        final type = isChicken ? MeatType.chicken : MeatType.mutton;
        final categories = isChicken
            ? sampleChickenCategories
            : sampleMuttonCategories;
        final products = isChicken
            ? sampleChickenProducts
            : sampleMuttonProducts;
        final selectedCategoryId = result.categoryId ?? result.id;
        return MeatCatalogPage(
          title: isChicken ? 'Chicken' : 'Mutton',
          type: type,
          categories: _categoriesWithFirst(categories, selectedCategoryId),
          products: products,
        );
      case SearchResultType.meatProduct:
        return ProductDetailsPage(product: productFor(result));
      case SearchResultType.produceCategory:
        final category = commonProduceCategories.firstWhere(
          (item) => item.id == (result.categoryId ?? result.id),
        );
        return ProduceCatalogPage(
          type: category.type,
          categories: _categoriesWithFirst(
            commonProduceCategories,
            category.id,
          ),
          products: sampleProduceProducts,
        );
      case SearchResultType.produceProduct:
        return ProductDetailsPage(product: productFor(result));
      case SearchResultType.homeRestaurant:
      case SearchResultType.homeRestaurantProduct:
      case SearchResultType.homeStore:
      case SearchResultType.homeStoreProduct:
        throw StateError(
          'Home discovery results must use the HomePage destination adapter.',
        );
    }
  }

  static ProductDetailsProduct productFor(SearchResult result) {
    switch (result.type) {
      case SearchResultType.restaurantProduct:
        final item = sampleRestaurantMenuItems.firstWhere(
          (item) => item.id == result.id,
        );
        final restaurant = sampleRestaurants.firstWhere(
          (restaurant) => restaurant.id == item.restaurantId,
        );
        return ProductDetailsProduct(
          id: item.id,
          serviceType: 'restaurant',
          merchantId: item.restaurantId,
          merchantName: restaurant.name,
          categoryId: item.categoryId,
          name: item.name,
          description: item.description,
          imageUrl: item.imageUrl,
          priceInPaise: (item.price * 100).round(),
          available: item.available,
          icon: Icons.restaurant_rounded,
          isVegetarian: item.isVeg,
        );
      case SearchResultType.bakeryProduct:
        final item = sampleBakeryMenuItems.firstWhere(
          (item) => item.id == result.id,
        );
        final bakery = sampleBakeries.firstWhere(
          (bakery) => bakery.id == item.bakeryId,
        );
        return ProductDetailsProduct(
          id: item.id,
          serviceType: 'bakery',
          merchantId: item.bakeryId,
          merchantName: bakery.name,
          categoryId: item.categoryId,
          name: item.name,
          description: item.description,
          imageUrl: item.imageUrl,
          priceInPaise: (item.price * 100).round(),
          available: item.available,
          icon: Icons.bakery_dining_rounded,
          isVegetarian: item.foodType == BakeryFoodType.vegetarian,
        );
      case SearchResultType.storeProduct:
        final item = sampleLocalStoreProducts.firstWhere(
          (item) => item.id == result.id,
        );
        final store = sampleLocalStores.firstWhere(
          (store) => store.id == item.storeId,
        );
        LocalStoreSession.instance.select(store);
        return ProductDetailsProduct(
          id: item.id,
          serviceType: 'local_store',
          merchantId: item.storeId,
          merchantName: store.name,
          categoryId: item.categoryId,
          name: item.name,
          brand: item.brand,
          description: item.description,
          imageUrl: item.imageUrl,
          priceInPaise: (item.price * 100).round(),
          mrpInPaise: (item.mrp * 100).round(),
          discountPercent: item.discount,
          quantityLabel: item.packSize,
          rating: item.rating,
          available: item.available,
          icon: Icons.inventory_2_rounded,
        );
      case SearchResultType.meatProduct:
        final item = [
          ...sampleChickenProducts,
          ...sampleMuttonProducts,
        ].firstWhere((item) => item.id == result.id);
        final partner = sampleMeatPartners.firstWhere(
          (partner) => partner.id == item.partnerId,
        );
        return ProductDetailsProduct(
          id: item.id,
          serviceType: 'meat',
          merchantId: item.partnerId,
          merchantName: partner.name,
          categoryId: item.categoryId,
          name: item.name,
          description: '${item.description} · ${item.weight}',
          imageUrl: item.imageUrl,
          priceInPaise: (item.price * 100).round(),
          quantityLabel: item.weight,
          available: item.available,
          icon: Icons.set_meal_rounded,
          isVegetarian: false,
        );
      case SearchResultType.produceProduct:
        final item = sampleProduceProducts.firstWhere(
          (item) => item.id == result.id,
        );
        return ProductDetailsProduct(
          id: item.id,
          serviceType: 'vegetables_fruits',
          serviceVariant: item.type.name,
          categoryId: item.categoryId,
          name: item.name,
          imageUrl: item.imageUrl,
          priceInPaise: (item.price * 100).round(),
          mrpInPaise: (item.mrp * 100).round(),
          discountPercent: item.discount,
          quantityLabel: item.packSize,
          rating: item.rating,
          available: item.available,
          icon: item.type == ProduceType.fruit
              ? Icons.eco_rounded
              : Icons.grass_rounded,
          isVegetarian: true,
        );
      case SearchResultType.restaurant:
      case SearchResultType.bakery:
      case SearchResultType.localStore:
      case SearchResultType.meatCategory:
      case SearchResultType.produceCategory:
      case SearchResultType.homeRestaurant:
      case SearchResultType.homeRestaurantProduct:
      case SearchResultType.homeStore:
      case SearchResultType.homeStoreProduct:
        throw ArgumentError.value(
          result.type,
          'result.type',
          'A product search result is required.',
        );
    }
  }

  static List<T> _categoriesWithFirst<T>(
    List<T> categories,
    String? selectedId,
  ) {
    if (selectedId == null) return categories;
    final selectedIndex = categories.indexWhere(
      (category) => switch (category) {
        CommonCategory() => category.id == selectedId,
        MeatCategory() => category.id == selectedId,
        ProduceCategory() => category.id == selectedId,
        _ => false,
      },
    );
    if (selectedIndex < 0) return categories;
    return [
      categories[selectedIndex],
      ...categories.take(selectedIndex),
      ...categories.skip(selectedIndex + 1),
    ];
  }

  static List<SearchResult> _buildResults() {
    final results = <SearchResult>[];

    for (final restaurant in sampleRestaurants) {
      results.add(
        SearchResult(
          id: restaurant.id,
          type: SearchResultType.restaurant,
          displayName: restaurant.name,
          subtitle: '${restaurant.cuisine} · ${restaurant.location}',
          imageUrl: restaurant.coverImageUrl,
          merchantId: restaurant.id,
          merchantName: restaurant.name,
          searchableText:
              '${restaurant.name} ${restaurant.cuisine} ${restaurant.location}',
        ),
      );
    }
    for (final item in sampleRestaurantMenuItems) {
      final restaurant = sampleRestaurants.firstWhere(
        (entry) => entry.id == item.restaurantId,
      );
      final category = sampleRestaurantMenuCategories.firstWhere(
        (entry) => entry.id == item.categoryId,
      );
      results.add(
        SearchResult(
          id: item.id,
          type: SearchResultType.restaurantProduct,
          displayName: item.name,
          subtitle: '${restaurant.name} · ${category.name}',
          imageUrl: item.imageUrl,
          price: item.price,
          merchantId: restaurant.id,
          merchantName: restaurant.name,
          categoryId: item.categoryId,
          available: item.available,
          searchableText:
              '${item.name} ${item.description} ${category.name} ${restaurant.name} ${restaurant.cuisine}',
        ),
      );
    }

    for (final bakery in sampleBakeries) {
      results.add(
        SearchResult(
          id: bakery.id,
          type: SearchResultType.bakery,
          displayName: bakery.name,
          subtitle: '${bakery.category} · ${bakery.location}',
          imageUrl: bakery.coverImageUrl,
          merchantId: bakery.id,
          merchantName: bakery.name,
          searchableText:
              '${bakery.name} ${bakery.category} ${bakery.location}',
        ),
      );
    }
    for (final item in sampleBakeryMenuItems) {
      final bakery = sampleBakeries.firstWhere(
        (entry) => entry.id == item.bakeryId,
      );
      final category = sampleBakeryCategories.firstWhere(
        (entry) => entry.id == item.categoryId,
      );
      results.add(
        SearchResult(
          id: item.id,
          type: SearchResultType.bakeryProduct,
          displayName: item.name,
          subtitle: '${bakery.name} · ${category.name}',
          imageUrl: item.imageUrl,
          price: item.price,
          merchantId: bakery.id,
          merchantName: bakery.name,
          categoryId: item.categoryId,
          available: item.available,
          searchableText:
              '${item.name} ${item.description} ${category.name} ${bakery.name}',
        ),
      );
    }

    for (final store in sampleLocalStores) {
      results.add(
        SearchResult(
          id: store.id,
          type: SearchResultType.localStore,
          displayName: store.name,
          subtitle: store.locality,
          imageUrl: store.imageUrl,
          merchantId: store.id,
          merchantName: store.name,
          searchableText: '${store.name} ${store.locality}',
        ),
      );
    }
    for (final item in sampleLocalStoreProducts) {
      final store = sampleLocalStores.firstWhere(
        (entry) => entry.id == item.storeId,
      );
      final category = commonLocalStoreCategories.firstWhere(
        (entry) => entry.id == item.categoryId,
      );
      results.add(
        SearchResult(
          id: item.id,
          type: SearchResultType.storeProduct,
          displayName: item.name,
          subtitle: '${store.name} · ${category.name}',
          imageUrl: item.imageUrl,
          price: item.price,
          merchantId: item.storeId,
          merchantName: store.name,
          categoryId: item.categoryId,
          available: item.available,
          searchableText:
              '${item.name} ${item.brand} ${item.description} ${item.packSize} ${category.name} ${store.name}',
        ),
      );
    }

    for (final category in sampleChickenCategories) {
      results.add(_meatCategoryResult(category));
    }
    for (final item in sampleChickenProducts) {
      results.add(_meatProductResult(item));
    }
    for (final category in sampleMuttonCategories) {
      results.add(_meatCategoryResult(category));
    }
    for (final item in sampleMuttonProducts) {
      results.add(_meatProductResult(item));
    }

    for (final category in commonProduceCategories) {
      results.add(
        SearchResult(
          id: category.id,
          type: SearchResultType.produceCategory,
          displayName: category.name,
          subtitle: category.type == ProduceType.fruit
              ? 'Fruits'
              : 'Vegetables',
          categoryId: category.id,
          searchableText: '${category.name} ${category.type.name}',
        ),
      );
    }
    for (final item in sampleProduceProducts) {
      final category = commonProduceCategories.firstWhere(
        (entry) => entry.id == item.categoryId,
      );
      results.add(
        SearchResult(
          id: item.id,
          type: SearchResultType.produceProduct,
          displayName: item.name,
          subtitle: '${category.name} · ${item.type.name}',
          imageUrl: item.imageUrl,
          price: item.price,
          categoryId: item.categoryId,
          available: item.available,
          searchableText:
              '${item.name} ${item.packSize} ${category.name} ${item.type.name}',
        ),
      );
    }

    return results;
  }

  static SearchResult _meatCategoryResult(MeatCategory category) {
    final isChicken = category.type == MeatType.chicken;
    return SearchResult(
      id: category.id,
      type: SearchResultType.meatCategory,
      displayName: category.name,
      subtitle: isChicken ? 'Chicken' : 'Mutton',
      categoryId: category.id,
      searchableText: '${category.name} ${isChicken ? 'Chicken' : 'Mutton'}',
    );
  }

  static SearchResult _meatProductResult(MeatProduct item) {
    final category = [
      ...sampleChickenCategories,
      ...sampleMuttonCategories,
    ].firstWhere((entry) => entry.id == item.categoryId);
    final partner = sampleMeatPartners.firstWhere(
      (entry) => entry.id == item.partnerId,
    );
    return SearchResult(
      id: item.id,
      type: SearchResultType.meatProduct,
      displayName: item.name,
      subtitle: '${partner.name} · ${category.name} · ${item.weight}',
      imageUrl: item.imageUrl,
      price: item.price,
      merchantId: partner.id,
      merchantName: partner.name,
      categoryId: item.categoryId,
      available: item.available,
      searchableText:
          '${item.name} ${item.description} ${item.weight} ${category.name} ${partner.name} ${item.type.name}',
    );
  }
}
