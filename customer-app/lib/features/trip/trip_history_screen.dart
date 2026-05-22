import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
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
      if (!_tabCtrl.indexIsChanging) _fetchTab(_tabCtrl.index);
    });
    _fetchTab(0);
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
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(AppStrings.tripHistory, style: AppTextStyles.h4),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelMedium,
          tabs: _tabLabels.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
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
                onRebook: () => showSearchDestinationDrawer(context),
              ),
            ),
          );
        }),
      ),
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
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: AppColors.surface, shape: BoxShape.circle),
                child: const Icon(Icons.history_rounded,
                    size: 40, color: AppColors.textHint),
              ),
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
