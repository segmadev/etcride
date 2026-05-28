import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';

const _mustard = Color(0xFFD99E2B);
const _inactiveMustard = Color(0xFFF3E2BE);

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.backgroundColor,
    required this.phoneWidthFactor,
    required this.phoneBottomFactor,
    required this.phoneOffset,
    required this.phoneRotation,
    this.showFloatingCards = false,
  });
  final String title;
  final String subtitle;
  final String asset;
  final Color backgroundColor;
  final double phoneWidthFactor;
  final double phoneBottomFactor;
  final Offset phoneOffset;
  final double phoneRotation;
  final bool showFloatingCards;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  late final AnimationController _floatCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);
  late final Animation<double> _float = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut);
  int _page = 0;

  late final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: AppStrings.ob1Title,
      subtitle: AppStrings.ob1Subtitle,
      asset: AppAssets.onboarding1,
      backgroundColor: AppColors.white,
      phoneWidthFactor: 0.88,
      phoneBottomFactor: -0.26,
      phoneOffset: const Offset(0, 0),
      phoneRotation: 0,
    ),
    _OnboardingPage(
      title: AppStrings.ob2Title,
      subtitle: AppStrings.ob2Subtitle,
      asset: AppAssets.onboarding3,
      backgroundColor: Color(0xFFFCEFD5),
      phoneWidthFactor: 0.90,
      phoneBottomFactor: -0.30,
      phoneOffset: const Offset(0, 0),
      phoneRotation: 0.26,
      showFloatingCards: true,
    ),
    _OnboardingPage(
      title: AppStrings.ob3Title,
      subtitle: AppStrings.ob3Subtitle,
      asset: AppAssets.onboarding2,
      backgroundColor: AppColors.white,
      phoneWidthFactor: 0.82,
      phoneBottomFactor: -0.30,
      phoneOffset: const Offset(40, 0),
      phoneRotation: 0,
    ),
  ];

  @override
  void dispose() { _floatCtrl.dispose(); _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (context, _) {
        final pageValue = _pageCtrl.hasClients ? (_pageCtrl.page ?? _page.toDouble()) : _page.toDouble();
        final lower = pageValue.floor().clamp(0, _pages.length - 1);
        final upper = pageValue.ceil().clamp(0, _pages.length - 1);
        final t = (pageValue - lower).clamp(0.0, 1.0);
        final bg = Color.lerp(_pages[lower].backgroundColor, _pages[upper].backgroundColor, t) ?? _pages[_page].backgroundColor;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: List.generate(_pages.length, (i) => _Bar(active: i == _page)),
                            ),
                          ),
                          if (!isLast)
                            TextButton(
                              onPressed: () => context.go(AppRoutes.phone),
                              child: Text(
                                AppStrings.skip,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageCtrl,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemCount: _pages.length,
                        itemBuilder: (context, i) => _OnboardingPageView(
                          page: _pages[i],
                          pageIndex: i,
                          pageController: _pageCtrl,
                          float: _float,
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  left: 24,
                  right: 24,
                  bottom: isLast ? 16 : -120,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isLast ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      scale: isLast ? 1 : 0.92,
                      child: _GetStartedCta(onTap: () => context.go(AppRoutes.phone)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({
    required this.page,
    required this.pageIndex,
    required this.pageController,
    required this.float,
  });
  final _OnboardingPage page;
  final int pageIndex;
  final PageController pageController;
  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: Listenable.merge([pageController, float]),
          builder: (context, _) {
            final pageValue = pageController.hasClients
                ? (pageController.page ?? pageIndex.toDouble())
                : pageIndex.toDouble();
            final delta = pageValue - pageIndex;
            final absDelta = delta.abs().clamp(0.0, 1.0);
            final focus = (1.0 - absDelta).clamp(0.0, 1.0);

            final titleFocus = focus;
            final subtitleFocus = ((focus - 0.18) / 0.82).clamp(0.0, 1.0);

            final titleOpacity = Curves.easeOutCubic.transform(titleFocus);
            final subtitleOpacity = Curves.easeOutCubic.transform(subtitleFocus);

            final titleTranslateY = 18 * (1 - titleFocus);
            final subtitleTranslateY = 14 * (1 - subtitleFocus);
            final phoneScale = 1 - (0.04 * absDelta);
            final phoneParallaxX = -18 * delta;
            final phoneParallaxY = 10 * absDelta;
            final phoneRotation = page.phoneRotation + (0.05 * delta);

            final phoneWidth = constraints.maxWidth * page.phoneWidthFactor;
            final phoneHeight = phoneWidth * 2.05;
            final phoneBottom = constraints.maxHeight * page.phoneBottomFactor;
            final centeredLeft = (constraints.maxWidth - phoneWidth) / 2;
            final phoneLeft = centeredLeft + page.phoneOffset.dx;

            final bob = sin(float.value * pi * 2) * 4;

            return ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        Transform.translate(
                          offset: Offset(0, titleTranslateY),
                          child: Opacity(
                            opacity: titleOpacity,
                            child: Text(
                              page.title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Transform.translate(
                            offset: Offset(0, subtitleTranslateY),
                            child: Opacity(
                              opacity: subtitleOpacity,
                              child: Text(
                                page.subtitle,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  height: 1.55,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: page.showFloatingCards ? null : phoneLeft,
                    right: page.showFloatingCards ? -constraints.maxWidth * 0.12 : null,
                    bottom: phoneBottom + page.phoneOffset.dy,
                    child: Transform.translate(
                      offset: Offset(phoneParallaxX, phoneParallaxY),
                      child: Transform.scale(
                        scale: phoneScale,
                        child: Transform.rotate(
                          angle: phoneRotation,
                          child: _PhoneMockup(
                            assetPath: page.asset,
                            width: phoneWidth,
                            height: phoneHeight,
                            borderRadius: 40,
                            borderWidth: 5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (page.showFloatingCards) ...[
                    Positioned(
                      left: 24,
                      top: constraints.maxHeight * 0.52,
                      child: Transform.translate(
                        offset: Offset(-22 * (1 - focus), (18 * (1 - focus)) + bob),
                        child: Opacity(
                          opacity: titleOpacity,
                          child: _FareCard(
                            title: 'ETC Courier',
                            subtitle: 'Send and receive packages',
                            amount: '₦4,800.00',
                            background: _mustard,
                            textColor: AppColors.white,
                            iconAsset: AppAssets.etcCourierCardIcon,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 54,
                      top: constraints.maxHeight * 0.44,
                      child: Transform.translate(
                        offset: Offset(0, (-14 * (1 - focus)) - bob),
                        child: Opacity(
                          opacity: titleOpacity,
                          child: _FareCard(
                            title: 'ETC Premium',
                            subtitle: 'Faster Pickup',
                            amount: '₦4,800.00',
                            background: AppColors.white,
                            textColor: AppColors.textPrimary,
                            iconAsset: AppAssets.etcPremiumCardIcon,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    margin: const EdgeInsets.only(right: 8),
    width: 34,
    height: 4,
    decoration: BoxDecoration(
      color: active ? _mustard : _inactiveMustard,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _FareCard extends StatelessWidget {
  const _FareCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.background,
    required this.textColor,
    required this.iconAsset,
  });

  final String title;
  final String subtitle;
  final String amount;
  final Color background;
  final Color textColor;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 32,
            child: _EmbeddedPngFromSvgAsset(assetPath: iconAsset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: textColor,
            ),
          ),
        ],
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
      if (match == null) {
        throw const FormatException('No embedded PNG found.');
      }
      return base64Decode(match.group(1)!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Container(
            color: AppColors.surface,
            alignment: Alignment.center,
            child: const Text('Image failed to load'),
          );
        }
        if (!snap.hasData) {
          return Container(color: AppColors.surface);
        }
        return Image.memory(snap.data!, fit: fit, gaplessPlayback: true);
      },
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.borderWidth,
  });

  final String assetPath;
  final double width;
  final double height;
  final double borderRadius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final innerRadius = borderRadius - borderWidth;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.black, width: borderWidth),
        ),
        padding: EdgeInsets.all(borderWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: _EmbeddedPngFromSvgAsset(assetPath: assetPath),
        ),
      ),
    );
  }
}

class _GetStartedCta extends StatelessWidget {
  const _GetStartedCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.only(left: 22, right: 14),
          child: Row(
            children: [
              Text(
                AppStrings.getStarted,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.white,
                ),
              ),
              const Spacer(),
              Container(
                width: 78,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  AppAssets.arrowBendUpRight,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(AppColors.black, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
