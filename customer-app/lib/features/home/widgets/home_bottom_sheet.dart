import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/services/chat_notification_service.dart';
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
      case BookingStatus.pickedUp:
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
        BookingStatus.pickedUp => 'Package picked up',
        BookingStatus.inProgress => 'Trip in progress',
        BookingStatus.paymentPending => 'Payment pending',
        BookingStatus.completed => 'Trip completed',
        BookingStatus.paid => 'Paid',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.rejected => 'Rejected',
      };

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(authInitProvider);
    final user = ref.watch(currentUserProvider);
    final initializing = init.isLoading && user == null;
    final isComplete = !initializing &&
        user != null &&
        user.name.isNotEmpty &&
        (user.phone.isNotEmpty || user.email.isNotEmpty);
    final greeting = user != null && user.name.isNotEmpty
        ? AppFormatters.greeting(user.name)
        : AppFormatters.greeting('');
    final bookingType = _isRide ? 'ride' : 'delivery';
    final active          = ref.watch(activeBookingProvider(bookingType));
    final activeDeliveries = ref.watch(activeDeliveryBookingsProvider);

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
                if (!initializing && !isComplete)
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

            // ── Active ride (single) ──────────────────────────────────────
            if (_isRide)
              active.when(
                data: (b) {
                  if (b == null) return const SizedBox.shrink();
                  return Column(
                    children: [
                      _ActiveBookingCard(
                        booking: b,
                        label: 'Active trip',
                        onResume: () => _resumeBooking(b),
                        onChat: b.driverId != null
                            ? () => context.push(AppRoutes.driverChat, extra: b.id)
                            : null,
                        statusLabel: _statusLabel(b.status),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 8),
                error: (_, __) => const SizedBox(height: 8),
              ),

            // ── Active deliveries (multiple) ──────────────────────────────
            if (!_isRide)
              activeDeliveries.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      for (final b in list) ...[
                        _ActiveBookingCard(
                          booking: b,
                          label: 'Active delivery',
                          onResume: () => _resumeBooking(b),
                          onChat: b.driverId != null
                              ? () => context.push(AppRoutes.driverChat, extra: b.id)
                              : null,
                          statusLabel: _statusLabel(b.status),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 4),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 8),
                error: (_, __) => const SizedBox(height: 8),
              ),

            GestureDetector(
              onTap: () {
                if (_isRide) {
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
                }
                ref.read(bookingDraftProvider.notifier).state =
                    BookingDraft(bookingType: bookingType);
                showSearchDestinationDrawer(context);
              },
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.whereTo,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.white),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.scheduleDelivery,
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Ride / Couriers toggle ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: AppStrings.rideTab,
                    iconWidget: const SizedBox(
                      width: 22,
                      height: 22,
                      child: _EmbeddedPngFromSvgAsset(assetPath: AppAssets.carTabIcon),
                    ),
                    active: _isRide,
                    onTap: () => setState(() => _isRide = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ToggleChip(
                    label: AppStrings.couriersTab,
                    iconWidget: const SizedBox(
                      width: 22,
                      height: 22,
                      child: _EmbeddedPngFromSvgAsset(assetPath: AppAssets.motorbikeTabIcon),
                    ),
                    active: !_isRide,
                    onTap: () => setState(() => _isRide = false),
                  ),
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
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _QuickAction(
              icon: Icons.map_outlined,
              label: AppStrings.chooseOnMap,
              iconBg: AppColors.primary,
              onTap: () {
                if (_isRide) {
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

// ── Active booking card with chat badge ───────────────────────────────────────

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({
    required this.booking,
    required this.label,
    required this.statusLabel,
    required this.onResume,
    this.onChat,
  });

  final BookingModel booking;
  final String       label;
  final String       statusLabel;
  final VoidCallback onResume;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
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
                Text(label, style: AppTextStyles.labelMedium),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Chat button with unread badge
          if (onChat != null)
            ValueListenableBuilder<Map<String, int>>(
              valueListenable: ChatNotificationService.instance.unreadCounts,
              builder: (_, counts, __) {
                final unread = counts[booking.id] ?? 0;
                return GestureDetector(
                  onTap: onChat,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onResume,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    this.iconWidget,
    required this.active,
    required this.onTap,
  });
  final String label;
  final Widget? iconWidget;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: active ? AppColors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(
              size: 20,
              color: active ? AppColors.white : AppColors.textPrimary,
            ),
            child: iconWidget ?? const SizedBox.shrink(),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: active ? AppColors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({required this.assetPath});

  final String assetPath;

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
          fit: BoxFit.contain,
          gaplessPlayback: true,
          color: IconTheme.of(context).color,
          colorBlendMode: BlendMode.srcIn,
        );
      },
    );
  }
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
