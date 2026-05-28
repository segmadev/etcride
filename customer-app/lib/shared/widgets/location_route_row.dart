import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Pickup → destination route display used in trip cards, driver assigned, etc.
/// Green dot (pickup) → dashed line → orange dot (destination)
class LocationRouteRow extends StatelessWidget {
  const LocationRouteRow({
    super.key,
    required this.pickup,
    required this.destination,
    this.pickupColor = AppColors.pickupPin,
    this.destinationColor = AppColors.destinationPin,
    this.compact = false,
  });

  final String pickup;
  final String destination;
  final Color pickupColor;
  final Color destinationColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = compact
        ? AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)
        : AppTextStyles.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: dots + dashed line ───────────────────────────────────────
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pin(color: pickupColor, size: compact ? 14 : 16),
            _DashedLine(height: compact ? 18 : 22),
            _Pin(color: destinationColor, size: compact ? 14 : 16),
          ],
        ),
        const SizedBox(width: 12),
        // ── Right: addresses ───────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup,      style: textStyle.copyWith(color: pickupColor),      maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: compact ? 10 : 14),
              Text(destination, style: textStyle.copyWith(color: destinationColor), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        AppAssets.mapPin,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(painter: _DashedLinePainter()),
  );
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashH = 3.0, gapH = 3.0;
    final paint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashH),
        paint,
      );
      y += dashH + gapH;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
