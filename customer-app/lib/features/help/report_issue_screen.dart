import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/providers/providers.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  bool _loading = true;
  String? _error;
  List<BookingModel> _bookings = const [];
  BookingModel? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await ref.read(bookingRepositoryProvider).getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = all.take(6).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openIssue(BookingModel b) => setState(() => _selected = b);

  String _short(String addr) => addr.isEmpty ? '' : addr.split(',').first.trim();

  String _dateTimeLabel(BookingModel b) {
    final raw = b.createdAt ?? '';
    if (raw.isEmpty) return 'Apr 22 • 9:03AM';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return _IssueChatView(
        booking: _selected!,
        onBack: () => setState(() => _selected = null),
        onContactSupport: () => context.push(AppRoutes.help),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.black,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                    children: [
                      SizedBox(
                        height: 74,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: _CircleIconButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => context.pop(),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 56, top: 14),
                                child: Text('Select a ride', style: AppTextStyles.h2),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _PillButton(
                                  label: 'VIEW ALL',
                                  onTap: () => context.push(AppRoutes.tripHistory),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final b in _bookings) ...[
                        _RideRow(
                          booking: b,
                          onReport: () => _openIssue(b),
                          shortPickup: _short(b.pickupAddress),
                          shortDest: _short(b.destinationAddress),
                          dateLabel: _dateTimeLabel(b),
                        ),
                        const Divider(height: 1),
                      ],
                      const SizedBox(height: 22),
                      Text('Common Topics', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TopicTile(
                              label: 'Payments & Wallet',
                              onTap: () => context.push(AppRoutes.commonTopics, extra: 'Payments & Wallet'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TopicTile(
                              label: 'Trips & Deliveries',
                              onTap: () => context.push(AppRoutes.commonTopics, extra: 'Trips & Deliveries'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TopicTile(
                              label: 'Account & Profile',
                              onTap: () => context.push(AppRoutes.commonTopics, extra: 'Account & Profile'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TopicTile(
                              label: 'Safety',
                              onTap: () => context.push(AppRoutes.commonTopics, extra: 'Safety'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _RideRow extends StatelessWidget {
  const _RideRow({
    required this.booking,
    required this.onReport,
    required this.shortPickup,
    required this.shortDest,
    required this.dateLabel,
  });

  final BookingModel booking;
  final VoidCallback onReport;
  final String shortPickup;
  final String shortDest;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final isDelivery = booking.bookingType == BookingType.delivery;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Center(
              child: Icon(
                isDelivery ? Icons.local_shipping_rounded : Icons.directions_car_rounded,
                size: 26,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      AppAssets.mapPin,
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(Color(0xFF0A9B4A), BlendMode.srcIn),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'From $shortPickup',
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0A9B4A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(AppFormatters.naira(booking.estimatedFare), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SvgPicture.asset(
                      AppAssets.mapPin,
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(Color(0xFFFF6A00), BlendMode.srcIn),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'To $shortDest',
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFFFF6A00)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateLabel,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    SizedBox(
                      height: 34,
                      child: _PillButton(
                        label: 'Report Issue',
                        icon: Icons.help_outline_rounded,
                        onTap: onReport,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppFormatters.naira(booking.estimatedFare)} ~ Successful',
                  style: AppTextStyles.caption.copyWith(color: const Color(0xFF0A9B4A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueChatView extends StatelessWidget {
  const _IssueChatView({
    required this.booking,
    required this.onBack,
    required this.onContactSupport,
  });

  final BookingModel booking;
  final VoidCallback onBack;
  final VoidCallback onContactSupport;

  String _short(String addr) => addr.isEmpty ? '' : addr.split(',').first.trim();

  @override
  Widget build(BuildContext context) {
    final date = booking.createdAt ?? 'Apr 22 • 9:03AM';
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          children: [
            SizedBox(
              height: 74,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: _CircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text('Report Issue', style: AppTextStyles.h2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5A01F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          booking.bookingType == BookingType.delivery ? Icons.local_shipping_rounded : Icons.directions_car_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _short(booking.destinationAddress),
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date,
                            style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.95)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${AppFormatters.naira(booking.estimatedFare)} ~ Successful',
                            style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.95)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E9E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hi John, welcome to customer support\nI just checked on this ride',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _OptionTile(
              label: 'Share feedback about this trip',
              showChevron: true,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _OptionTile(
              label: 'That will be all',
              onTap: onBack,
            ),
            const SizedBox(height: 12),
            _OptionTile(
              label: 'I need to talk with live agent',
              onTap: onContactSupport,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.onTap, this.showChevron = false});
  final String label;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))),
            if (showChevron) const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.white),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, letterSpacing: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
