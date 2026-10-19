class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.label,
    required this.priceInPaise,
    required this.available,
    this.mrpInPaise,
    this.discountPercent,
    this.sku,
    this.imageUrl,
    this.value,
    this.unit,
    this.quantity,
    this.stock,
  });

  final String id;
  final String productId;
  final String label;
  final int priceInPaise;
  final int? mrpInPaise;
  final int? discountPercent;
  final bool available;
  final String? sku;
  final String? imageUrl;
  final String? value;
  final String? unit;
  final double? quantity;
  final int? stock;
}
