import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/product_details/models/product_variant.dart';

class CustomerApiException implements Exception {
  const CustomerApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int? statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class ApiShop {
  const ApiShop({
    required this.id,
    required this.name,
    required this.partnerType,
    this.partnerId,
    this.address,
    this.partnerName,
    this.storeOpen = true,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final String name;
  final String partnerType;
  final String? partnerId;
  final String? address;
  final String? partnerName;
  final bool storeOpen;
  final String? opensAt;
  final String? closesAt;

  factory ApiShop.fromJson(Map<String, dynamic> json) {
    return ApiShop(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      partnerType: _requiredString(json, 'partner_type'),
      partnerId: _optionalString(json['partner_id']),
      address: _optionalString(json['address']),
      partnerName: _optionalString(json['partner_name']),
      storeOpen: json['storeOpen'] is bool ? json['storeOpen'] as bool : true,
      opensAt: _optionalString(json['opensAt']),
      closesAt: _optionalString(json['closesAt']),
    );
  }
}

class ApiPartnerCategory {
  const ApiPartnerCategory({
    required this.partnerType,
    required this.displayName,
    required this.partnerCount,
  });

  final String partnerType;
  final String displayName;
  final int partnerCount;

  factory ApiPartnerCategory.fromJson(Map<String, dynamic> json) {
    return ApiPartnerCategory(
      partnerType: _requiredString(json, 'partner_type'),
      displayName: _requiredString(json, 'display_name'),
      partnerCount: _requiredInteger(json, 'partner_count', minimum: 1),
    );
  }
}

class ApiCategory {
  const ApiCategory({
    required this.id,
    required this.name,
    this.shopId,
    this.parentCategoryId,
  });

  final String id;
  final String name;
  final String? shopId;
  final String? parentCategoryId;

  factory ApiCategory.fromJson(Map<String, dynamic> json) {
    return ApiCategory(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      shopId: _optionalString(json['shop_id']),
      parentCategoryId: _optionalString(json['parent_category_id']),
    );
  }
}

class ApiProduct {
  const ApiProduct({
    required this.id,
    required this.shopId,
    required this.name,
    required this.description,
    required this.priceMinor,
    required this.currency,
    required this.available,
    this.categoryId,
    this.partnerType,
    this.shopName,
    this.imageUrl,
    this.thumbUrl,
    this.rating,
    this.mrpMinor,
    this.discountPercent = 0,
    this.badge,
    this.brand,
    this.packSize,
    this.produceType,
    this.storeOpen = true,
    this.opensAt,
    this.closesAt,
    this.variants = const [],
  });

  final String id;
  final String shopId;
  final String name;
  final String description;
  final int priceMinor;
  final String currency;
  final bool available;
  final String? categoryId;
  final String? partnerType;
  final String? shopName;
  final String? imageUrl;
  final String? thumbUrl;
  final double? rating;
  final int? mrpMinor;
  final int discountPercent;
  final String? badge;
  final String? brand;
  final String? packSize;
  final String? produceType;
  final bool storeOpen;
  final String? opensAt;
  final String? closesAt;
  final List<ProductVariant> variants;

  factory ApiProduct.fromJson(Map<String, dynamic> json) {
    final priceValue = json['price_minor'];
    final priceMinor = switch (priceValue) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };
    if (priceMinor == null || priceMinor < 0) {
      throw const FormatException('Invalid product price.');
    }
    if (json['is_available'] is! bool) {
      throw const FormatException('Invalid product availability.');
    }
    final attributes = _optionalObject(json['attributes']) ?? const {};
    final rawVariants = json['variants'];
    if (rawVariants != null && rawVariants is! List) {
      throw const FormatException('Invalid product variants.');
    }
    final mrpMinor = _optionalMinorMetadata(attributes, const [
      'mrp_minor',
      'mrpMinor',
    ]);
    final discountPercent = _optionalIntMetadata(attributes, const [
      'discount_percent',
      'discountPercent',
    ]);
    return ApiProduct(
      id: _requiredString(json, 'id'),
      shopId: _requiredString(json, 'shop_id'),
      name: _requiredString(json, 'name'),
      description: _optionalString(json['description']) ?? '',
      priceMinor: priceMinor,
      currency: _requiredString(json, 'currency'),
      available: json['is_available'] as bool,
      categoryId: _optionalString(json['category_id']),
      partnerType: _optionalString(json['partner_type']),
      shopName: _optionalString(json['shop_name']),
      imageUrl:
          _optionalString(json['image_url']) ??
          _optionalStringMetadata(attributes, const ['image_url', 'imageUrl']),
      thumbUrl:
          _optionalString(json['thumb_url']) ??
          _optionalStringMetadata(attributes, const ['thumb_url', 'thumbUrl']),
      rating: _optionalDoubleMetadata(attributes, const ['rating']),
      mrpMinor: mrpMinor,
      discountPercent:
          discountPercent != null &&
              discountPercent >= 0 &&
              discountPercent <= 100
          ? discountPercent
          : mrpMinor != null && mrpMinor > priceMinor
          ? ((mrpMinor - priceMinor) * 100 / mrpMinor).round()
          : 0,
      badge: _optionalStringMetadata(attributes, const ['badge']),
      brand: _optionalStringMetadata(attributes, const ['brand']),
      packSize: _optionalStringMetadata(attributes, const [
        'pack_size',
        'packSize',
      ]),
      produceType: _optionalStringMetadata(attributes, const [
        'produce_type',
        'produceType',
      ]),
      storeOpen: json['storeOpen'] is bool ? json['storeOpen'] as bool : true,
      opensAt: _optionalString(json['opensAt']),
      closesAt: _optionalString(json['closesAt']),
      variants: (rawVariants as List? ?? const [])
          .map((variant) {
            if (variant is! Map<String, dynamic>) {
              throw const FormatException('Invalid product variant.');
            }
            return _productVariantFromJson(
              variant,
              _requiredString(json, 'id'),
            );
          })
          .toList(growable: false),
    );
  }
}

class ApiCartQuote {
  const ApiCartQuote({
    required this.currency,
    required this.itemSubtotalMinor,
    required this.deliveryFeeMinor,
    required this.discountMinor,
    required this.totalMinor,
    required this.items,
    this.storeOpen = true,
    this.opensAt,
    this.closesAt,
  });

  final String currency;
  final int itemSubtotalMinor;
  final int deliveryFeeMinor;
  final int discountMinor;
  final int totalMinor;
  final List<ApiCartQuoteItem> items;
  final bool storeOpen;
  final String? opensAt;
  final String? closesAt;

  factory ApiCartQuote.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) throw const FormatException('Invalid quote items.');
    return ApiCartQuote(
      currency: _requiredString(json, 'currency'),
      itemSubtotalMinor: _requiredMinor(json, 'itemSubtotalMinor'),
      deliveryFeeMinor: _requiredMinor(json, 'deliveryFeeMinor'),
      discountMinor: _requiredMinor(json, 'discountMinor'),
      totalMinor: _requiredMinor(json, 'totalMinor'),
      storeOpen: json['storeOpen'] is bool ? json['storeOpen'] as bool : true,
      opensAt: _optionalString(json['opensAt']),
      closesAt: _optionalString(json['closesAt']),
      items: rawItems
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid quote item.');
            }
            return ApiCartQuoteItem.fromJson(item);
          })
          .toList(growable: false),
    );
  }
}

class ApiCartQuoteItem {
  const ApiCartQuoteItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.priceMinor,
    required this.lineTotalMinor,
    this.variantId,
    this.variantLabel,
  });

  final String productId;
  final String name;
  final int quantity;
  final int priceMinor;
  final int lineTotalMinor;
  final String? variantId;
  final String? variantLabel;

  factory ApiCartQuoteItem.fromJson(Map<String, dynamic> json) {
    final quantity = _requiredMinor(json, 'quantity');
    if (quantity < 1) throw const FormatException('Invalid quote quantity.');
    return ApiCartQuoteItem(
      productId: _requiredString(json, 'productId'),
      name: _requiredString(json, 'name'),
      quantity: quantity,
      priceMinor: _requiredMinor(json, 'priceMinor'),
      lineTotalMinor: _requiredMinor(json, 'lineTotalMinor'),
      variantId: _optionalString(json['variantId']),
      variantLabel: _optionalString(json['variantLabel']),
    );
  }
}

class ApiCartItem {
  const ApiCartItem({
    required this.productId,
    required this.variantId,
    required this.variantLabel,
    required this.shopId,
    required this.name,
    required this.quantity,
    required this.priceMinor,
    required this.currency,
    required this.available,
    this.sku,
  });

  final String productId;
  final String variantId;
  final String variantLabel;
  final String shopId;
  final String name;
  final int quantity;
  final int priceMinor;
  final String currency;
  final bool available;
  final String? sku;

  factory ApiCartItem.fromJson(Map<String, dynamic> json) {
    final quantity = _requiredMinor(json, 'quantity');
    if (quantity < 1) throw const FormatException('Invalid cart quantity.');
    if (json['available'] is! bool) {
      throw const FormatException('Invalid cart item availability.');
    }
    return ApiCartItem(
      productId: _requiredString(json, 'productId'),
      variantId: _requiredString(json, 'variantId'),
      variantLabel: _requiredString(json, 'variantLabel'),
      shopId: _requiredString(json, 'shopId'),
      name: _requiredString(json, 'name'),
      quantity: quantity,
      priceMinor: _requiredMinor(json, 'priceMinor'),
      currency: _requiredString(json, 'currency'),
      available: json['available'] as bool,
      sku: _optionalString(json['sku']),
    );
  }
}

class ApiCart {
  const ApiCart({required this.items, required this.itemSubtotalMinor});

  final List<ApiCartItem> items;
  final int itemSubtotalMinor;

  factory ApiCart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) throw const FormatException('Invalid cart items.');
    return ApiCart(
      items: rawItems
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid cart item.');
            }
            return ApiCartItem.fromJson(item);
          })
          .toList(growable: false),
      itemSubtotalMinor: _requiredMinor(json, 'itemSubtotalMinor'),
    );
  }
}

class ApiSavedAddress {
  const ApiSavedAddress({
    required this.id,
    required this.label,
    required this.address,
  });

  final String id;
  final String label;
  final Map<String, dynamic> address;

  String get formattedAddress {
    final value = address['formattedAddress'] ?? address['address'];
    return value is String ? value : '';
  }

  double? get latitude => _optionalDouble(address['latitude']);
  double? get longitude => _optionalDouble(address['longitude']);
  String? get pincode =>
      _optionalString(address['pincode'] ?? address['postalCode']);

  factory ApiSavedAddress.fromJson(Map<String, dynamic> json) {
    final snapshot = json['address_snapshot'];
    if (snapshot is! Map<String, dynamic> || snapshot.isEmpty) {
      throw const FormatException('Invalid saved address.');
    }
    return ApiSavedAddress(
      id: _requiredString(json, 'id'),
      label: _requiredString(json, 'label'),
      address: Map<String, dynamic>.unmodifiable(snapshot),
    );
  }
}

class ApiWishlistItem {
  const ApiWishlistItem({
    required this.productId,
    required this.shopId,
    required this.name,
    required this.description,
    required this.priceMinor,
    required this.currency,
    required this.available,
    required this.shopName,
  });

  final String productId;
  final String shopId;
  final String name;
  final String description;
  final int priceMinor;
  final String currency;
  final bool available;
  final String shopName;

  factory ApiWishlistItem.fromJson(Map<String, dynamic> json) {
    if (json['available'] is! bool) {
      throw const FormatException('Invalid wishlist availability.');
    }
    return ApiWishlistItem(
      productId: _requiredString(json, 'product_id'),
      shopId: _requiredString(json, 'shop_id'),
      name: _requiredString(json, 'name'),
      description: _optionalString(json['description']) ?? '',
      priceMinor: _requiredMinor(json, 'price_minor'),
      currency: _requiredString(json, 'currency'),
      available: json['available'] as bool,
      shopName: _requiredString(json, 'shop_name'),
    );
  }
}

class ApiCustomerProfile {
  const ApiCustomerProfile({
    required this.displayName,
    required this.email,
    required this.phone,
  });

  final String displayName;
  final String? email;
  final String? phone;

  factory ApiCustomerProfile.fromJson(Map<String, dynamic> json) {
    return ApiCustomerProfile(
      displayName: _requiredString(json, 'display_name'),
      email: _nullableString(json, 'email'),
      phone: _nullableString(json, 'phone'),
    );
  }
}

class ApiOrderResult {
  const ApiOrderResult({
    required this.orderId,
    required this.status,
    required this.currency,
    required this.itemSubtotalMinor,
    required this.deliveryFeeMinor,
    required this.discountMinor,
    required this.totalMinor,
    required this.itemCount,
  });

  final String orderId;
  final String status;
  final String currency;
  final int itemSubtotalMinor;
  final int deliveryFeeMinor;
  final int discountMinor;
  final int totalMinor;
  final int itemCount;

  factory ApiOrderResult.fromJson(Map<String, dynamic> json) {
    final status = _requiredString(json, 'status');
    if (status != 'placed') {
      throw const FormatException('Invalid order status.');
    }
    return ApiOrderResult(
      orderId: _requiredString(json, 'orderId'),
      status: status,
      currency: _requiredString(json, 'currency'),
      itemSubtotalMinor: _requiredMinor(json, 'itemSubtotalMinor'),
      deliveryFeeMinor: _requiredMinor(json, 'deliveryFeeMinor'),
      discountMinor: _requiredMinor(json, 'discountMinor'),
      totalMinor: _requiredMinor(json, 'totalMinor'),
      itemCount: _requiredInteger(json, 'items', minimum: 1),
    );
  }
}

class ServiceabilityResponse {
  const ServiceabilityResponse({
    required this.isDeliverable,
    required this.message,
  });

  final bool isDeliverable;
  final String message;

  factory ServiceabilityResponse.fromJson(Map<String, dynamic> json) {
    if (json['isDeliverable'] is! bool ||
        json['message'] is! String ||
        (json['message'] as String).trim().isEmpty) {
      throw const FormatException('Invalid serviceability response.');
    }
    return ServiceabilityResponse(
      isDeliverable: json['isDeliverable'] as bool,
      message: (json['message'] as String).trim(),
    );
  }
}

class ApiCustomerOrder {
  const ApiCustomerOrder({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.status,
    required this.currency,
    required this.itemsSubtotalMinor,
    required this.deliveryFeeMinor,
    required this.discountMinor,
    required this.totalMinor,
    required this.placedAt,
    required this.itemCount,
  });

  final String id;
  final String shopId;
  final String shopName;
  final String status;
  final String currency;
  final int itemsSubtotalMinor;
  final int deliveryFeeMinor;
  final int discountMinor;
  final int totalMinor;
  final String placedAt;
  final int itemCount;

  factory ApiCustomerOrder.fromJson(Map<String, dynamic> json) {
    return ApiCustomerOrder(
      id: _requiredString(json, 'id'),
      shopId: _requiredString(json, 'shop_id'),
      shopName: _requiredString(json, 'shop_name'),
      status: _requiredString(json, 'status'),
      currency: _requiredString(json, 'currency'),
      itemsSubtotalMinor: _requiredMinor(json, 'items_subtotal_minor'),
      deliveryFeeMinor: _requiredMinor(json, 'delivery_fee_minor'),
      discountMinor: _requiredMinor(json, 'discount_minor'),
      totalMinor: _requiredMinor(json, 'total_minor'),
      placedAt: _requiredString(json, 'placed_at'),
      itemCount: _requiredInteger(json, 'item_count', minimum: 0),
    );
  }
}

class ApiCustomerOrderItem {
  const ApiCustomerOrderItem({
    required this.name,
    required this.quantity,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
    required this.currency,
    this.sku,
    this.variantSnapshot,
  });

  final String name;
  final int quantity;
  final int unitPriceMinor;
  final int lineTotalMinor;
  final String currency;
  final String? sku;
  final Map<String, dynamic>? variantSnapshot;
  String? get variantLabel => _optionalString(variantSnapshot?['label']);

  factory ApiCustomerOrderItem.fromJson(Map<String, dynamic> json) {
    final rawVariant = json['variant_snapshot'];
    if (rawVariant != null && rawVariant is! Map<String, dynamic>) {
      throw const FormatException('Invalid order variant snapshot.');
    }
    return ApiCustomerOrderItem(
      name: _requiredString(json, 'product_name_snapshot'),
      quantity: _requiredInteger(json, 'quantity', minimum: 1),
      unitPriceMinor: _requiredMinor(json, 'unit_price_minor'),
      lineTotalMinor: _requiredMinor(json, 'line_total_minor'),
      currency: _requiredString(json, 'currency'),
      sku: _nullableString(json, 'sku_snapshot'),
      variantSnapshot: rawVariant == null
          ? null
          : Map<String, dynamic>.unmodifiable(
              rawVariant as Map<String, dynamic>,
            ),
    );
  }
}

class ApiCustomerOrderDetail extends ApiCustomerOrder {
  const ApiCustomerOrderDetail({
    required super.id,
    required super.shopId,
    required super.shopName,
    required super.status,
    required super.currency,
    required super.itemsSubtotalMinor,
    required super.deliveryFeeMinor,
    required super.discountMinor,
    required super.totalMinor,
    required super.placedAt,
    required this.deliveryAddressSnapshot,
    required this.items,
  }) : super(itemCount: items.length);

  final Map<String, dynamic> deliveryAddressSnapshot;
  final List<ApiCustomerOrderItem> items;

  factory ApiCustomerOrderDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawAddress = json['delivery_address_snapshot'];
    if (rawItems is! List ||
        rawAddress is! Map<String, dynamic> ||
        rawAddress.isEmpty) {
      throw const FormatException('Invalid order details.');
    }
    final order = ApiCustomerOrder.fromJson({
      ...json,
      'item_count': rawItems.length,
    });
    return ApiCustomerOrderDetail(
      id: order.id,
      shopId: order.shopId,
      shopName: order.shopName,
      status: order.status,
      currency: order.currency,
      itemsSubtotalMinor: order.itemsSubtotalMinor,
      deliveryFeeMinor: order.deliveryFeeMinor,
      discountMinor: order.discountMinor,
      totalMinor: order.totalMinor,
      placedAt: order.placedAt,
      deliveryAddressSnapshot: Map<String, dynamic>.unmodifiable(rawAddress),
      items: rawItems
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid order item.');
            }
            return ApiCustomerOrderItem.fromJson(item);
          })
          .toList(growable: false),
    );
  }
}

class ApiParcelBookingRequest {
  const ApiParcelBookingRequest({
    required this.pickupLocation,
    required this.dropLocation,
    required this.parcelType,
    required this.weightKg,
    this.instructions = '',
  });

  static const parcelTypes = [
    'Documents',
    'Food',
    'Clothing',
    'Electronics',
    'Other',
  ];

  final String pickupLocation;
  final String dropLocation;
  final String parcelType;
  final double weightKg;
  final String instructions;

  String? get validationError {
    if (pickupLocation.trim().isEmpty || dropLocation.trim().isEmpty) {
      return 'Enter both pickup and drop locations.';
    }
    if (pickupLocation.trim().length > 300 ||
        dropLocation.trim().length > 300) {
      return 'Locations must be 300 characters or fewer.';
    }
    if (!parcelTypes.contains(parcelType)) {
      return 'Select a supported parcel type.';
    }
    if (!weightKg.isFinite || weightKg <= 0 || weightKg > 20) {
      return 'Weight must be greater than 0 kg and no more than 20 kg.';
    }
    if ((weightKg * 1000 - (weightKg * 1000).round()).abs() > 1e-7) {
      return 'Weight can have up to 3 decimal places.';
    }
    if (instructions.length > 1000) {
      return 'Instructions must be 1000 characters or fewer.';
    }
    return null;
  }
}

class ApiParcelBooking {
  const ApiParcelBooking({
    required this.id,
    required this.pickupLocation,
    required this.dropLocation,
    required this.parcelType,
    required this.weightKg,
    required this.instructions,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String pickupLocation;
  final String dropLocation;
  final String parcelType;
  final double weightKg;
  final String instructions;
  final String status;
  final String createdAt;
  final String? updatedAt;

  factory ApiParcelBooking.fromJson(Map<String, dynamic> json) {
    final weightGrams = _requiredInteger(json, 'weight_grams', minimum: 1);
    if (weightGrams > 20000) {
      throw const FormatException('Invalid parcel weight.');
    }
    final parcelType = _requiredString(json, 'parcel_type');
    if (!ApiParcelBookingRequest.parcelTypes.contains(parcelType)) {
      throw const FormatException('Invalid parcel type.');
    }
    final instructions = json['instructions'];
    if (instructions is! String) {
      throw const FormatException('Invalid parcel instructions.');
    }
    return ApiParcelBooking(
      id: _requiredString(json, 'id'),
      pickupLocation: _requiredString(json, 'pickup_location'),
      dropLocation: _requiredString(json, 'drop_location'),
      parcelType: parcelType,
      weightKg: weightGrams / 1000,
      instructions: instructions,
      status: _requiredString(json, 'status'),
      createdAt: _requiredString(json, 'created_at'),
      updatedAt: _optionalString(json['updated_at']),
    );
  }
}

class CustomerApi {
  CustomerApi({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _httpClient = httpClient ?? http.Client();

  factory CustomerApi.fromEnvironment({http.Client? httpClient}) {
    return CustomerApi(
      baseUrl: const String.fromEnvironment('MYSHOPZY_API_BASE_URL'),
      httpClient: httpClient,
    );
  }

  static CustomerApi instance = CustomerApi.fromEnvironment();

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration timeout;
  String? _cartToken;
  Future<void>? _cartInitialization;
  bool _orderOutcomeUnknown = false;
  bool _parcelOutcomeUnknown = false;
  String? _customerAccessToken;

  bool get isConfigured => _baseUrl.isNotEmpty;
  bool get hasCartToken => _cartToken != null;
  bool get hasCustomerSession => _customerAccessToken != null;
  bool get orderOutcomeUnknown => _orderOutcomeUnknown;
  bool get parcelOutcomeUnknown => _parcelOutcomeUnknown;
  CustomerApiException get _unknownOrderOutcomeException =>
      const CustomerApiException(
        statusCode: null,
        code: 'ORDER_OUTCOME_UNKNOWN',
        message: 'The previous order outcome is still unknown.',
      );
  CustomerApiException get _unknownParcelOutcomeException =>
      const CustomerApiException(
        statusCode: null,
        code: 'PARCEL_OUTCOME_UNKNOWN',
        message: 'The parcel request outcome could not be confirmed. Check parcel history before trying again.',
      );

  Future<void> requestOtp({required String phoneNumber}) async {
    _customerAccessToken = null;
    final payload = await _request(
      'POST',
      '/auth/otp/request',
      body: {'phoneNumber': phoneNumber},
    );
    try {
      final result = _dataObject(payload);
      _requiredString(result, 'message');
      final expiresIn = _requiredInteger(result, 'expiresIn', minimum: 1);
      final resendAfter = _requiredInteger(result, 'resendAfter', minimum: 1);
      if (expiresIn > 5 * 60 || resendAfter > expiresIn) {
        throw const FormatException('Invalid OTP request response.');
      }
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    _customerAccessToken = null;
    final payload = await _request(
      'POST',
      '/auth/otp/verify',
      body: {'phoneNumber': phoneNumber, 'otp': otp},
    );
    try {
      final session = _dataObject(payload);
      final accessToken = _requiredString(session, 'accessToken');
      final tokenType = _requiredString(session, 'tokenType');
      final expiresIn = _requiredInteger(session, 'expiresIn', minimum: 1);
      if (tokenType != 'Bearer' || expiresIn > 15 * 60) {
        throw const FormatException('Invalid customer session.');
      }
      _customerAccessToken = accessToken;
    } on FormatException {
      throw _invalidResponse();
    }
  }

  void clearCustomerSession() {
    _customerAccessToken = null;
  }

  Future<List<ApiShop>> getShops({
    String? partnerType,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError.value(
        '$limit/$offset',
        'limit/offset',
        'Catalog pagination must use a limit from 1 to 100 and a '
            'non-negative offset.',
      );
    }
    final payload = await _request(
      'GET',
      '/shops',
      queryParameters: {
        'partnerType': ?partnerType,
        'q': ?_nonEmptyQuery(query),
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return _parseList(payload, ApiShop.fromJson);
  }

  Future<List<ApiPartnerCategory>> getPartnerCategories() async {
    final payload = await _request('GET', '/partner-categories');
    return _parseList(payload, ApiPartnerCategory.fromJson);
  }

  Future<List<ApiShop>> getAllShops({
    String? partnerType,
    String? query,
  }) async {
    const pageSize = 100;
    final shops = <ApiShop>[];
    var offset = 0;
    while (true) {
      final page = await getShops(
        partnerType: partnerType,
        query: query,
        limit: pageSize,
        offset: offset,
      );
      shops.addAll(page);
      if (page.length < pageSize) return shops;
      offset += page.length;
    }
  }

  Future<List<ApiCategory>> getCategories(String shopId) async {
    final payload = await _request('GET', '/shops/$shopId/categories');
    return _parseList(payload, ApiCategory.fromJson);
  }

  Future<List<ApiProduct>> getProducts({
    String? shopId,
    String? categoryId,
    String? partnerType,
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError.value(
        '$limit/$offset',
        'limit/offset',
        'Catalog pagination must use a limit from 1 to 100 and a '
            'non-negative offset.',
      );
    }
    final payload = await _request(
      'GET',
      '/products',
      queryParameters: {
        'shopId': ?shopId,
        'categoryId': ?categoryId,
        'partnerType': ?partnerType,
        'q': ?_nonEmptyQuery(query),
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return _parseList(payload, ApiProduct.fromJson);
  }

  Future<List<ApiProduct>> getAllProducts({
    String? shopId,
    String? categoryId,
    String? partnerType,
    String? query,
  }) async {
    const pageSize = 100;
    final products = <ApiProduct>[];
    var offset = 0;
    while (true) {
      final page = await getProducts(
        shopId: shopId,
        categoryId: categoryId,
        partnerType: partnerType,
        query: query,
        limit: pageSize,
        offset: offset,
      );
      products.addAll(page);
      if (page.length < pageSize) return products;
      offset += page.length;
    }
  }

  Future<ApiProduct> getProduct(String productId) async {
    final payload = await _request('GET', '/products/$productId');
    try {
      return ApiProduct.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<List<ApiSavedAddress>> getSavedAddresses() async {
    final payload = await _request('GET', '/me/addresses');
    return _parseList(payload, ApiSavedAddress.fromJson);
  }

  Future<ApiSavedAddress> createSavedAddress({
    required String label,
    required Map<String, Object?> address,
  }) async {
    final payload = await _request(
      'POST',
      '/me/addresses',
      body: {'label': label, 'address': address},
    );
    return _parseSavedAddress(payload);
  }

  Future<ApiSavedAddress> updateSavedAddress(
    String addressId, {
    required String label,
    required Map<String, Object?> address,
  }) async {
    final payload = await _request(
      'PATCH',
      '/me/addresses/$addressId',
      body: {'label': label, 'address': address},
    );
    return _parseSavedAddress(payload);
  }

  Future<void> deleteSavedAddress(String addressId) async {
    await _request('DELETE', '/me/addresses/$addressId');
  }

  Future<List<ApiWishlistItem>> getWishlist() async {
    final payload = await _request('GET', '/me/wishlist');
    return _parseList(payload, ApiWishlistItem.fromJson);
  }

  Future<void> addWishlistItem(String productId) async {
    final payload = await _request(
      'POST',
      '/me/wishlist/items',
      body: {'productId': productId},
    );
    try {
      final result = _dataObject(payload);
      if (_requiredString(result, 'productId') != productId ||
          result['saved'] != true) {
        throw const FormatException('Invalid wishlist result.');
      }
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<void> removeWishlistItem(String productId) async {
    await _request('DELETE', '/me/wishlist/items/$productId');
  }

  Future<ApiCustomerProfile> getProfile() async {
    final payload = await _request('GET', '/me/profile');
    return _parseCustomerProfile(payload);
  }

  Future<ApiCustomerProfile> updateProfile({
    String? displayName,
    String? email,
    String? phone,
    bool clearEmail = false,
    bool clearPhone = false,
  }) async {
    final body = <String, Object?>{
      'displayName': ?displayName,
      'email': ?email,
      'phone': ?phone,
    };
    if (clearEmail) body['email'] = null;
    if (clearPhone) body['phone'] = null;
    final payload = await _request('PATCH', '/me/profile', body: body);
    return _parseCustomerProfile(payload);
  }

  Future<void> ensureCart() async {
    if (_cartToken != null) return;
    final initializingCart = _cartInitialization ??= _createCart();
    try {
      await initializingCart;
    } finally {
      if (identical(_cartInitialization, initializingCart)) {
        _cartInitialization = null;
      }
    }
  }

  Future<void> _createCart() async {
    final payload = await _request('POST', '/carts', body: const {});
    try {
      final token = _requiredString(_dataObject(payload), 'cartToken');
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        throw const FormatException('Invalid cart token.');
      }
      _cartToken = token;
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<ApiCart> getCart() async {
    if (_orderOutcomeUnknown) throw _unknownOrderOutcomeException;
    await ensureCart();
    final payload = await _request('GET', '/cart', useCartToken: true);
    try {
      return ApiCart.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<int> addCartItem(
    String productId, {
    required String variantId,
    int quantity = 1,
  }) async {
    await ensureCart();
    final payload = await _request(
      'POST',
      '/cart/items',
      body: {
        'productId': productId,
        'variantId': variantId,
        'quantity': quantity,
      },
      useCartToken: true,
    );
    try {
      final item = _dataObject(payload);
      if (_requiredString(item, 'productId') != productId ||
          _requiredString(item, 'variantId') != variantId) {
        throw const FormatException(
          'Cart response product variant did not match.',
        );
      }
      return _requiredInteger(item, 'quantity', minimum: 1);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<int> updateCartItem(
    String productId,
    String variantId,
    int quantity,
  ) async {
    final payload = await _request(
      'PATCH',
      '/cart/items/$productId/$variantId',
      body: {'quantity': quantity},
      useCartToken: true,
    );
    try {
      return _requiredInteger(_dataObject(payload), 'quantity', minimum: 1);
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<void> removeCartItem(String productId, String variantId) async {
    await _request(
      'DELETE',
      '/cart/items/$productId/$variantId',
      useCartToken: true,
    );
  }

  Future<void> clearCart() async {
    await _request('DELETE', '/cart/items', useCartToken: true);
  }

  Future<ApiCartQuote> getCheckoutQuote() async {
    final payload = await _request(
      'POST',
      '/checkout/quote',
      body: const {},
      useCartToken: true,
    );
    try {
      return ApiCartQuote.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<ServiceabilityResponse> checkLocationServiceability(
    double latitude,
    double longitude,
    String pincode,
  ) async {
    final normalizedPincode = pincode.trim();
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !RegExp(r'^\d{6}$').hasMatch(normalizedPincode)) {
      throw const CustomerApiException(
        statusCode: null,
        code: 'INVALID_REQUEST',
        message: 'Enter a valid location and 6-digit pincode.',
      );
    }
    final payload = await _request(
      'POST',
      '/delivery/serviceability',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'pincode': normalizedPincode,
      },
    );
    try {
      return ServiceabilityResponse.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<ApiOrderResult> placeOrder(
    Map<String, Object?> deliveryAddress,
  ) async {
    if (_orderOutcomeUnknown) throw _unknownOrderOutcomeException;
    try {
      final payload = await _request(
        'POST',
        '/orders',
        body: {'deliveryAddress': deliveryAddress},
        useCartToken: true,
      );
      return ApiOrderResult.fromJson(_dataObject(payload));
    } on CustomerApiException catch (error) {
      if (error.code == 'REQUEST_TIMEOUT' ||
          error.code == 'NETWORK_ERROR' ||
          error.code == 'INVALID_RESPONSE' ||
          (error.statusCode != null && error.statusCode! >= 500)) {
        _orderOutcomeUnknown = true;
      }
      rethrow;
    } on FormatException {
      _orderOutcomeUnknown = true;
      throw _invalidResponse();
    }
  }

  Future<List<ApiCustomerOrder>> getOrders({
    int limit = 20,
    int offset = 0,
  }) async {
    final payload = await _request(
      'GET',
      '/me/orders',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    return _parseList(payload, ApiCustomerOrder.fromJson);
  }

  Future<ApiCustomerOrderDetail> getOrderDetails(String orderId) async {
    final payload = await _request('GET', '/me/orders/$orderId');
    try {
      return ApiCustomerOrderDetail.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<ApiParcelBooking> createParcelBooking(
    ApiParcelBookingRequest request,
  ) async {
    if (_parcelOutcomeUnknown) throw _unknownParcelOutcomeException;
    final validationError = request.validationError;
    if (validationError != null) {
      throw CustomerApiException(
        statusCode: null,
        code: 'INVALID_REQUEST',
        message: validationError,
      );
    }
    try {
      final payload = await _request(
        'POST',
        '/me/parcels',
        body: {
          'pickupLocation': request.pickupLocation.trim(),
          'dropLocation': request.dropLocation.trim(),
          'parcelType': request.parcelType,
          'weightKg': request.weightKg,
          'instructions': request.instructions.trim(),
        },
      );
      try {
        return ApiParcelBooking.fromJson(_dataObject(payload));
      } on FormatException {
        _parcelOutcomeUnknown = true;
        throw _invalidResponse();
      }
    } on CustomerApiException catch (error) {
      if (error.code == 'REQUEST_TIMEOUT' ||
          error.code == 'NETWORK_ERROR' ||
          error.code == 'INVALID_RESPONSE' ||
          (error.statusCode != null && error.statusCode! >= 500)) {
        _parcelOutcomeUnknown = true;
      }
      rethrow;
    }
  }

  Future<List<ApiParcelBooking>> getParcelBookings({
    int limit = 20,
    int offset = 0,
  }) async {
    final payload = await _request(
      'GET',
      '/me/parcels',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    return _parseList(payload, ApiParcelBooking.fromJson);
  }

  Future<ApiParcelBooking> getParcelBookingDetails(String bookingId) async {
    final payload = await _request('GET', '/me/parcels/$bookingId');
    try {
      return ApiParcelBooking.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  void clearCartToken() {
    _cartToken = null;
    _cartInitialization = null;
  }

  void close() {
    _httpClient.close();
  }

  CustomerApiException _invalidResponse() => const CustomerApiException(
    statusCode: null,
    code: 'INVALID_RESPONSE',
    message: 'The server returned an invalid response.',
  );

  ApiSavedAddress _parseSavedAddress(Object? payload) {
    try {
      return ApiSavedAddress.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  ApiCustomerProfile _parseCustomerProfile(Object? payload) {
    try {
      return ApiCustomerProfile.fromJson(_dataObject(payload));
    } on FormatException {
      throw _invalidResponse();
    }
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    bool useCartToken = false,
  }) async {
    if (!isConfigured) {
      throw const CustomerApiException(
        statusCode: null,
        code: 'API_NOT_CONFIGURED',
        message: 'Backend mode is not configured.',
      );
    }
    late final Uri uri;
    try {
      try {
        uri = Uri.parse('$_baseUrl/api/v1$path')
            .replace(queryParameters: queryParameters);
      } on FormatException {
        throw const CustomerApiException(
          statusCode: null,
          code: 'INVALID_BASE_URL',
          message: 'The configured backend URL is invalid.',
        );
      }
      if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
        throw const CustomerApiException(
          statusCode: null,
          code: 'INVALID_BASE_URL',
          message: 'The configured backend URL is invalid.',
        );
      }
      if (uri.scheme == 'http' && !_isLoopbackHost(uri.host)) {
        throw const CustomerApiException(
          statusCode: null,
          code: 'INSECURE_BASE_URL',
          message: 'Use HTTPS for non-local backend connections.',
        );
      }
      final headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (_customerAccessToken != null)
          'Authorization': 'Bearer $_customerAccessToken',
        if (useCartToken && _cartToken != null) 'X-Cart-Token': _cartToken!,
      };
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body);
      final response = await _httpClient
          .send(request)
          .timeout(timeout)
          .then(http.Response.fromStream)
          .timeout(timeout);
      Object? decoded;
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
        final errorObject = error is Map<String, dynamic> ? error : const {};
        final code = errorObject['code'];
        final message = errorObject['message'];
        throw CustomerApiException(
          statusCode: response.statusCode,
          code: code is String ? code : 'HTTP_ERROR',
          message: message is String
              ? message
              : _statusMessage(response.statusCode),
        );
      }
      return decoded;
    } on CustomerApiException {
      rethrow;
    } on TimeoutException {
      throw const CustomerApiException(
        statusCode: null,
        code: 'REQUEST_TIMEOUT',
        message: 'The server took too long to respond. Please try again.',
      );
    } on FormatException {
      throw const CustomerApiException(
        statusCode: null,
        code: 'INVALID_RESPONSE',
        message: 'The server returned an invalid response.',
      );
    } on Exception {
      throw const CustomerApiException(
        statusCode: null,
        code: 'NETWORK_ERROR',
        message: 'Could not connect to the server. Please try again.',
      );
    }
  }
}

bool _isLoopbackHost(String host) {
  final normalizedHost = host.toLowerCase();
  if (normalizedHost == 'localhost' || normalizedHost == '::1') return true;
  final octets = normalizedHost.split('.');
  return octets.length == 4 &&
      int.tryParse(octets.first) == 127 &&
      octets.every((octet) {
        final value = int.tryParse(octet);
        return value != null && value >= 0 && value <= 255;
      });
}

List<T> _parseList<T>(Object? payload, T Function(Map<String, dynamic>) parse) {
  if (payload is! Map<String, dynamic> || payload['data'] is! List) {
    throw const CustomerApiException(
      statusCode: null,
      code: 'INVALID_RESPONSE',
      message: 'The server returned an invalid response.',
    );
  }
  final data = payload['data'] as List;
  return data
      .map((item) {
        if (item is! Map<String, dynamic>) {
          throw const CustomerApiException(
            statusCode: null,
            code: 'INVALID_RESPONSE',
            message: 'The server returned an invalid response.',
          );
        }
        try {
          return parse(item);
        } on FormatException {
          throw const CustomerApiException(
            statusCode: null,
            code: 'INVALID_RESPONSE',
            message: 'The server returned an invalid response.',
          );
        }
      })
      .toList(growable: false);
}

Map<String, dynamic> _dataObject(Object? payload) {
  if (payload is! Map<String, dynamic> ||
      payload['data'] is! Map<String, dynamic>) {
    throw const CustomerApiException(
      statusCode: null,
      code: 'INVALID_RESPONSE',
      message: 'The server returned an invalid response.',
    );
  }
  return payload['data'] as Map<String, dynamic>;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

String? _optionalString(Object? value) => value is String ? value : null;

Map<String, dynamic>? _optionalObject(Object? value) {
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry(key.toString(), value));
}

ProductVariant _productVariantFromJson(
  Map<String, dynamic> json,
  String productId,
) {
  if (json['is_available'] is! bool) {
    throw const FormatException('Invalid variant availability.');
  }
  final quantity = _optionalDouble(json['quantity']);
  final stock = json['stock'] == null
      ? null
      : _requiredInteger(json, 'stock', minimum: 0);
  if (quantity == null || quantity <= 0) {
    throw const FormatException('Invalid variant quantity.');
  }
  return ProductVariant(
    id: _requiredString(json, 'id'),
    productId: productId,
    label: _requiredString(json, 'label'),
    priceInPaise: _requiredMinor(json, 'price_minor'),
    available: json['is_available'] as bool,
    sku: _nullableString(json, 'sku'),
    unit: _requiredString(json, 'unit'),
    quantity: quantity,
    stock: stock,
  );
}

String? _optionalStringMetadata(
  Map<String, dynamic> metadata,
  List<String> keys,
) {
  for (final key in keys) {
    final value = _optionalString(metadata[key])?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

int? _optionalMinorMetadata(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    final parsed = switch (value) {
      int number => number,
      String number => int.tryParse(number),
      _ => null,
    };
    if (parsed != null && parsed >= 0) return parsed;
  }
  return null;
}

int? _optionalIntMetadata(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    final parsed = switch (value) {
      int number => number,
      String number => int.tryParse(number),
      _ => null,
    };
    if (parsed != null) return parsed;
  }
  return null;
}

double? _optionalDoubleMetadata(
  Map<String, dynamic> metadata,
  List<String> keys,
) {
  for (final key in keys) {
    final parsed = _optionalDouble(metadata[key]);
    if (parsed != null && parsed >= 0 && parsed <= 5) return parsed;
  }
  return null;
}

double? _optionalDouble(Object? value) {
  final number = switch (value) {
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('Invalid $key.');
  }
  return value as String?;
}

String? _nonEmptyQuery(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _requiredMinor(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = switch (value) {
    int amount => amount,
    String amount => int.tryParse(amount),
    _ => null,
  };
  if (parsed == null || parsed < 0) {
    throw FormatException('Invalid $key.');
  }
  return parsed;
}

int _requiredInteger(
  Map<String, dynamic> json,
  String key, {
  required int minimum,
}) {
  final value = json[key];
  final parsed = switch (value) {
    int number => number,
    String number => int.tryParse(number),
    _ => null,
  };
  if (parsed == null || parsed < minimum) {
    throw FormatException('Invalid $key.');
  }
  return parsed;
}

String _statusMessage(int statusCode) {
  return switch (statusCode) {
    401 => 'Customer authentication is required to access your account or submit a parcel request.',
    404 => 'The requested item was not found.',
    409 => 'The cart or product changed. Review your cart and try again.',
    503 => 'The service is temporarily unavailable. Please try again later.',
    _ => 'The request could not be completed. Please try again.',
  };
}
