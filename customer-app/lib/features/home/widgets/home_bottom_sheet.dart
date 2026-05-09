import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/booking_model.dart';
import '../../booking/search_destination_screen.dart';
import '../../auth/complete_profile_screen.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/trip_card.dart';

class HomeBottomSheet extends ConsumerStatefulWidget {
  const HomeBottomSheet({super.key});

  @override
  ConsumerState<HomeBottomSheet> createState() => _HomeBottomSheetState();
}

class _HomeBottomSheetState extends ConsumerState<HomeBottomSheet> {
  bool _isRide = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Poll for active ride every 10 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidate(activeBookingProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _resumeRide(BookingModel b) {
    final route = switch (b.status) {
      BookingStatus.pending                                         => AppRoutes.requesting,
      BookingStatus.assigned ||
      BookingStatus.accepted ||
      BookingStatus.arrived                                         => AppRoutes.driverAssigned,
      BookingStatus.inProgress                                      => AppRoutes.tripInProgress,
      BookingStatus.paymentPending                                  => AppRoutes.payment,
      _                                                             => AppRoutes.home,
    };
    context.go(route, extra: b.id);
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final isComplete = user != null && user.name.isNotEmpty;
    final greeting  = AppFormatters.greeting(user?.name ?? '');
    final activeAsync = ref.watch(activeBookingProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.28,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.28, 0.38, 0.55, 0.65],
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Greeting ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: Text(greeting, style: AppTextStyles.h3)),
                if (!isComplete)
                  GestureDetector(
                    onTap: () => showCompleteProfileDrawer(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(AppStrings.completeYourProfile,
                          style: const TextStyle(
                              fontFamily: 'Inter', fontSize: 11,
                              fontWeight: FontWeight.w600, color: AppColors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Active ride banner ────────────────────────────────────────
            activeAsync.when(
              data: (active) => active != null
                  ? _ActiveRideBanner(booking: active, onResume: () => _resumeRide(active))
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Search bar + Schedule ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(bookingDraftProvider.notifier).state =
                          BookingDraft(bookingType: _isRide ? 'ride' : 'delivery');
                      showSearchDestinationDrawer(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                          const SizedBox(width: 8),
                          Text(AppStrings.whereTo,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.white),
                        const SizedBox(width: 6),
                        Text(AppStrings.scheduleDelivery,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Ride / Couriers toggle ────────────────────────────────────
            Row(
              children: [
                _ToggleChip(
                  label: AppStrings.rideTab,
                  icon: Icons.directions_car_rounded,
                  active: _isRide,
                  onTap: () => setState(() => _isRide = true),
                ),
                const SizedBox(width: 10),
                _ToggleChip(
                  label: AppStrings.couriersTab,
                  icon: Icons.delivery_dining_rounded,
                  active: !_isRide,
                  onTap: () => setState(() => _isRide = false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Quick actions ─────────────────────────────────────────────
            _QuickAction(
              icon: Icons.star_rounded,
              label: AppStrings.savedPlaces,
              iconBg: AppColors.primary,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved places coming soon.'))),
            ),
            const Divider(height: 1),
            _QuickAction(
              icon: Icons.map_outlined,
              label: AppStrings.chooseOnMap,
              iconBg: AppColors.primary,
              onTap: () {
                ref.read(bookingDraftProvider.notifier).state =
                    BookingDraft(bookingType: _isRide ? 'ride' : 'delivery');
                context.push(AppRoutes.confirmPickup);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active ride banner ────────────────────────────────────────────────────────

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.booking, required this.onResume});
  final BookingModel booking;
  final VoidCallback onResume;

  String get _statusLabel => statusLabel(booking.status);

  IconData get _statusIcon => switch (booking.status) {
    BookingStatus.pending        => Icons.search_rounded,
    BookingStatus.assigned ||
    BookingStatus.accepted       => Icons.directions_car_rounded,
    BookingStatus.arrived        => Icons.location_on_rounded,
    BookingStatus.inProgress     => Icons.play_arrow_rounded,
    BookingStatus.paymentPending => Icons.payments_rounded,
    _                            => Icons.directions_car_rounded,
  };

  String get _ctaLabel => switch (booking.status) {
    BookingStatus.inProgress     => 'Resume',
    BookingStatus.paymentPending => 'Pay Now',
    _                            => 'Track Ride',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onResume,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Pulsing status icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(_statusIcon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),

            // Status + route
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    booking.pickupAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.arrow_downward_rounded, size: 10, color: Colors.white38),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          booking.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // CTA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _ctaLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.icon, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.black : AppColors.inputFill,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? AppColors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600,
                    color: active ? AppColors.white : AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.iconBg, required this.onTap});
  final IconData icon;
  final String label;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
          child: Icon(icon, size: 20, color: AppColors.white),
        ),
        title: Text(label, style: AppTextStyles.bodyLarge),
        onTap: onTap,
      );
}
