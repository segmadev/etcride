import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Full-screen translucent overlay with spinner.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const ModalBarrier(color: Color(0x66000000), dismissible: false),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36, height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  /// Wrap a widget and conditionally show the overlay.
  static Widget wrap({
    required Widget child,
    required bool loading,
    String? message,
  }) => Stack(
    children: [
      child,
      if (loading) LoadingOverlay(message: message),
    ],
  );
}

/// Shimmer-style skeleton placeholder for list items.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.disabled,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}
