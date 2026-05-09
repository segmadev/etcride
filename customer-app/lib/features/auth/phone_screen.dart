import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../data/models/otp_extra.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/loading_overlay.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> with SingleTickerProviderStateMixin {
  final _contactCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  late final AnimationController _introCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  )..forward();

  bool get _isValid {
    final v = _contactCtrl.text.trim();
    if (v.isEmpty) return false;
    if (v.contains('@')) {
      // basic email check
      return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
    }
    // phone: at least 10 digits
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v.replaceAll(' ', ''));
  }

  Future<void> _continue() async {
    if (!_isValid) return;
    final contact = _contactCtrl.text.trim();

    setState(() { _loading = true; _error = null; });
    try {
      final contactType = await ref.read(authRepositoryProvider).sendOtp(contact);
      if (!mounted) return;
      context.push(
        AppRoutes.otp,
        extra: OtpExtra(contact: contact, contactType: contactType),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _introCtrl.dispose(); _contactCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final contentWidth = screenSize.width - 20;
    final carBoxWidth = (screenSize.width * 0.70 * 3).clamp(0.0, contentWidth).toDouble();
    final carBoxHeight = (screenSize.height * 0.35 * 3).clamp(220.0, 380.0).toDouble();

    return LoadingOverlay.wrap(
      loading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                Center(
                  child: SizedBox(
                    width: carBoxWidth,
                    height: carBoxHeight,
                    child: _IntroCar(
                      controller: _introCtrl,
                      height: carBoxHeight,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                _FadeSlide(
                  controller: _introCtrl,
                  interval: const Interval(0.62, 0.76, curve: Curves.easeOut),
                  from: const Offset(0, 10),
                  child: Text(
                    AppStrings.startJourney,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2,
                  ),
                ),
                const SizedBox(height: 8),
                _FadeSlide(
                  controller: _introCtrl,
                  interval: const Interval(0.70, 0.82, curve: Curves.easeOut),
                  from: const Offset(0, 10),
                  child: Text(
                    AppStrings.startJourneySub,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),

                const SizedBox(height: 36),

                _FadeSlide(
                  controller: _introCtrl,
                  interval: const Interval(0.78, 0.90, curve: Curves.easeOut),
                  from: const Offset(0, 12),
                  child: AppTextField(
                    controller: _contactCtrl,
                    label: AppStrings.emailOrPhone,
                    hint: 'e.g. 08012345678 or you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _continue(),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                ],

                const SizedBox(height: 32),

                _FadeSlide(
                  controller: _introCtrl,
                  interval: const Interval(0.84, 1.00, curve: Curves.easeOut),
                  from: const Offset(0, 14),
                  child: AppButton(
                    label: AppStrings.continueBtn,
                    onPressed: _isValid && !_loading ? _continue : null,
                    enabled: _isValid && !_loading,
                  ),
                ),

                const SizedBox(height: 16),
                _FadeSlide(
                  controller: _introCtrl,
                  interval: const Interval(0.90, 1.00, curve: Curves.easeOut),
                  from: const Offset(0, 10),
                  child: Center(
                    child: Text(
                      AppStrings.otpSentNote,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({
    required this.controller,
    required this.interval,
    required this.child,
    this.from = const Offset(0, 12),
  });

  final AnimationController controller;
  final Interval interval;
  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        return Opacity(
          opacity: t.value,
          child: Transform.translate(
            offset: Offset(from.dx * (1 - t.value), from.dy * (1 - t.value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _IntroCar extends StatelessWidget {
  const _IntroCar({
    required this.controller,
    required this.height,
  });

  final AnimationController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final entry = CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.46, curve: Curves.easeOutCubic));
    final settle = CurvedAnimation(parent: controller, curve: const Interval(0.38, 0.62, curve: Curves.easeOutBack));

    final baseY = Tween<double>(begin: -height * 0.18, end: 0).animate(entry);
    final scale = Tween<double>(begin: 0.99, end: 1.0).animate(settle);
    final settleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 55),
    ]).animate(CurvedAnimation(parent: controller, curve: const Interval(0.44, 0.66)));

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final trailOpacity = (1 - entry.value).clamp(0.0, 1.0) * 0.18;

          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                child: Opacity(
                  opacity: trailOpacity,
                  child: Container(
                    width: 160,
                    height: height,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x22000000),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, baseY.value + settleY.value),
                child: Transform.scale(
                  scale: scale.value,
                  child: SizedBox.expand(
                    child: _EmbeddedPngFromSvgAsset(
                      assetPath: AppAssets.carLogin,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
    this.fit = BoxFit.cover,
  });

  final String assetPath;
  final BoxFit fit;

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
        return Image.memory(snap.data!, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
