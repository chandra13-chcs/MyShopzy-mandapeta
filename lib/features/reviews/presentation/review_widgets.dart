import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../product_details/models/product_review.dart';

class ReviewStars extends StatelessWidget {
  const ReviewStars({required this.rating, required this.size, super.key});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFE4A323),
          size: size,
        ),
      ),
    );
  }
}

class RatingBreakdownRow extends StatelessWidget {
  const RatingBreakdownRow({
    required this.rating,
    required this.count,
    required this.total,
    super.key,
  });

  final int rating;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 37,
            child: Text(
              '$rating star',
              style: const TextStyle(color: Color(0xFF727A74), fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 6,
                backgroundColor: const Color(0xFFE9ECE8),
                valueColor: const AlwaysStoppedAnimation(
                  AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: const TextStyle(color: Color(0xFF727A74), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerReviewCard extends StatelessWidget {
  const CustomerReviewCard({
    required this.review,
    required this.onHelpful,
    super.key,
  });

  final ProductReview review;
  final VoidCallback onHelpful;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.reviewerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF17251F),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _formatReviewDate(review.createdAt),
              style: const TextStyle(color: Color(0xFF727A74), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            ReviewStars(rating: review.rating, size: 14),
            if (review.isVerifiedPurchase) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3E9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'Verified Purchase',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Text(
          review.reviewText,
          style: const TextStyle(
            color: Color(0xFF4F5A53),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onHelpful,
            icon: const Icon(Icons.thumb_up_alt_outlined, size: 14),
            label: Text('Helpful (${review.helpfulCount})'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF727A74),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              textStyle: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  String _formatReviewDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
