import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../checkout/presentation/checkout_page.dart';
import '../../home/presentation/free_delivery_progress_strip.dart';
import '../data/cart_store.dart';
import '../../product_details/data/product_availability_store.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
  static const _border = Color(0xFFE7EAE8);

  final _cartStore = CartStore.instance;
  bool _loadingBackendCart = false;
  String? _cartLoadError;

  @override
  void initState() {
    super.initState();
    if (CustomerApi.instance.isConfigured &&
        !_cartStore.items.any((item) => !item.isBackendProduct)) {
      Future<void>.delayed(Duration.zero, _refreshBackendCart);
    }
  }

  Future<void> _refreshBackendCart() async {
    if (!mounted) return;
    setState(() {
      _loadingBackendCart = true;
      _cartLoadError = null;
    });
    try {
      await _cartStore.refreshBackendCart();
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _cartLoadError = error.message);
    } finally {
      if (mounted) setState(() => _loadingBackendCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Cart',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: AnimatedBuilder(
        animation: _cartStore,
        builder: (context, child) {
          final items = _cartStore.items;
          if (items.isNotEmpty) return _buildCartContents(items);
          if (_loadingBackendCart) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_cartLoadError != null) {
            return _buildCartLoadError();
          }
          return _buildEmptyState(context);
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _cartStore,
        builder: (context, child) => _cartStore.items.isEmpty
            ? const SizedBox.shrink()
            : _buildCheckoutAction(context),
      ),
    );
  }

  Widget _buildCartContents(List<CartItem> items) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (_cartLoadError != null) ...[
          _buildCartLoadErrorBanner(),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _lightGreen,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: _green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  items.every((item) => item.isBackendProduct)
                      ? 'Backend cart · Prices are refreshed during checkout'
                      : 'Demo cart · Items and prices are for preview only',
                  style: const TextStyle(color: _green, fontSize: 12),
                ),
              ),
              if (_cartStore.hasBackendCart)
                TextButton(
                  onPressed: () => _runCartMutation(_cartStore.clearFromUi()),
                  child: const Text('Clear cart'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const FreeDeliveryProgressStrip(),
        const SizedBox(height: 14),
        for (final item in items) ...[
          _buildCartItem(item),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        _buildOrderSummary(),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(item.icon, color: _green, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.variantLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.variantLabel!,
                    style: const TextStyle(
                      color: _secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(color: _secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(
                      _formatPrice(item.priceInPaise),
                      style: const TextStyle(
                        color: _mainText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _buildQuantityControl(item),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _cartStore.isQuantityMutationPending(item.key)
                ? null
                : () => _runCartMutation(
                    _cartStore.removeItemFromUi(item.key),
                  ),
            tooltip: 'Remove item',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: _secondaryText,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityControl(CartItem item) {
    return AnimatedBuilder(
      animation: ProductAvailabilityStore.instance,
      builder: (context, child) {
        final available = ProductAvailabilityStore.instance.isAvailable(
          productId: item.productId,
          serviceType: item.serviceType,
          merchantId: item.merchantId,
          variantId: item.productVariantId,
          defaultAvailable: item.available,
        );
        final quantityPending = _cartStore.isQuantityMutationPending(item.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!available) ...[
              const Text(
                'Out of Stock',
                style: TextStyle(
                  color: Color(0xFFA85B5B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Container(
              decoration: BoxDecoration(
                color: _lightGreen,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _quantityButton(
                    icon: Icons.remove_rounded,
                    label: 'Decrease quantity',
                    onPressed: quantityPending
                        ? null
                        : () => _runCartMutation(
                            _cartStore.decreaseQuantityFromUi(item.key),
                          ),
                  ),
                  SizedBox(
                    width: 25,
                    child: Text(
                      quantityPending ? '…' : '${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _mainText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _quantityButton(
                    icon: Icons.add_rounded,
                    label: 'Increase quantity',
                    color: available ? _green : _secondaryText,
                    onPressed: quantityPending
                        ? null
                        : () {
                            if (!available) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This product is currently out of stock.',
                                  ),
                                ),
                              );
                              return;
                            }
                            _increaseQuantity(item);
                          },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _increaseQuantity(CartItem item) async {
    try {
      if (!await _cartStore.increaseQuantityFromUi(item.key) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _cartStore.incompatibilityMessage(
                    serviceType: item.serviceType,
                    merchantId: item.merchantId,
                    serviceVariant: item.serviceVariant,
                  ) ??
                  'Please complete or clear your current order before adding '
                      'items from another service.',
            ),
          ),
        );
      }
    } on CustomerApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _runCartMutation(Future<void> mutation) async {
    try {
      await mutation;
    } on CustomerApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Widget _quantityButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color color = _green,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: _mainText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(
            'Item subtotal',
            _formatPrice(_cartStore.subtotalInPaise),
          ),
          const SizedBox(height: 9),
          _summaryRow('Delivery charge', 'Calculated at checkout'),
          const SizedBox(height: 9),
          _summaryRow('Discount', 'Demo only'),
          const Divider(height: 22, color: _border),
          _summaryRow(
            'Total (items only)',
            _formatPrice(_cartStore.subtotalInPaise),
            emphasize: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'Final delivery charges and discounts are not included in this demo total.',
            style: TextStyle(color: _secondaryText, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String value, {bool emphasize = false}) {
    final style = TextStyle(
      color: emphasize ? _mainText : _secondaryText,
      fontSize: emphasize ? 14 : 12,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
    );
    return Row(
      children: [
        Expanded(child: Text(title, style: style)),
        const SizedBox(width: 8),
        Text(value, style: style, textAlign: TextAlign.end),
      ],
    );
  }

  Widget _buildCheckoutAction(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const CheckoutPage(),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Proceed to Checkout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: FreeDeliveryProgressStrip(),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: _lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: _green,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: _mainText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Add something you love and it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continue Shopping'),
            ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: _secondaryText,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load your cart.',
              style: TextStyle(
                color: _mainText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _cartLoadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadingBackendCart ? null : _refreshBackendCart,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartLoadErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _cartLoadError!,
              style: TextStyle(color: _secondaryText, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _loadingBackendCart ? null : _refreshBackendCart,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int priceInPaise) {
    final rupees = priceInPaise ~/ 100;
    final paise = priceInPaise % 100;
    if (paise == 0) return '₹$rupees';
    return '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }
}
