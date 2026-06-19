import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/pre_dashboard_account_menu.dart';

class KycPendingScreen extends ConsumerStatefulWidget {
  const KycPendingScreen({super.key});

  @override
  ConsumerState<KycPendingScreen> createState() => _KycPendingScreenState();
}

class _KycPendingScreenState extends ConsumerState<KycPendingScreen> {
  bool _refreshing = false;

  Future<void> _refreshStatus() async {
    if (_refreshing) {
      return;
    }

    setState(() => _refreshing = true);

    try {
      final driver = await ref.read(driverAuthRepositoryProvider).getProfile();
      ref.read(currentDriverProvider.notifier).state = driver;
      await ref.read(driverAuthRepositoryProvider).updateCachedDriver(driver);

      if (!mounted) {
        return;
      }

      switch (driver.kycStatus) {
        case 'verified':
          context.go(AppRoutes.verified);
        case 'rejected':
          context.go(AppRoutes.kyc);
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Verification is still under review."),
            ),
          );
      }
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Spacer(),
                    const PreDashboardAccountMenu(compact: true),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Refresh status',
                      child: InkWell(
                        onTap: _refreshing ? null : _refreshStatus,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: Center(
                            child: _refreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Image.asset(
                  'assets/icons/kycverify.png',
                  width: 190,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                Text(
                  'Application under review',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'We are reviewing your documents and account details. Once approved, ETC will assign you a vehicle and activate your driver account.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 26),
                const _ReviewTimeline(),
                const SizedBox(height: 26),
                AppButton(
                  label: 'CONTACT SUPPORT',
                  height: 48,
                  icon: const Icon(Icons.support_agent_rounded),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support contact will be available here soon.'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1E8D8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Average approval time is 24-48 hours',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

class _ReviewTimeline extends StatelessWidget {
  const _ReviewTimeline();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _ReviewStepData(label: 'Registration completed', isDone: true),
      _ReviewStepData(label: 'Documents uploaded', isDone: true),
      _ReviewStepData(label: 'Admin review'),
      _ReviewStepData(label: 'Vehicle assignment'),
    ];

    return Column(
      children: [
        SizedBox(
          height: 74.0 * steps.length,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimelineRail(
                itemCount: steps.length,
                completedCount: 2,
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: List.generate(steps.length, (index) {
                    return _ReviewStep(
                      data: steps[index],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewStepData {
  const _ReviewStepData({
    required this.label,
    this.isDone = false,
  });

  final String label;
  final bool isDone;
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.data,
  });

  final _ReviewStepData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                data.label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            if (data.isDone)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: SvgPicture.asset(
                  AppAssets.tickIcon,
                  width: 24,
                  height: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.itemCount,
    required this.completedCount,
  });

  final int itemCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    const itemHeight = 74.0;
    const dotSize = 14.0;
    const railWidth = 26.0;
    const firstCenterY = 14.0;
    final lastCenterY = firstCenterY + ((itemCount - 1) * itemHeight);
    final activeEndY = completedCount <= 0
        ? firstCenterY
        : firstCenterY + ((completedCount - 1) * itemHeight);

    return SizedBox(
      width: railWidth,
      child: Stack(
        children: [
          Positioned(
            left: (railWidth - 2) / 2,
            top: firstCenterY,
            bottom: itemHeight - firstCenterY,
            child: Container(
              width: 2,
              color: const Color(0xFFD9D9D9),
            ),
          ),
          Positioned(
            left: (railWidth - 2) / 2,
            top: firstCenterY,
            height: (activeEndY - firstCenterY).clamp(0, lastCenterY - firstCenterY),
            child: Container(
              width: 2,
              color: AppColors.primary,
            ),
          ),
          for (var index = 0; index < itemCount; index++)
            Positioned(
              left: (railWidth - dotSize) / 2,
              top: firstCenterY - (dotSize / 2) + (index * itemHeight),
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: index < completedCount
                      ? AppColors.primary
                      : const Color(0xFFD9D9D9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
