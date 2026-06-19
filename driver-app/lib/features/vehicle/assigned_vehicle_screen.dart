import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/providers.dart';

class AssignedVehicleScreen extends ConsumerWidget {
  const AssignedVehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverProvider);
    final vehicle = driver?.assignedVehicle;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BackCircle(onTap: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  Text(
                    'Assigned Vehicle',
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 48),
              Center(child: _VehicleHeroImage(photoUrl: vehicle?.photoUrl)),
              const SizedBox(height: 42),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle?.displayName ?? 'No vehicle assigned',
                          style: AppTextStyles.h3.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vehicle?.plateNumber?.trim().isNotEmpty == true
                              ? vehicle!.plateNumber!.trim()
                              : 'Awaiting assignment',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _VehicleStatusPill(status: vehicle?.status),
                ],
              ),
              const SizedBox(height: 34),
              _VehicleDetailRow(
                label: 'Vehicle Type',
                value: vehicle?.vehicleType ?? '--',
              ),
              _VehicleDetailRow(label: 'Color', value: vehicle?.color ?? '--'),
              _VehicleDetailRow(label: 'Year', value: vehicle?.year ?? '--'),
              _VehicleDetailRow(
                label: 'Capacity',
                value: '--',
                showDivider: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleHeroImage extends StatelessWidget {
  const _VehicleHeroImage({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    final fallback = SvgPicture.asset(
      AppAssets.etcPremiumCardIcon,
      width: 290,
      height: 150,
      fit: BoxFit.contain,
    );

    if (!hasUrl) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 290,
        height: 150,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back_rounded, color: Colors.black, size: 20),
        ),
      ),
    );
  }
}

class _VehicleStatusPill extends StatelessWidget {
  const _VehicleStatusPill({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final isActive = (status ?? '').toLowerCase() == 'active';
    final background = isActive
        ? const Color(0xFFDDE8D9)
        : const Color(0xFFEAEAEA);
    final foreground = isActive
        ? const Color(0xFF188118)
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: AppTextStyles.bodyMedium.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VehicleDetailRow extends StatelessWidget {
  const _VehicleDetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: const Color(0xFFAEAEAE),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (showDivider) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE1E1E1)),
          ],
        ],
      ),
    );
  }
}
