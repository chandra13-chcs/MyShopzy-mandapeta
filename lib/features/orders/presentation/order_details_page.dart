import 'package:flutter/material.dart';

import '../../cart/data/cart_store.dart';
import '../../cart/presentation/cart_page.dart';
import '../../product_details/data/product_availability_store.dart';
import '../../product_details/models/product_details_product.dart';
import '../../reviews/presentation/write_review_page.dart';
import '../models/order_record.dart';
import 'order_tracking_page.dart';

class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({required this.order, super.key});

  final OrderRecord order;

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _lightGreen = Color(0xFFEFF8F4);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);
  static const _border = Color(0xFFE7EAE8);

  bool get _canTrack =>
      order.orderTab == OrdersTab.ongoing && order.trackingStatus != null;

  bool get _canCancel => order.canCustomerCancel;

  bool get _canReview =>
      order.orderTab == OrdersTab.delivered && order.items.isNotEmpty;

  bool get _canBuyAgain =>
      order.orderTab == OrdersTab.delivered && order.items.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 14),
              _buildOrderInfoCard(),
              const SizedBox(height: 14),
              _buildItemsCard(),
              const SizedBox(height: 14),
              _buildPriceCard(),
              const SizedBox(height: 14),
              _buildPaymentCard(),
              const SizedBox(height: 14),
              _buildAddressCard(),
              if (_canShowOtp) ...[const SizedBox(height: 14), _buildOtpCard()],
              const SizedBox(height: 18),
              if (_canTrack) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => _openTracking(context),
                    icon: const Icon(Icons.delivery_dining_rounded),
                    label: const Text('Track Order'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_canCancel) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancellation(context),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Order'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA85B5B),
                      side: const BorderSide(color: Color(0xFFA85B5B)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_canReview) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _reviewProducts(context),
                    icon: const Icon(Icons.star_border_rounded),
                    label: const Text('Review products'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_canBuyAgain) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => _buyAgain(context),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Buy Again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openReceipt(context),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View Receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canShowOtp =>
      order.orderTab == OrdersTab.ongoing && order.deliveryOtp != null;

  Widget _buildStatusCard() {
    final cancelled = order.orderTab == OrdersTab.cancelled;
    final color = cancelled ? const Color(0xFFA85B5B) : _green;
    final background = cancelled ? const Color(0xFFFFF2F1) : _lightGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            cancelled
                ? Icons.cancel_outlined
                : order.orderTab == OrdersTab.delivered
                ? Icons.check_circle_outline_rounded
                : Icons.local_shipping_outlined,
            color: color,
            size: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.statusMessage,
                  style: const TextStyle(color: _secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return _SectionCard(
      title: 'Order information',
      child: Column(
        children: [
          _InfoRow(label: 'Order ID', value: order.orderId),
          const SizedBox(height: 10),
          _InfoRow(label: 'Order date', value: order.dateTime),
          const SizedBox(height: 10),
          _InfoRow(label: 'Merchant', value: order.storeName),
          const SizedBox(height: 10),
          _InfoRow(label: 'Service', value: order.serviceType),
          if (order.cancellationReason != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Cancellation reason',
              value: order.cancellationReason!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return _SectionCard(
      title: 'Ordered items',
      child: Column(
        children: [
          for (var index = 0; index < order.items.length; index++) ...[
            if (index > 0) const Divider(height: 20, color: _border),
            _OrderItemRow(item: order.items[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return _SectionCard(
      title: 'Price details',
      child: Column(
        children: [
          _InfoRow(
            label: 'Item total',
            value: _formatPrice(order.itemTotalInPaise),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Delivery charge · demo',
            value: _formatPrice(order.deliveryChargeInPaise),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Discount · demo',
            value: order.discountInPaise == 0
                ? 'Not applied'
                : '−${_formatPrice(order.discountInPaise)}',
          ),
          const Divider(height: 22, color: _border),
          _InfoRow(
            label: 'Grand total',
            value: _formatPrice(order.totalInPaise),
            emphasized: true,
          ),
          const SizedBox(height: 9),
          const Text(
            'Demo item prices and delivery charges are illustrative.',
            style: TextStyle(color: _secondaryText, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return _SectionCard(
      title: 'Payment',
      child: Column(
        children: [
          _InfoRow(label: 'Payment method', value: order.paymentMethod),
          const SizedBox(height: 10),
          _InfoRow(label: 'Payment status', value: order.paymentStatus),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return _SectionCard(
      title: 'Delivery address',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: _green, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              order.deliveryAddress,
              style: const TextStyle(
                color: _mainText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    return _SectionCard(
      title: 'Delivery OTP',
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Share this demo OTP with your delivery partner only when your order arrives.',
              style: TextStyle(
                color: _secondaryText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            order.deliveryOtp!,
            style: const TextStyle(
              color: _green,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _openTracking(BuildContext context) {
    final status = order.trackingStatus;
    if (status == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OrderTrackingPage(
          order: OrderTrackingData(
            orderId: order.orderId,
            storeName: order.storeName,
            items: order.itemSummary,
            total: order.total,
            status: status,
          ),
        ),
      ),
    );
  }

  void _openReceipt(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OrderReceiptPage(order: order),
      ),
    );
  }

  Future<void> _confirmCancellation(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? selectedReason;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final otherReason = reasonController.text.trim();
            final canConfirm =
                selectedReason != null &&
                (selectedReason != 'Other' || otherReason.isNotEmpty);
            return AlertDialog(
              title: const Text('Cancel order?'),
              content: SingleChildScrollView(
                child: RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final option in _cancellationReasons)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(option),
                          value: option,
                        ),
                      if (selectedReason == 'Other')
                        TextField(
                          controller: reasonController,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Please specify',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Keep Order'),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () {
                          final value = selectedReason == 'Other'
                              ? 'Other: ${reasonController.text.trim()}'
                              : selectedReason!;
                          Navigator.of(dialogContext).pop(value);
                        }
                      : null,
                  child: const Text('Confirm cancellation'),
                ),
              ],
            );
          },
        );
      },
    );
    reasonController.dispose();
    if (reason == null || !context.mounted) return;
    if (!order.cancelByCustomer(reason)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This order can no longer be cancelled.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _reviewProducts(BuildContext context) async {
    final item = await showModalBottomSheet<OrderLineItem>(
      context: context,
      backgroundColor: _background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a product to review',
                style: TextStyle(
                  color: _mainText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in order.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.icon, color: _green),
                  title: Text(item.name),
                  subtitle: Text('Quantity: ${item.quantity}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(item),
                ),
            ],
          ),
        ),
      ),
    );
    if (item == null || !context.mounted) return;

    final product = ProductDetailsProduct(
      id: item.productId ?? _productIdFromName(item.name),
      serviceType:
          item.serviceType ??
          order.serviceType.toLowerCase().replaceAll(' ', '_'),
      merchantId: item.merchantId,
      name: item.name,
      icon: item.icon,
      available: true,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WriteReviewPage(product: product),
      ),
    );
  }

  String _productIdFromName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  void _buyAgain(BuildContext context) {
    final cart = CartStore.instance;
    final availability = ProductAvailabilityStore.instance;
    final fallbackService = _normalizeIdentity(order.serviceType);
    final fallbackMerchant = _normalizeIdentity(order.storeName);
    final serviceIdentifiedItem = order.items.firstWhere(
      (item) => item.serviceType != null,
      orElse: () => order.items.first,
    );
    final merchantIdentifiedItem = order.items.firstWhere(
      (item) => item.merchantId != null,
      orElse: () => order.items.first,
    );
    final targetService = serviceIdentifiedItem.serviceType ?? fallbackService;
    final targetMerchant =
        merchantIdentifiedItem.merchantId ?? fallbackMerchant;

    final hasIncompatibleCartItems = cart.items.any(
      (item) =>
          item.serviceType != targetService ||
          item.merchantId != targetMerchant,
    );
    if (hasIncompatibleCartItems) {
      _showReorderMessage(
        context,
        'Your cart contains items from another store. Empty your cart before buying again.',
      );
      return;
    }

    var addedQuantity = 0;
    final unavailableNames = <String>{};
    final incompatibleNames = <String>{};
    for (final item in order.items) {
      final productId = item.productId ?? _productIdFromName(item.name);
      final serviceType = item.serviceType ?? targetService;
      final merchantId = item.merchantId ?? targetMerchant;
      if (serviceType != targetService || merchantId != targetMerchant) {
        incompatibleNames.add(item.name);
        continue;
      }
      if (!availability.isAvailable(
        productId: productId,
        serviceType: serviceType,
        merchantId: merchantId,
        defaultAvailable: true,
      )) {
        unavailableNames.add(item.name);
        continue;
      }

      for (var quantity = 0; quantity < item.quantity; quantity++) {
        cart.addItem(
          productId: productId,
          serviceType: serviceType,
          merchantId: merchantId,
          name: item.name,
          description: item.description ?? '',
          priceInPaise: item.unitPriceInPaise,
          imageUrl: item.imageUrl,
          icon: item.icon,
        );
        addedQuantity++;
      }
    }

    if (addedQuantity == 0) {
      final messages = <String>[];
      if (unavailableNames.isNotEmpty) {
        messages.add('Out of stock: ${unavailableNames.join(', ')}.');
      }
      if (incompatibleNames.isNotEmpty) {
        messages.add(
          'Not added because they belong to another store: '
          '${incompatibleNames.join(', ')}.',
        );
      }
      _showReorderMessage(
        context,
        messages.isEmpty
            ? 'No products from this order could be added to your cart.'
            : messages.join(' '),
      );
      return;
    }

    final feedback = StringBuffer(
      '$addedQuantity ${addedQuantity == 1 ? 'item' : 'items'} added to your cart.',
    );
    if (unavailableNames.isNotEmpty) {
      feedback.write(' Out of stock: ${unavailableNames.join(', ')}.');
    }
    if (incompatibleNames.isNotEmpty) {
      feedback.write(
        ' Not added from another store: ${incompatibleNames.join(', ')}.',
      );
    }
    _showReorderMessage(context, feedback.toString());
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => const CartPage()));
  }

  String _normalizeIdentity(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  void _showReorderMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatPrice(int priceInPaise) {
    final rupees = priceInPaise ~/ 100;
    final paise = priceInPaise % 100;
    return paise == 0
        ? '₹$rupees'
        : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }

  static const _cancellationReasons = [
    'Changed my mind',
    'Ordered by mistake',
    'Delivery taking too long',
    'Found better option',
    'Other',
  ];
}

class OrderReceiptPage extends StatelessWidget {
  const OrderReceiptPage({required this.order, super.key});

  final OrderRecord order;

  static const _background = Color(0xFFFCFDFC);
  static const _green = Color(0xFF2C7C65);
  static const _mainText = Color(0xFF202321);
  static const _secondaryText = Color(0xFF777C79);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _mainText,
        surfaceTintColor: _background,
        title: const Text(
          'Receipt',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7EAE8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.bolt_rounded, color: _green, size: 28),
                      SizedBox(height: 3),
                      Text(
                        'MYSHOPZY',
                        style: TextStyle(
                          color: _mainText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'DEMO RECEIPT',
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(),
                _ReceiptRow(label: 'Order ID', value: order.orderId),
                _ReceiptRow(label: 'Date', value: order.dateTime),
                _ReceiptRow(label: 'Merchant', value: order.storeName),
                _ReceiptRow(label: 'Order Status', value: order.status),
                if (order.cancellationReason != null)
                  _ReceiptRow(
                    label: 'Cancellation Reason',
                    value: order.cancellationReason!,
                  ),
                const Divider(height: 23),
                for (final item in order.items)
                  _ReceiptRow(
                    label: '${item.name} × ${item.quantity}',
                    value: _formatPrice(item.lineTotalInPaise),
                  ),
                const Divider(height: 23),
                _ReceiptRow(
                  label: 'Item Total',
                  value: _formatPrice(order.itemTotalInPaise),
                ),
                _ReceiptRow(
                  label: 'Delivery Charge · demo',
                  value: _formatPrice(order.deliveryChargeInPaise),
                ),
                _ReceiptRow(
                  label: 'Discount · demo',
                  value: order.discountInPaise == 0
                      ? 'Not applied'
                      : '−${_formatPrice(order.discountInPaise)}',
                ),
                const Divider(height: 23),
                _ReceiptRow(
                  label: 'Grand Total',
                  value: _formatPrice(order.totalInPaise),
                  emphasized: true,
                ),
                const SizedBox(height: 15),
                _ReceiptRow(
                  label: 'Payment Method',
                  value: order.paymentMethod,
                ),
                _ReceiptRow(
                  label: 'Payment Status',
                  value: order.paymentStatus,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.deliveryAddress,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Demo receipt · item values and charges are illustrative.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondaryText, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Receipt download will be available in the production version.',
                  ),
                ),
              ),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download Receipt'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(int priceInPaise) {
    final rupees = priceInPaise ~/ 100;
    final paise = priceInPaise % 100;
    return paise == 0
        ? '₹$rupees'
        : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderLineItem item;

  @override
  Widget build(BuildContext context) {
    final description = item.description;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF8F4),
            borderRadius: BorderRadius.circular(11),
          ),
          child: item.imageUrl == null || item.imageUrl!.isEmpty
              ? Icon(item.icon, color: const Color(0xFF2C7C65), size: 22)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(item.icon, color: const Color(0xFF2C7C65)),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  color: Color(0xFF202321),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF777C79),
                    fontSize: 10,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                '${item.quantity} × ${_formatPrice(item.unitPriceInPaise)}',
                style: const TextStyle(color: Color(0xFF777C79), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatPrice(item.lineTotalInPaise),
          style: const TextStyle(
            color: Color(0xFF202321),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatPrice(int priceInPaise) {
    final rupees = priceInPaise ~/ 100;
    final paise = priceInPaise % 100;
    return paise == 0
        ? '₹$rupees'
        : '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF202321),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized
        ? const Color(0xFF202321)
        : const Color(0xFF777C79);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: emphasized ? 14 : 12,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: emphasized
                  ? const Color(0xFF2C7C65)
                  : const Color(0xFF202321),
              fontSize: emphasized ? 15 : 12,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized
                    ? const Color(0xFF202321)
                    : const Color(0xFF777C79),
                fontSize: emphasized ? 14 : 11,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: emphasized
                  ? const Color(0xFF2C7C65)
                  : const Color(0xFF202321),
              fontSize: emphasized ? 14 : 11,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
