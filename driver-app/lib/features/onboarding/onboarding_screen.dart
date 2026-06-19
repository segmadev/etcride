import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';

const _mustard = Color(0xFFE2A322);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.background,
    this.titleFontSize = 40,
  });

  final String image;
  final String title;
  final String subtitle;
  final Color background;
  final double titleFontSize;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      image: AppAssets.onboarding1,
      title: AppStrings.ob1Title,
      subtitle: AppStrings.ob1Subtitle,
      background: Color(0xFFF9EBCF),
      titleFontSize: 40,
    ),
    _OnboardingPage(
      image: AppAssets.onboarding2,
      title: AppStrings.ob2Title,
      subtitle: AppStrings.ob2Subtitle,
      background: Color(0xFFF9EBCF),
      titleFontSize: 40,
    ),
    _OnboardingPage(
      image: AppAssets.onboarding3,
      title: AppStrings.ob3Title,
      subtitle: AppStrings.ob3Subtitle,
      background: Color(0xFFF9EBCF),
      titleFontSize: 40,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _nextOrFinish() async {
    final isLast = _page == _pages.length - 1;
    if (isLast) {
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }
    await _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    final skipColor = _page == 1 ? AppColors.white : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: _pages[_page].background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;

          return Stack(
            children: [
              PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: p.background),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: height * 0.695,
                        child: Image.asset(
                          p.image,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: height * 0.58,
                        bottom: 0,
                        child: _OnboardingSheet(
                          page: p,
                          isLast: isLast,
                          onPressed: _nextOrFinish,
                        ),
                      ),
                    ],
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 18, 26, 0),
                  child: Row(
                    children: [
                      Row(
                        children: List.generate(
                          _pages.length,
                          (i) => _Bar(active: i == _page),
                        ),
                      ),
                      const Spacer(),
                      if (!isLast)
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          style: TextButton.styleFrom(
                            foregroundColor: skipColor,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            AppStrings.skip,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
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

class _OnboardingSheet extends StatelessWidget {
  const _OnboardingSheet({
    required this.page,
    required this.isLast,
    required this.onPressed,
  });

  final _OnboardingPage page;
  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(60)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 66, 26, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  page.title,
                  style: AppTextStyles.displayLarge.copyWith(
                    fontSize: page.titleFontSize,
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 324),
                child: Text(
                  page.subtitle,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27.5),
                    ),
                  ),
                  child: Text(
                    isLast ? AppStrings.getStarted : 'NEXT',
                    style: AppTextStyles.labelLarge.copyWith(
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: active ? _mustard : _mustard.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
