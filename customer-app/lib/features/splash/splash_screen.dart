import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../shared/providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward().whenComplete(_navigate);
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
      try {
        await ref.read(authInitProvider.future);
      } catch (_) {}
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splash,
      body: FadeTransition(
        opacity: _fade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, child) {
                        final t = _ctrl.value;
                        final wave = math.sin(t * math.pi * 2);
                        final dx = wave * 1.2;
                        final dy = wave * 2.4;
                        final rot = wave * 0.012;
                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Transform.rotate(angle: rot, child: child),
                        );
                      },
                      child: _EmbeddedPngFromSvgAsset(
                        assetPath: AppAssets.splashRoad,
                        width: 110,
                        height: 110,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, child) {
                            final t = _ctrl.value;
                            final wave = math.sin(t * math.pi * 2);
                            final dy = wave * 2.2;
                            final drift = math.sin(t * math.pi) * 8;
                            return ClipRect(
                              child: Transform.translate(
                                offset: Offset(drift, dy),
                                child: child,
                              ),
                            );
                          },
                          child: SizedBox(
                            height: 124,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Opacity(
                                  opacity: 0.78,
                                  child: Transform.translate(
                                    offset: const Offset(0, 22),
                                    child: const _EmbeddedPngFromSvgAsset(
                                      assetPath: AppAssets.splashCloud1,
                                      width: 52,
                                      height: 52,
                                    ),
                                  ),
                                ),
                                Opacity(
                                  opacity: 0.84,
                                  child: Transform.translate(
                                    offset: const Offset(0, -10),
                                    child: const _EmbeddedPngFromSvgAsset(
                                      assetPath: AppAssets.splashCloud2,
                                      width: 90,
                                      height: 90,
                                    ),
                                  ),
                                ),
                                Opacity(
                                  opacity: 0.78,
                                  child: Transform.translate(
                                    offset: const Offset(20, 30),
                                    child: const _EmbeddedPngFromSvgAsset(
                                      assetPath: AppAssets.splashCloud3,
                                      width: 60,
                                      height: 60,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: _EmbeddedPngFromSvgAsset(assetPath: AppAssets.logoDark, width: 200),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Text(
                AppStrings.appTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
    this.width,
    this.height,
  });

  final String assetPath;
  final double? width;
  final double? height;

  static final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> _load() {
    return _cache.putIfAbsent(assetPath, () async {
      final svg = await rootBundle.loadString(assetPath);
      final match = RegExp(r'data:image\/png;base64,([^"]+)').firstMatch(svg);
      if (match == null) throw const FormatException('No embedded PNG found.');
      return base64Decode(match.group(1)!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Image.memory(
          snap.data!,
          width: width,
          height: height,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      },
    );
  }
}
