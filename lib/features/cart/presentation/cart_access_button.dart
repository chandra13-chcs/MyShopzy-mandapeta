 import 'package:flutter/material.dart';

import '../data/cart_store.dart';
 import '../../product_details/data/product_availability_store.dart';
 import 'cart_page.dart';

class CartAccessButton extends StatelessWidget {
  const CartAccessButton({super.key});

  static const _green = Color(0xFF2C7C65);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartStore.instance,
      builder: (context, child) {
        final totalQuantity = CartStore.instance.totalQuantity;
        return SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const CartPage(),
                    ),
                  ),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      color: _green,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (totalQuantity > 0)
                Positioned(
                  top: -3,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$totalQuantity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({super.key});

  static const _green = Color(0xFF2C7C65);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartStore.instance,
      builder: (context, child) {
        final totalQuantity = CartStore.instance.totalQuantity;
        if (totalQuantity == 0) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Material(
            color: Colors.white,
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const CartPage(),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$totalQuantity '
                          '${totalQuantity == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        'VIEW CART',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CartNavigationIcon extends StatelessWidget {
  const CartNavigationIcon({super.key});

  static const _green = Color(0xFF2C7C65);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartStore.instance,
      builder: (context, child) {
        final totalQuantity = CartStore.instance.totalQuantity;
        return SizedBox(
          width: 30,
          height: 26,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 23),
              if (totalQuantity > 0)
                Positioned(
                  top: -4,
                  right: -5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '$totalQuantity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CartProductControl extends StatelessWidget {
  const CartProductControl({
    required this.productId,
    required this.serviceType,
    required this.name,
    required this.description,
    required this.priceInPaise,
    required this.icon,
    required this.available,
    super.key,
    this.merchantId,
    this.categoryId,
    this.imageUrl,
    this.width = 88,
    this.height = 34,
    this.unavailableLabel = 'OUT OF STOCK',
  });

  final String productId;
  final String serviceType;
  final String? merchantId;
  final String? categoryId;
  final String name;
  final String description;
  final int priceInPaise;
  final String? imageUrl;
  final IconData icon;
  final bool available;
  final double width;
  final double height;
  final String unavailableLabel;

  static const _green = Color(0xFF16834A);

  @override
  Widget build(BuildContext context) {
    final store = CartStore.instance;
    final availabilityStore = ProductAvailabilityStore.instance;
    return AnimatedBuilder(
      animation: availabilityStore,
      builder: (context, child) {
        final isAvailable = availabilityStore.isAvailable(
          productId: productId,
          serviceType: serviceType,
          merchantId: merchantId,
          defaultAvailable: available,
        );
        return AnimatedBuilder(
          animation: store,
          builder: (context, child) {
            final quantity = store.quantityFor(
              productId: productId,
              serviceType: serviceType,
              merchantId: merchantId,
            );
            return SizedBox(
              width: width,
              height: height,
              child: quantity == 0
                  ? _buildAddButton(store, isAvailable)
                  : _buildQuantityControl(
                      context,
                      store,
                      quantity,
                      isAvailable,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddButton(CartStore store, bool isAvailable) {
    return _controlSurface(
      isAvailable: isAvailable,
      onTap: isAvailable
          ? () => store.addItem(
              productId: productId,
              serviceType: serviceType,
              merchantId: merchantId,
              categoryId: categoryId,
              name: name,
              description: description,
              priceInPaise: priceInPaise,
              imageUrl: imageUrl,
              icon: icon,
            )
          : null,
      child: Text(
        isAvailable ? 'ADD' : unavailableLabel,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: isAvailable ? _green : const Color(0xFF929892),
          fontSize: isAvailable ? 11 : 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildQuantityControl(
    BuildContext context,
    CartStore store,
    int quantity,
    bool isAvailable,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F4),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _green),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stepButton(
            icon: Icons.remove_rounded,
            label: 'Decrease quantity',
            onPressed: () {
              if (quantity == 1) {
                store.removeItem(_cartKey);
              } else {
                store.decreaseQuantity(_cartKey);
              }
            },
          ),
          Flexible(
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _stepButton(
            icon: Icons.add_rounded,
            label: 'Increase quantity',
            color: isAvailable ? _green : const Color(0xFF929892),
            onPressed: () {
              if (!isAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This product is currently out of stock.'),
                  ),
                );
                return;
              }
              store.increaseQuantity(_cartKey);
            },
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = _green,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      icon: Icon(icon, color: color, size: 17),
    );
  }

  Widget _controlSurface({
    required Widget child,
    required bool isAvailable,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isAvailable ? Colors.white : const Color(0xFFF0F1EF),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isAvailable ? _green : const Color(0xFFD9DDD8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  String get _cartKey => '$serviceType:${merchantId ?? ''}:$productId';
}
