import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../orders/models/order_record.dart';

class OrderRatingPage extends StatefulWidget {
  const OrderRatingPage({required this.order, super.key});

  final OrderRecord order;

  @override
  State<OrderRatingPage> createState() => _OrderRatingPageState();
}

class _OrderRatingPageState extends State<OrderRatingPage> {
  static const _background = AppTheme.lightBackground;
  static const _ink = AppTheme.primaryText;
  static const _green = AppTheme.primaryGreen;
  static const _yellow = AppTheme.brandYellow;
  static const _border = Color(0xFFE5E9E3);

  final _commentController = TextEditingController();
  final Map<int, int> _productRatings = {};
  int _deliveryRating = 0;
  bool _showValidationError = false;
  bool _showPersistenceNotice = false;

  bool get _isDelivered => widget.order.orderTab == OrdersTab.delivered;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDelivered) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: AppTheme.white,
          title: const Text('Rate Your Order'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ratings are available after an order is delivered.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Rate Your Order',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderHeader(),
              const SizedBox(height: 16),
              _ratingCard(
                title: 'Rate your delivery partner',
                subtitle: 'How was your delivery experience?',
                rating: _deliveryRating,
                onChanged: (rating) => setState(() {
                  _deliveryRating = rating;
                  _showValidationError = false;
                  _showPersistenceNotice = false;
                }),
                keyPrefix: 'delivery',
              ),
              if (widget.order.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildProductRatings(),
              ],
              const SizedBox(height: 16),
              _buildCommentField(),
              const SizedBox(height: 12),
              const Text(
                'Order ratings are not saved in this demo.',
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
              ),
              if (_showValidationError) ...[
                const SizedBox(height: 8),
                const Text(
                  'Select a delivery partner rating before continuing.',
                  key: ValueKey('order-rating-validation'),
                  style: TextStyle(color: Color(0xFFB63E32), fontSize: 13),
                ),
              ],
              if (_showPersistenceNotice) ...[
                const SizedBox(height: 8),
                const Text(
                  'Your ratings have not been submitted. Saving will be '
                  'available when order reviews are connected.',
                  key: ValueKey('order-rating-not-saved'),
                  style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('order-rating-submit'),
                  onPressed: _handleSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Submit Ratings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: _green, size: 25),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.order.storeName,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Order ${widget.order.orderId}',
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: _green, size: 21),
        ],
      ),
    );
  }

  Widget _buildProductRatings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rate products (optional)',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < widget.order.items.length; index++) ...[
            if (index > 0) const Divider(height: 18, color: _border),
            Text(
              widget.order.items[index].name,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.order.items[index].variantLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.order.items[index].variantLabel!,
                style: const TextStyle(
                  color: AppTheme.secondaryText,
                  fontSize: 11,
                ),
              ),
            ],
            _starRating(
              rating: _productRatings[index] ?? 0,
              onChanged: (rating) => setState(() {
                _productRatings[index] = rating;
                _showPersistenceNotice = false;
              }),
              keyPrefix: 'product-$index',
            ),
          ],
        ],
      ),
    );
  }

  Widget _ratingCard({
    required String title,
    required String subtitle,
    required int rating,
    required ValueChanged<int> onChanged,
    required String keyPrefix,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 12),
          ),
          _starRating(
            rating: rating,
            onChanged: onChanged,
            keyPrefix: keyPrefix,
          ),
        ],
      ),
    );
  }

  Widget _starRating({
    required int rating,
    required ValueChanged<int> onChanged,
    required String keyPrefix,
  }) {
    return Semantics(
      label: '$keyPrefix rating, $rating out of 5 stars',
      child: Wrap(
        spacing: 2,
        children: [
          for (var index = 1; index <= 5; index++)
            IconButton(
              key: ValueKey('$keyPrefix-rating-star-$index'),
              tooltip: '$index star${index == 1 ? '' : 's'}',
              onPressed: () => onChanged(index),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                index <= rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: index <= rating ? _yellow : const Color(0xFF9AA19C),
                size: 32,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentField() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment (optional)',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('order-rating-comment'),
            controller: _commentController,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Share anything about your delivery or products',
              filled: true,
              fillColor: _background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    if (_deliveryRating < 1 || _deliveryRating > 5) {
      setState(() {
        _showValidationError = true;
        _showPersistenceNotice = false;
      });
      return;
    }

    // Future order-review persistence belongs here. Do not imply ratings were
    // submitted until that operation is backed by a real store or API.
    setState(() {
      _showValidationError = false;
      _showPersistenceNotice = true;
    });
  }
}
