import 'package:flutter/material.dart';

import 'product_variant.dart';

class ProductDetailsProduct {
  const ProductDetailsProduct({
    required this.id,
    required this.serviceType,
    required this.name,
    required this.icon,
    required this.available,
    this.merchantId,
    this.merchantName,
    this.serviceVariant,
    this.categoryId,
    this.brand,
    this.description,
    this.imageUrl,
    this.priceInPaise,
    this.mrpInPaise,
    this.discountPercent,
    this.quantityLabel,
    this.rating,
    this.isVegetarian,
    this.isBackendProduct = false,
    this.variants = const [],
    this.relatedProducts = const [],
  });

  final String id;
  final String serviceType;
  final String name;
  final IconData icon;
  final bool available;
  final String? merchantId;
  final String? merchantName;
  final String? serviceVariant;
  final String? categoryId;
  final String? brand;
  final String? description;
  final String? imageUrl;
  final int? priceInPaise;
  final int? mrpInPaise;
  final int? discountPercent;
  final String? quantityLabel;
  final double? rating;
  final bool? isVegetarian;
  final bool isBackendProduct;
  final List<ProductVariant> variants;
  final List<ProductDetailsProduct> relatedProducts;
}
