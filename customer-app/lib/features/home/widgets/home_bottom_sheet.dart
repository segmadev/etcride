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

class HomeBottomSheet extends ConsumerStatefulWidget {
  const HomeBottomSheet({super.key});

  @override
  ConsumerState<HomeBottomSheet> createState() => _HomeBottomSheetState();
}

class _HomeBottomSheetState extends ConsumerState<HomeBottomSheet> {
  bool _isRide = true; // toggle: Ride vs Couriers

  void _resumeBooking(BookingModel b) {
    switch (b.status) {
      case BookingStatus.pending:
        context.go(AppRoutes.requesting, extra: b.id);
      case BookingStatus.assigned:
      case BookingStatus.accepted:
      case BookingStatus.arrived:
        context.go(AppRoutes.driverAssigned, extra: b.id);
      case BookingStatus.inProgress:
        context.go(AppRoutes.tripInProgress, extra: b.id);
      case BookingStatus.paymentPending:
      case BookingStatus.completed:
        context.go(AppRoutes.payment, extra: b.id);
      case BookingStatus.paid:
        context.go(AppRoutes.tripCompleted, extra: b.id);
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
        break;
    }
  }

  String _statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.pending => 'Searching for driver',
        BookingStatus.assigned => 'Driver assigned',
        BookingStatus.accepted => 'Driver accepted',
        BookingStatus.arrived => 'Driver arrived',
        BookingStatus.inProgress => 'Trip in progress',
        BookingStatus.paymentPending => 'Payment pending',
        BookingStatus.completed => 'Trip completed',
        BookingStatus.paid => 'Paid',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
      };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isComplete = user != null && user.name.isNotEmpty;
    final greeting = user != null && user.name.isNotEmpty
        ? AppFormatters.greeting(user.name)
        : AppFormatters.greeting('');
    final bookingType = _isRide ? 'ride' : 'delivery';
    final active = ref.watch(activeBookingProvider(bookingType));

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.28,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.28, 0.38, 0.55],
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
                Expanded(
                  child: Text(greeting, style: AppTextStyles.h3),
                ),
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
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11,
                            fontWeight: FontWeight.w600, color: AppColors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            active.when(
              data: (b) {
                if (b == null) return const SizedBox.shrink();
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.route_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Active trip', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 2),
                                Text(
                                  _statusLabel(b.status),
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _resumeBooking(b),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            child: const Text('Resume'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
              loading: () => const SizedBox(height: 8),
              error: (_, __) => const SizedBox(height: 8),
            ),

            // ── Search bar + Schedule delivery ────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final b = active.valueOrNull;
                      if (b != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You already have an active trip. Resuming it.'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                        _resumeBooking(b);
                        return;
                      }
                      ref.read(bookingDraftProvider.notifier).state =
                          BookingDraft(bookingType: bookingType);
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
                  onTap: () {}, // TODO: schedule delivery
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
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontSize: 11)),
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
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved places coming soon.')),
                    );
                  },
            ),
            const Divider(height: 1),
            _QuickAction(
              icon: Icons.map_outlined,
              label: AppStrings.chooseOnMap,
              iconBg: AppColors.primary,
              onTap: () {
                final b = active.valueOrNull;
                if (b != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You already have an active trip. Resuming it.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                  _resumeBooking(b);
                  return;
                }
                ref.read(bookingDraftProvider.notifier).state =
                    BookingDraft(bookingType: bookingType);
                context.push(AppRoutes.confirmPickup);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
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
