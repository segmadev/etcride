import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/trip_card.dart';
import '../booking/search_destination_screen.dart';

class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // null = all, 'ride', 'delivery'
  static const List<String?> _filters = [null, 'ride', 'delivery'];
  static const _tabLabels = [
    AppStrings.allTab,
    AppStrings.ridesTab,
    AppStrings.couriersHistTab,
  ];

  final Map<int, List<BookingModel>> _cache = {};
  final Map<int, bool> _loading = {};
  final Map<int, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
      if (!_tabCtrl.indexIsChanging) _fetchTab(_tabCtrl.index);
    });
    _fetchTab(0);
  }

  void _rebook(BookingModel b) {
    // Prefill the booking draft with the previous trip's locations and type
    ref.read(bookingDraftProvider.notifier).state = BookingDraft(
      bookingType:        b.bookingType.apiValue,
      pickupAddress:      b.pickupAddress,
      pickupLat:          b.pickupLat,
      pickupLng:          b.pickupLng,
      destinationAddress: b.destinationAddress,
      destinationLat:     b.destinationLat,
      destinationLng:     b.destinationLng,
    );
    showSearchDestinationDrawer(context);
  }

  Future<void> _fetchTab(int idx) async {
    if (_loading[idx] == true) return;
    setState(() { _loading[idx] = true; _errors[idx] = null; });
    try {
      final all = await ref.read(bookingRepositoryProvider).getMyBookings();
      final filter = _filters[idx];
      final result = filter == null
          ? all
          : all.where((b) => b.bookingType.apiValue == filter).toList();
      if (mounted) setState(() { _cache[idx] = result; _loading[idx] = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _errors[idx] = e.toString(); _loading[idx] = false; });
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: SizedBox(
                height: 92,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.home);
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppStrings.tripHistory, style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.recentRides,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _PillTabs(
                index: _tabCtrl.index,
                labels: _tabLabels,
                onChanged: (i) {
                  _tabCtrl.animateTo(i);
                  _fetchTab(i);
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: List.generate(3, (idx) {
                  if (_loading[idx] == true) {
                    return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (_errors[idx] != null) {
                    return _ErrorState(
                      message: _errors[idx]!,
                      onRetry: () => _fetchTab(idx),
                    );
                  }
                  final bookings = _cache[idx] ?? [];
                  if (bookings.isEmpty) {
                    return _EmptyState(
                        onBook: () => showSearchDestinationDrawer(context));
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => _fetchTab(idx),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: bookings.length,
                      itemBuilder: (_, i) => TripCard(
                        booking: bookings[i],
                        onTap: () => context.push(AppRoutes.tripDetails,
                            extra: bookings[i].id),
                        onRebook: () => _rebook(bookings[i]),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(labels.length, (i) {
        final selected = i == index;
        return Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 14),
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.disabled,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labels[i].toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected ? AppColors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(AppAssets.noTrip, width: 170, height: 170),
              const SizedBox(height: 20),
              Text(AppStrings.noTripsYet, style: AppTextStyles.h4),
              const SizedBox(height: 8),
              Text(AppStrings.noTripsSub,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              AppButton(label: AppStrings.bookARide, onPressed: onBook),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(label: 'Retry', onPressed: onRetry),
            ],
          ),
        ),
      );
}
