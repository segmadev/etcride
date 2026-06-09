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
  });

  final String image;
  final String title;
  final String subtitle;
  final Color background;
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
    ),
    _OnboardingPage(
      image: AppAssets.onboarding2,
      title: AppStrings.ob2Title,
      subtitle: AppStrings.ob2Subtitle,
      background: Color(0xFFF9EBCF),
    ),
    _OnboardingPage(
      image: AppAssets.onboarding3,
      title: AppStrings.ob3Title,
      subtitle: AppStrings.ob3Subtitle,
      background: Color(0xFFF9EBCF),
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
      context.go(AppRoutes.signIn);
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
      body: Stack(
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
                  ColoredBox(
                    color: p.background,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Image.asset(
                        p.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.72,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                style: AppTextStyles.displayLarge.copyWith(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                p.subtitle,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _nextOrFinish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(27.5),
                                    ),
                                  ),
                                  child: Text(
                                    isLast ? AppStrings.getStarted : 'NEXT',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      letterSpacing: 0.3,
                                      fontWeight: FontWeight.w700,
                                    ),
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
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                      onPressed: () => context.go(AppRoutes.signIn),
                      child: Text(
                        AppStrings.skip,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: skipColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
