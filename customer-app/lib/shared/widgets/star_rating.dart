import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Interactive or display-only star rating widget.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.size = 24.0,
    this.onRate,
    this.color = AppColors.starFilled,
    this.emptyColor = AppColors.starEmpty,
  });

  final double rating;
  final int maxStars;
  final double size;
  final ValueChanged<int>? onRate;
  final Color color;
  final Color emptyColor;

  bool get interactive => onRate != null;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(maxStars, (i) {
      final filled = i < rating.round();
      return GestureDetector(
        onTap: interactive ? () => onRate!(i + 1) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? color : emptyColor,
            size: size,
          ),
        ),
      );
    }),
  );
}

/// Compact read-only rating shown in driver cards.
class CompactRating extends StatelessWidget {
  const CompactRating({super.key, required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, color: AppColors.starFilled, size: 14),
      const SizedBox(width: 3),
      Text(
        rating.toStringAsFixed(1),
        style: const TextStyle(
          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}
