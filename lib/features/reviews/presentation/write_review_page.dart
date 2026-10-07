import 'package:flutter/material.dart';

import '../../product_details/data/demo_product_reviews.dart';
import '../../product_details/models/product_details_product.dart';

class WriteReviewPage extends StatefulWidget {
  const WriteReviewPage({required this.product, super.key});

  final ProductDetailsProduct product;

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  static const _background = Color(0xFFF7F8F5);
  static const _ink = Color(0xFF17251F);
  static const _green = Color(0xFF16834A);
  static const _border = Color(0xFFE5E9E3);

  final _reviewController = TextEditingController();
  var _rating = 5;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _ink,
        surfaceTintColor: _background,
        title: const Text(
          'Write a Review',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Icon(product.icon, color: _green, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Your rating',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  5,
                  (index) => IconButton(
                    tooltip: '${index + 1} star${index == 0 ? '' : 's'}',
                    onPressed: () => setState(() => _rating = index + 1),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFE4A323),
                      size: 34,
                    ),
                  ),
                ),
              ),
              Text(
                _ratingLabel,
                style: const TextStyle(
                  color: Color(0xFF727A74),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your review',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewController,
                minLines: 4,
                maxLines: 7,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What did you like or dislike?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _green),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add photos (optional)',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: _green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Photo selection is not available in this demo.',
                        style: TextStyle(
                          color: Color(0xFF727A74),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This review is saved in local demo memory only.',
                style: TextStyle(color: Color(0xFF727A74), fontSize: 11),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Submit Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _ratingLabel => switch (_rating) {
    1 => 'Poor',
    2 => 'Fair',
    3 => 'Good',
    4 => 'Very good',
    _ => 'Excellent',
  };

  void _submit() {
    final reviewText = _reviewController.text.trim();
    if (reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your review.')),
      );
      return;
    }

    final product = widget.product;
    DemoProductReviews.instance.addReview(
      productId: product.id,
      serviceType: product.serviceType,
      merchantId: product.merchantId,
      reviewerName: 'You',
      rating: _rating,
      reviewText: reviewText,
      createdAt: DateTime.now(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your review was added locally to this demo.'),
      ),
    );
    Navigator.of(context).pop();
  }
}
