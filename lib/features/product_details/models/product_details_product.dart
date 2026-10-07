import 'package:flutter/material.dart';

class ProductDetailsProduct {
  const ProductDetailsProduct({
    required this.id,
    required this.serviceType,
    required this.name,
    required this.icon,
    required this.available,
    this.merchantId,
    this.merchantName,
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
    this.relatedProducts = const [],
  });

  final String id;
  final String serviceType;
  final String name;
  final IconData icon;
  final bool available;
  final String? merchantId;
  final String? merchantName;
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
  final List<ProductDetailsProduct> relatedProducts;
}
