import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/router.dart';
import '../../shared/providers/providers.dart';

/// Three-phase animated splash:
/// 1. Black screen with logo (0 → 1.2s)
/// 2. Road/clouds decoration appear (1.2 → 2.4s)
/// 3. Transition to white (2.4 → 3.0s) then navigate
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _decorFade;
  late final Animation<double> _bgFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _logoFade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.35, curve: Curves.easeIn));
    _decorFade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 0.70, curve: Curves.easeIn));
    _bgFade    = CurvedAnimation(parent: _ctrl, curve: const Interval(0.80, 1.0, curve: Curves.easeOut));

    _ctrl.forward().then((_) => _navigate());
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    // Restore light status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Check if user is already logged in
    final isLoggedIn = await ref.read(secureStorageProvider).isLoggedIn;
    if (!mounted) return;

    if (isLoggedIn) {
      context.go(AppRoutes.home);
    } else {
      // Check if onboarding was seen (use simple shared prefs alternative)
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Interpolate background from black → white
        final bg = Color.lerp(AppColors.splash, AppColors.white, _bgFade.value)!;

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Decorative road (top-left) ──────────────────────────────
              Positioned(
                top: 0, left: 0,
                child: FadeTransition(
                  opacity: _decorFade,
                  child: _SplashDecoration(isDark: _bgFade.value < 0.5),
                ),
              ),

              // ── Logo (center) ───────────────────────────────────────────
              Center(
                child: FadeTransition(
                  opacity: _logoFade,
                  child: _LogoLockup(isDark: _bgFade.value < 0.5),
                ),
              ),

              // ── Tagline (bottom) ────────────────────────────────────────
              Positioned(
                bottom: 48, left: 0, right: 0,
                child: FadeTransition(
                  opacity: _decorFade,
                  child: Text(
                    'Fast. Reliable. ETC.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _bgFade.value < 0.5 ? AppColors.white : AppColors.textPrimary,
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

class _LogoLockup extends StatelessWidget {
  const _LogoLockup({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // ETC logo text
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('E', style: _letterStyle(isDark ? AppColors.white : AppColors.textPrimary)),
          Text('T', style: _letterStyle(AppColors.primary)),
          Text('C', style: _letterStyle(isDark ? AppColors.white : AppColors.textPrimary)),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'LOGISTICS',
        style: TextStyle(
          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
          letterSpacing: 3,
          color: isDark ? AppColors.primary : AppColors.primary,
        ),
      ),
    ],
  );

  TextStyle _letterStyle(Color color) => TextStyle(
    fontFamily: 'Inter', fontSize: 52, fontWeight: FontWeight.w800,
    color: color, height: 1.0,
  );
}

class _SplashDecoration extends StatelessWidget {
  const _SplashDecoration({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.white : AppColors.textPrimary;
    return SizedBox(
      width: 160, height: 130,
      child: CustomPaint(painter: _RoadPainter(color: color)),
    );
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Road curves
    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.2, size.width, 0);
    canvas.drawPath(path, paint);

    // Dashed center line
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedPath(canvas, path, dashPaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final seg = metric.extractPath(dist, dist + 8);
        canvas.drawPath(seg, paint);
        dist += 16;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
