import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/maps/maps_service.dart';
import '../../data/models/booking_model.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_bottom_drawer.dart';
import '../../shared/widgets/trip_quick_nav.dart';

class DriverAssignedScreen extends ConsumerStatefulWidget {
  const DriverAssignedScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
  });

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
        );
      },
    );
  }
}

class _DriverAssignedScreenState extends ConsumerState<DriverAssignedScreen> {
  BookingModel? _booking;
  Timer? _pollTimer;
  Timer? _waitingTimer;
  int    _waitingElapsedSecs = 0;
  bool _cancelling = false;
  final _noteCtrl = TextEditingController();

  // Driver position — updated by poll, animation handled inside _RoutedMapView
  LatLng? _driverTarget;

  // Unread message count (driver → customer messages since last chat open)
  int _unreadMsgCount = 0;
  Timer? _msgPollTimer;
  DateTime _lastMsgPollAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer    = Timer.periodic(const Duration(seconds: 5),  (_) => _load());
    _msgPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollMessages());
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = b);
      _loadTrack(b);

      switch (b.status) {
        case BookingStatus.arrived:
          _startWaitingTimer(b);
        case BookingStatus.pickedUp:
          _cancelWaitingTimer();
        case BookingStatus.inProgress:
          _cancelWaitingTimer();
          _pollTimer?.cancel();
          context.go(AppRoutes.tripInProgress, extra: widget.bookingId);
        case BookingStatus.completed:
        case BookingStatus.paymentPending:
          _cancelWaitingTimer();
          _pollTimer?.cancel();
          context.go(AppRoutes.payment, extra: widget.bookingId);
        case BookingStatus.cancelled:
          _cancelWaitingTimer();
          _pollTimer?.cancel();
          if (mounted) {
            ref.invalidate(activeBookingProvider('ride'));
            ref.invalidate(activeBookingProvider('delivery'));
            _showCancelledDialog(b);
          }
        case BookingStatus.pending:
          // Driver was unassigned (e.g. rejected) — go back to requesting screen
          _cancelWaitingTimer();
          _pollTimer?.cancel();
          if (mounted) {
            context.go(AppRoutes.requesting, extra: widget.bookingId);
          }
        default:
          _cancelWaitingTimer();
          break;
      }
    } catch (_) {}
  }

  void _startWaitingTimer(BookingModel b) {
    final arrivedAt = b.arrivedAt;
    if (_waitingTimer == null) {
      // First time: seed elapsed from server-side arrived_at
      if (arrivedAt != null) {
        try {
          final t = DateTime.parse(arrivedAt).toLocal();
          final initial = DateTime.now().difference(t).inSeconds;
          if (!mounted) return;
          _waitingElapsedSecs = initial.clamp(0, 86400);
        } catch (_) {}
      }
      _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _waitingElapsedSecs++);
      });
    } else if (arrivedAt != null) {
      // Timer already running — drift-correct if server says we're off by >2s
      try {
        final t = DateTime.parse(arrivedAt).toLocal();
        final serverElapsed = DateTime.now().difference(t).inSeconds.clamp(0, 86400);
        if ((serverElapsed - _waitingElapsedSecs).abs() > 2 && mounted) {
          setState(() => _waitingElapsedSecs = serverElapsed);
        }
      } catch (_) {}
    }
  }

  void _cancelWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
  }

  void _showCancelledDialog(BookingModel b) {
    if (!mounted) return;
    final reason = (b.cancellationReason ?? '').trim();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Trip Cancelled', style: AppTextStyles.h4.copyWith(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your trip has been cancelled.',
                style: AppTextStyles.bodyMedium),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('"$reason"',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) context.go(AppRoutes.home);
              },
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTrack(BookingModel b) async {
    if (b.driverId == null) return;
    try {
      final t = await ref.read(bookingRepositoryProvider).trackBooking(widget.bookingId);
      if (!mounted) return;
      final lat = t.lat;
      final lng = t.lng;
      if (lat == null || lng == null) return;
      // Only update if position actually changed to avoid unnecessary setState
      final next = LatLng(lat, lng);
      if (_driverTarget?.latitude != next.latitude ||
          _driverTarget?.longitude != next.longitude) {
        setState(() => _driverTarget = next);
      }
    } catch (_) {}
  }

  Future<void> _cancel() async {
    final b = _booking;
    final isArrived = b?.status == BookingStatus.arrived;

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CancelReasonSheet(
        subtitle: isArrived
            ? 'Your driver has arrived. Please let us know why you need to cancel.'
            : 'Please let us know why you\'re cancelling.',
        reasons: const [
          'Changed my mind',
          'Driver is taking too long',
          'Wrong driver or vehicle details',
          'Booked by mistake',
          'Found another ride',
        ],
      ),
    );

    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      _pollTimer?.cancel();
      await ref.read(bookingRepositoryProvider)
          .cancelBooking(widget.bookingId, reason: reason);
      ref.invalidate(activeBookingProvider('ride'));
      ref.invalidate(activeBookingProvider('delivery'));
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
        setState(() {
          _cancelling = false;
          _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
        });
      }
    }
  }


  Future<void> _showCallSheet() async {
    final b = _booking;
    if (b == null) return;
    final name = b.driverName ?? 'Driver';
    final phone = b.driverPhone ?? '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 22),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Call $name', style: AppTextStyles.h4, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: phone.isEmpty
                      ? null
                      : () async {
                          final uri = Uri.parse('tel:$phone');
                          await launchUrl(uri);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    phone.isEmpty ? '—' : phone,
                    style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pollMessages() async {
    if (_booking == null) return;
    try {
      final msgs = await ref.read(bookingRepositoryProvider)
          .getMessages(widget.bookingId, since: _lastMsgPollAt);
      if (!mounted) return;
      final fromDriver = msgs.where((m) => m.senderRole == 'driver').toList();
      if (fromDriver.isNotEmpty) {
        setState(() => _unreadMsgCount += fromDriver.length);
        _lastMsgPollAt = fromDriver.last.createdAt;
      }
    } catch (_) {}
  }

  void _openChat() {
    final b = _booking;
    if (b == null) return;
    setState(() => _unreadMsgCount = 0);
    _lastMsgPollAt = DateTime.now();
    context.push(AppRoutes.driverChat, extra: widget.bookingId);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgPollTimer?.cancel();
    _waitingTimer?.cancel();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b         = _booking;
    final mapKey    = ref.watch(mapApiKeyProvider);
    final isArrived = b?.status == BookingStatus.arrived;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map — owns route, driver animation, approach line ─────────────
          _RoutedMapView(
            booking:      b,
            apiKey:       mapKey,
            driverTarget: _driverTarget,
          ),

          // ── Back button ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  MapOverlayButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.go(AppRoutes.home),
                  ),
                ],
              ),
            ),
          ),

          // ── Arrived / waiting-timer banner + graph ───────────────────────
          if (isArrived && b != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WaitingTimerBanner(
                        elapsedSecs:     _waitingElapsedSecs,
                        freeWaitingSecs: b.freeWaitingMinutes * 60,
                        chargePerMin:    b.waitingChargePerMin,
                      ),
                      if (b.waitingChargePerMin > 0) ...[
                        const SizedBox(height: 6),
                        _WaitingProgressGraph(
                          elapsedSecs:     _waitingElapsedSecs,
                          freeWaitingSecs: b.freeWaitingMinutes * 60,
                          chargePerMin:    b.waitingChargePerMin,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom driver card (collapsible — drag down to see full map) ───
          Positioned.fill(
            child: b == null
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.white,
                      padding: const EdgeInsets.all(32),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    ),
                  )
                : CollapsibleMapSheet(
                    child: _AssignedSheet(
                      booking:            b,
                      noteCtrl:           _noteCtrl,
                      cancelling:         _cancelling,
                      waitingElapsedSecs: _waitingElapsedSecs,
                      unreadMsgCount:     _unreadMsgCount,
                      onCancel:   _cancel,
                      onCall:     _showCallSheet,
                      onChat:     _openChat,
                      onNeedHelp: () => context.push(AppRoutes.help),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AssignedSheet extends StatelessWidget {
  const _AssignedSheet({
    required this.booking,
    required this.noteCtrl,
    required this.cancelling,
    required this.waitingElapsedSecs,
    required this.unreadMsgCount,
    required this.onCancel,
    required this.onCall,
    required this.onChat,
    required this.onNeedHelp,
  });

  final BookingModel booking;
  final TextEditingController noteCtrl;
  final bool cancelling;
  final int  waitingElapsedSecs;
  final int  unreadMsgCount;
  final VoidCallback onCancel;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onNeedHelp;

  String _short(String addr) => addr.split(',').first.trim();

  int get _arrivingMins {
    // Prefer driver-to-pickup ETA (calculated server-side from driver's live location).
    // Fall back to trip route duration as a rough proxy if ETA not yet available.
    if (booking.driverEtaMinutes > 0) return booking.driverEtaMinutes;
    final sec = booking.routeDurationSeconds;
    if (sec <= 0) return 4;
    return (sec / 60).ceil().clamp(1, 9999);
  }

  @override
  Widget build(BuildContext context) {
    final name = booking.driverName ?? 'Driver';
    final plate = booking.vehiclePlate ?? '';
    final color = booking.vehicleColor ?? '';
    final vehicleName = booking.vehicleTypeName ?? 'Vehicle';

    final isDelivery = booking.bookingType == BookingType.delivery;
    final isPickedUp = booking.status == BookingStatus.pickedUp;

    // Heading & subtitle based on status
    final (heading, subtitle) = switch (booking.status) {
      BookingStatus.arrived  => isDelivery
          ? ('Driver arrived', 'Driver has arrived to collect your package.')
          : ('Your driver has arrived!', 'Please come out to the pickup spot.'),
      BookingStatus.pickedUp => ('Package picked up', 'Your package has been collected'),
      _                      => isDelivery
          ? ('Driver heading to pickup', 'Meet your driver at the pickup spot.')
          : ('Arriving in $_arrivingMins mins…', 'Meet your driver at the pickup spot.'),
    };

    // ETA shown in the right box for delivery bookings
    final etaMins = switch (booking.status) {
      BookingStatus.pickedUp =>
          booking.routeDurationSeconds > 0
              ? (booking.routeDurationSeconds / 60).ceil().clamp(1, 999)
              : _arrivingMins,
      _ => _arrivingMins,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Heading row ───────────────────────────────────────────────────
          if (isDelivery)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading, style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _EtaBox(minutes: etaMins),
              ],
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(heading, style: AppTextStyles.h4),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],

          // ── Delivery progress bar ─────────────────────────────────────────
          if (isDelivery) ...[
            const SizedBox(height: 14),
            _DeliveryProgressBar(status: booking.status),
          ],

          // ── Inline waiting-charge row (arrived only) ─────────────────
          if (booking.status == BookingStatus.arrived && booking.waitingChargePerMin > 0) ...[
            const SizedBox(height: 10),
            _InlineWaitingCharge(
              elapsedSecs:     waitingElapsedSecs,
              freeWaitingSecs: booking.freeWaitingMinutes * 60,
              chargePerMin:    booking.waitingChargePerMin,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.person_rounded, size: 30, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 90,
                    child: Text(
                      name,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final filled = i < booking.driverRating.round().clamp(0, 5);
                      return Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14,
                        color: AppColors.primary,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: _EmbeddedPngFromSvgAsset(
                      assetPath: booking.bookingType == BookingType.delivery
                          ? AppAssets.courierIcon
                          : AppAssets.carIcon,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicleName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  if (plate.isNotEmpty) Text(plate, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  if (color.isNotEmpty) Text(color, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _RoundAction(
                icon: Icons.call_rounded,
                onTap: onCall,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add note for driver (optional)',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _RoundAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: onChat,
                  ),
                  if (unreadMsgCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          unreadMsgCount > 9 ? '9+' : unreadMsgCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: const [
                  _PinIcon(),
                  SizedBox(height: 8),
                  _DottedVLine(height: 32),
                  SizedBox(height: 8),
                  _PinIcon(),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From ${_short(booking.pickupAddress)}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Text('To ${_short(booking.destinationAddress)}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.share_outlined, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(child: Text('Share trip status', style: AppTextStyles.bodyMedium)),
              Text(
                'Share',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (!isPickedUp) ...[
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: cancelling ? null : onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: const Color(0xFF6B6B6B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text(
                        cancelling ? '...' : 'CANCEL',
                        style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onNeedHelp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      'NEED HELP?',
                      style: AppTextStyles.labelLarge.copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Waiting timer banner (shown over the map when driver has arrived) ─────────

class _WaitingTimerBanner extends StatelessWidget {
  const _WaitingTimerBanner({
    required this.elapsedSecs,
    required this.freeWaitingSecs,
    required this.chargePerMin,
  });
  final int    elapsedSecs;
  final int    freeWaitingSecs;
  final double chargePerMin;

  String _fmt(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (freeWaitingSecs - elapsedSecs).clamp(0, freeWaitingSecs);
    final charging  = elapsedSecs > freeWaitingSecs;
    final extraSecs = charging ? (elapsedSecs - freeWaitingSecs) : 0;
    final extraCharge = (extraSecs / 60) * chargePerMin;

    final bgColor   = charging ? const Color(0xFFD84315) : AppColors.success;
    final icon      = charging ? Icons.timer_off_rounded : Icons.timer_rounded;
    final label     = charging
        ? '₦${extraCharge.toStringAsFixed(2)} extra  •  ${_fmt(extraSecs)} over free time'
        : 'Free waiting: ${_fmt(remaining)} remaining';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waiting progress graph ────────────────────────────────────────────────────
//
// Horizontal track visualising:
//   [green ▓▓▓▓ elapsed free] [grey ░░░░ remaining free] [red ██ paid time]
//
// The green segment fills as time elapses; once free time is used the red
// segment grows from the right. A small label shows the current extra cost.

class _WaitingProgressGraph extends StatelessWidget {
  const _WaitingProgressGraph({
    required this.elapsedSecs,
    required this.freeWaitingSecs,
    required this.chargePerMin,
  });
  final int    elapsedSecs;
  final int    freeWaitingSecs;
  final double chargePerMin;

  @override
  Widget build(BuildContext context) {
    // Clamp fractions to [0,1]
    final freeFrac  = freeWaitingSecs > 0
        ? (elapsedSecs / freeWaitingSecs).clamp(0.0, 1.0)
        : 1.0;
    final charging  = elapsedSecs > freeWaitingSecs;
    final extraSecs = charging ? (elapsedSecs - freeWaitingSecs) : 0;
    final extraCharge = (extraSecs / 60) * chargePerMin;

    // Extra bar width: grows by 1 "free bar" width per extra free-period elapsed.
    // Cap visual overflow at 2× the free-bar width for compact display.
    const barH = 8.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Track ──────────────────────────────────────────────────────────
          LayoutBuilder(builder: (_, c) {
            final totalW = c.maxWidth;
            // Free section occupies full width; paid section overlaps right edge
            final freeUsedW  = totalW * freeFrac;
            // Extra section: each additional minute = 1 × (totalW / freeWaitingMins)
            final extraMins  = extraSecs / 60.0;
            final perMinW    = freeWaitingSecs > 0
                ? (totalW / (freeWaitingSecs / 60.0))
                : totalW;
            final extraW     = (extraMins * perMinW).clamp(0.0, totalW * 0.6);

            return SizedBox(
              height: barH + 6, // bar + tick margin
              child: Stack(
                children: [
                  // Background (free remaining) – grey
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(barH / 2),
                      child: Container(color: const Color(0xFFDDDDDD)),
                    ),
                  ),
                  // Green: elapsed free time
                  if (freeUsedW > 0)
                    Positioned(
                      left: 0, top: 0, bottom: 0,
                      width: freeUsedW.clamp(0.0, totalW),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft:     const Radius.circular(4),
                          bottomLeft:  const Radius.circular(4),
                          topRight:    Radius.circular(freeFrac >= 1.0 ? 4 : 0),
                          bottomRight: Radius.circular(freeFrac >= 1.0 ? 4 : 0),
                        ),
                        child: Container(color: AppColors.success),
                      ),
                    ),
                  // Red: paid extra time — grows from the far right edge inward
                  if (extraW > 0)
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      width: extraW,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight:    Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                        child: Container(color: const Color(0xFFD84315)),
                      ),
                    ),
                  // Divider tick at the free/paid boundary (right edge of green)
                  if (freeFrac >= 1.0)
                    Positioned(
                      right: 0,
                      top: -3,
                      child: Container(
                        width: 2, height: barH + 6,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          // ── Labels ─────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${freeWaitingSecs ~/ 60} min free',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              if (charging)
                Text(
                  '+ ₦${extraCharge.toStringAsFixed(2)}',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFFD84315),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  '₦${chargePerMin.toStringAsFixed(0)}/min after',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Inline charge row shown inside the bottom sheet ───────────────────────────

class _InlineWaitingCharge extends StatelessWidget {
  const _InlineWaitingCharge({
    required this.elapsedSecs,
    required this.freeWaitingSecs,
    required this.chargePerMin,
  });
  final int    elapsedSecs;
  final int    freeWaitingSecs;
  final double chargePerMin;

  @override
  Widget build(BuildContext context) {
    final remaining = (freeWaitingSecs - elapsedSecs).clamp(0, freeWaitingSecs);
    final charging  = elapsedSecs > freeWaitingSecs;
    final extraSecs = charging ? (elapsedSecs - freeWaitingSecs) : 0;
    final extraCharge = (extraSecs / 60) * chargePerMin;

    final m = remaining ~/ 60, s = remaining % 60;
    final fmtFree = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: charging
            ? const Color(0xFFFBE9E7)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: charging
          ? Row(
              children: [
                const Icon(Icons.timer_off_rounded, size: 16, color: Color(0xFFD84315)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Waiting charge: ₦${extraCharge.toStringAsFixed(2)}'
                    '  (₦${chargePerMin.toStringAsFixed(0)}/min after ${freeWaitingSecs ~/ 60} min free)',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFFD84315),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.timer_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  '${freeWaitingSecs ~/ 60} min free waiting  •  $fmtFree left',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

// ── Delivery progress bar (courier bookings only) ─────────────────────────────

class _DeliveryProgressBar extends StatelessWidget {
  const _DeliveryProgressBar({required this.status});
  final BookingStatus status;

  int get _filled => switch (status) {
    BookingStatus.accepted   => 1,
    BookingStatus.arrived    => 2,
    BookingStatus.pickedUp   => 3,
    BookingStatus.inProgress => 4,
    _                        => 1,
  };

  @override
  Widget build(BuildContext context) {
    const total = 4;
    final filled = _filled;
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 6,
            decoration: BoxDecoration(
              color: (i + 1) <= filled
                  ? AppColors.primary
                  : const Color(0xFFEDD9A3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

// ── ETA box (large number + "mins" shown top-right for delivery) ──────────────

class _EtaBox extends StatelessWidget {
  const _EtaBox({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        minutes.toString(),
        style: AppTextStyles.h1.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      Text(
        'mins',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.white),
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      AppAssets.mapPin,
      width: 18,
      height: 18,
      colorFilter: const ColorFilter.mode(AppColors.black, BlendMode.srcIn),
    );
  }
}

class _DottedVLine extends StatelessWidget {
  const _DottedVLine({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: height,
      child: CustomPaint(
        painter: _DottedVLinePainter(),
      ),
    );
  }
}

class _DottedVLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.black.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dot = 2.0;
    const gap = 6.0;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + dot).clamp(0.0, size.height)), paint);
      y += dot + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Map view — owns route computation, driver animation, approach line ────────
//
// Fixes the blink:
//  • _loadFuture is cached in initState — FutureBuilder never gets a new
//    Future instance, so it never flashes back to ConnectionState.waiting.
//  • Driver animation runs inside this widget's own timer — the parent only
//    updates driverTarget once per poll (every 5 s), not every 40 ms.

class _RoutedMapView extends StatefulWidget {
  const _RoutedMapView({
    required this.booking,
    required this.apiKey,
    required this.driverTarget,
  });
  final BookingModel? booking;
  final String        apiKey;
  final LatLng?       driverTarget;  // raw GPS position from poll

  @override
  State<_RoutedMapView> createState() => _RoutedMapViewState();
}

class _RoutedMapViewState extends State<_RoutedMapView> {
  // ── Web: cached JS-loader future (never recreated) ──────────────────────────
  Future<bool>? _loadFuture;

  // ── Map controller ───────────────────────────────────────────────────────────
  GoogleMapController? _ctrl;
  int _camVersion = 0;

  // ── Route ────────────────────────────────────────────────────────────────────
  List<LatLng>  _routePts   = [];
  bool          _routeLoaded = false;
  String?       _polyUsed;
  LatLngBounds? _routeBounds;

  // ── Approach route (driver → pickup via real roads) ───────────────────────────
  List<LatLng> _approachRoute     = [];
  LatLng?      _lastApproachFetch;
  static const double _kRefetchM = 120; // re-fetch approach route every 120 m moved

  // ── Custom car icon for driver marker ────────────────────────────────────────
  BitmapDescriptor? _carIcon;
  static BitmapDescriptor? _cachedCarIcon; // process-level cache

  // ── Driver animation ─────────────────────────────────────────────────────────
  LatLng? _driverPos;
  double  _driverRot = 0;
  Timer?  _animTimer;

  static const _kDefaultCenter = LatLng(8.4966, 4.5421);

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _loadFuture = ensureGoogleMapsJsLoaded(apiKey: widget.apiKey);
    _buildRoute(widget.booking);
    if (widget.driverTarget != null) _driverPos = widget.driverTarget;
    _loadCarIcon();
    // Fetch the real-road approach route as soon as we have a driver position
    if (widget.driverTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchApproachRoute(widget.driverTarget!);
      });
    }
  }

  Future<void> _loadCarIcon() async {
    if (_cachedCarIcon != null) {
      setState(() => _carIcon = _cachedCarIcon);
      return;
    }
    try {
      final icon = await _buildCircleMarkerIcon(
        Icons.directions_car_rounded,
        bg: const Color(0xFFE2A322),
      );
      _cachedCarIcon = icon;
      if (mounted) setState(() => _carIcon = icon);
    } catch (e, st) {
      debugPrint('[CarIcon] failed to build car marker icon: $e\n$st');
    }
  }

  /// Builds a circular bitmap marker from a Material icon.
  /// Renders at physical-pixel resolution and passes imagePixelRatio so
  /// google_maps_flutter scales it to the correct logical size on screen.
  static Future<BitmapDescriptor> _buildCircleMarkerIcon(
    IconData icon, {
    Color bg = const Color(0xFFE2A322),
    double size = 40, // logical pixels
  }) async {
    final dpr      = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    final physSize = (size * dpr).roundToDouble();
    final r        = physSize / 2;

    final rec    = ui.PictureRecorder();
    final canvas = Canvas(rec);

    canvas.drawCircle(
      Offset(r, r), r,
      Paint()..color = bg,
    );
    canvas.drawCircle(
      Offset(r, r), r - dpr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * dpr,
    );

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: physSize * 0.52,
          fontFamily: icon.fontFamily,
          color: Colors.white,
          package: icon.fontPackage,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset((physSize - tp.width) / 2, (physSize - tp.height) / 2));

    final img  = await rec.endRecording().toImage(physSize.toInt(), physSize.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: dpr);
  }

  @override
  void didUpdateWidget(_RoutedMapView old) {
    super.didUpdateWidget(old);
    final b  = widget.booking;
    final ob = old.booking;
    if (b?.id != ob?.id || b?.routePolyline != ob?.routePolyline) {
      _buildRoute(b);
    }
    final t = widget.driverTarget;
    if (t != null && t != old.driverTarget) _animateDriverTo(t);
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _ctrl?.dispose();
    _ctrl = null;
    super.dispose();
  }

  // ── Route computation ────────────────────────────────────────────────────────

  void _buildRoute(BookingModel? b) {
    if (b == null || b.pickupLat == 0 || b.destinationLat == 0) return;
    final encoded = (b.routePolyline ?? '').trim();
    if (_routeLoaded && (encoded.isEmpty || encoded == _polyUsed)) return;

    final pickup = LatLng(b.pickupLat, b.pickupLng);
    final dest   = LatLng(b.destinationLat, b.destinationLng);
    final pts    = encoded.isNotEmpty
        ? MapsService.decodePolylineBest(encoded, origin: pickup, destination: dest)
        : [pickup, dest];

    if (encoded.isNotEmpty && !_routeValid(pts, pickup, dest)) return;
    final route = pts.length >= 2 ? pts : [pickup, dest];
    final allPts = <LatLng>[...route, if (_driverPos != null) _driverPos!];

    setState(() {
      _routePts   = route;
      _routeBounds = MapsService.boundsFromPoints(allPts);
      _routeLoaded = true;
      if (encoded.isNotEmpty) _polyUsed = encoded;
    });
    _fitCamera();
  }

  bool _routeValid(List<LatLng> pts, LatLng origin, LatLng dest) {
    if (pts.length < 2) return false;
    double hav(LatLng a, LatLng b) {
      const r = 6371.0;
      final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
      final dLng = (b.longitude - a.longitude) * math.pi / 180;
      final lat1 = a.latitude * math.pi / 180;
      final lat2 = b.latitude * math.pi / 180;
      final s1 = math.sin(dLat / 2), s2 = math.sin(dLng / 2);
      return r * 2 * math.asin(math.sqrt(s1 * s1 + math.cos(lat1) * math.cos(lat2) * s2 * s2));
    }
    final s1 = hav(origin, pts.first) + hav(dest, pts.last);
    final s2 = hav(origin, pts.last)  + hav(dest, pts.first);
    return s1 < 2.0 || s2 < 2.0;
  }

  void _fitCamera() {
    if (!mounted || _ctrl == null || _routeBounds == null) return;
    final bounds = _routeBounds!;
    final spanLat = (bounds.northeast.latitude  - bounds.southwest.latitude).abs();
    final spanLng = (bounds.northeast.longitude - bounds.southwest.longitude).abs();
    if (spanLat > 1.5 || spanLng > 1.5) return;
    final v = ++_camVersion;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _ctrl == null || v != _camVersion) return;
      try { _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80)); }
      catch (_) { _ctrl = null; }
    });
  }

  // ── Approach route (driver → pickup via Directions API) ─────────────────────

  Future<void> _fetchApproachRoute(LatLng driverPos) async {
    final b = widget.booking;
    if (b == null || b.pickupLat == 0) return;
    final isApproaching = b.status == BookingStatus.accepted ||
                          b.status == BookingStatus.arrived;
    debugPrint('[Approach] status=${b.status} isApproaching=$isApproaching driverPos=$driverPos');
    if (!isApproaching) return;

    // Skip if driver hasn't moved enough since last fetch
    final last = _lastApproachFetch;
    if (last != null && _haversineM(last, driverPos) < _kRefetchM) return;

    _lastApproachFetch = driverPos;
    final pickup = LatLng(b.pickupLat, b.pickupLng);
    debugPrint('[Approach] fetching route: $driverPos → $pickup');
    final pts = await MapsService.getDirectionsRoute(driverPos, pickup);
    debugPrint('[Approach] got ${pts.length} points (${pts.length == 2 ? "straight line fallback" : "real route"})');
    if (mounted) setState(() => _approachRoute = pts);
  }

  static double _haversineM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final s1 = math.sin(dLat / 2), s2 = math.sin(dLng / 2);
    return r * 2 * math.asin(math.sqrt(s1*s1 + math.cos(lat1)*math.cos(lat2)*s2*s2));
  }

  // ── Driver animation (runs inside this widget — doesn't rebuild the parent) ──

  void _animateDriverTo(LatLng target) {
    final from = _driverPos ?? target;
    if (from == target) return;

    _driverRot = _bearing(from, target);
    _animTimer?.cancel();
    _fetchApproachRoute(target);

    const steps = 20;
    var i = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) { t.cancel(); return; }
      i++;
      final f = (i / steps).clamp(0.0, 1.0);
      setState(() => _driverPos = LatLng(
        from.latitude  + (target.latitude  - from.latitude)  * f,
        from.longitude + (target.longitude - from.longitude) * f,
      ));
      if (i >= steps) {
        t.cancel();
        _followCamera(target);
      }
    });
  }

  /// Pan the camera to keep the driver and their next waypoint both in frame.
  void _followCamera(LatLng driverPos) {
    final b = widget.booking;
    if (b == null || _ctrl == null) return;

    final isApproaching = b.status == BookingStatus.accepted ||
                          b.status == BookingStatus.arrived;
    final wLat = isApproaching ? b.pickupLat      : b.destinationLat;
    final wLng = isApproaching ? b.pickupLng      : b.destinationLng;
    if (wLat == 0) return;

    final waypoint = LatLng(wLat, wLng);
    if (_haversineM(driverPos, waypoint) < 10) return;

    final sw = LatLng(
      math.min(driverPos.latitude, waypoint.latitude),
      math.min(driverPos.longitude, waypoint.longitude),
    );
    final ne = LatLng(
      math.max(driverPos.latitude, waypoint.latitude),
      math.max(driverPos.longitude, waypoint.longitude),
    );
    try {
      _ctrl!.animateCamera(
        CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 100),
      );
    } catch (_) { _ctrl = null; }
  }

  void _copyDriverLocation() {
    final dPos = _driverPos;
    if (dPos == null) return;
    final text = '${dPos.latitude.toStringAsFixed(6)}, ${dPos.longitude.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Driver location copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openInGoogleMaps() {
    final dPos   = _driverPos;
    final b      = widget.booking;
    final pickup = (b != null && b.pickupLat != 0)
        ? LatLng(b.pickupLat, b.pickupLng)
        : null;
    if (pickup == null) return;

    // If driver pos known, route from driver → pickup; otherwise just open pickup
    final uri = dPos != null
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&origin=${dPos.latitude},${dPos.longitude}'
            '&destination=${pickup.latitude},${pickup.longitude}'
            '&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1'
            '&query=${pickup.latitude},${pickup.longitude}',
          );
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude  * math.pi / 180;
    final lat2 = to.latitude    * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
              math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ── Markers & polylines ──────────────────────────────────────────────────────

  Set<Marker> get _markers {
    final b = widget.booking;
    if (b == null) return {};
    return {
      if (b.pickupLat != 0)
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(b.pickupLat, b.pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Pickup', snippet: b.pickupAddress),
        ),
      if (b.destinationLat != 0)
        Marker(
          markerId: const MarkerId('dest'),
          position: LatLng(b.destinationLat, b.destinationLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: b.destinationAddress),
        ),
      if (_driverPos != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          rotation: _driverRot,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: 'Driver location',
            snippet: '${_driverPos!.latitude.toStringAsFixed(5)}, '
                     '${_driverPos!.longitude.toStringAsFixed(5)}  •  tap snippet to copy',
            onTap: _copyDriverLocation,
          ),
        ),
    };
  }

  Set<Polyline> get _polylines {
    final b = widget.booking;
    final lines = <Polyline>{};

    // ── Trip route (pickup → destination) ────────────────────────────────────
    if (_routePts.length >= 2) {
      final accepted = b?.status == BookingStatus.accepted ||
                       b?.status == BookingStatus.arrived;
      lines.add(Polyline(
        polylineId: const PolylineId('route'),
        points:     _routePts,
        // Muted when driver is still approaching; primary during trip
        color:      accepted ? AppColors.primary.withValues(alpha: 0.35) : AppColors.primary,
        width:      5,
        jointType:  JointType.round,
        startCap:   Cap.roundCap,
        endCap:     Cap.roundCap,
      ));
    }

    // ── Approach line (driver current position → pickup) ─────────────────────
    // Shows the driver's path to the customer in amber.
    final dPos   = _driverPos;
    final pickup = (b != null && b.pickupLat != 0)
        ? LatLng(b.pickupLat, b.pickupLng)
        : null;
    final isApproaching = b?.status == BookingStatus.accepted ||
                          b?.status == BookingStatus.arrived;
    if (dPos != null && pickup != null && isApproaching) {
      // Use real road route if fetched, otherwise straight line fallback
      final approachPts = _approachRoute.isNotEmpty ? _approachRoute : [dPos, pickup];
      lines.add(Polyline(
        polylineId: const PolylineId('approach'),
        points:     approachPts,
        color:      const Color(0xFFE2A322),
        width:      4,
        patterns:   [PatternItem.dot, PatternItem.gap(8)],
        startCap:   Cap.roundCap,
        endCap:     Cap.roundCap,
      ));
    }

    return lines;
  }

  LatLng get _initialTarget {
    final b = widget.booking;
    if (b != null && b.pickupLat != 0) return LatLng(b.pickupLat, b.pickupLng);
    if (_driverPos != null) return _driverPos!;
    return _kDefaultCenter;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return _map();
    return FutureBuilder<bool>(
      future: _loadFuture,  // stable instance — never causes a blink
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data != true) {
          return Container(color: AppColors.surface,
              child: const Center(child: CircularProgressIndicator()));
        }
        return _map();
      },
    );
  }

  Widget _map() {
    final b = widget.booking;
    final hasDriver = _driverPos != null;
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _initialTarget, zoom: 14),
          markers:                 _markers,
          polylines:               _polylines,
          myLocationEnabled:       false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled:     false,
          mapToolbarEnabled:       false,
          onMapCreated: (c) {
            _ctrl = c;
            _camVersion++;
            _fitCamera();
          },
        ),

        // ── Map overlay action buttons ────────────────────────────────────
        Positioned(
          top: 12, right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Open route in Google Maps
              if (b != null && b.pickupLat != 0)
                _MapOverlayChip(
                  icon: Icons.map_outlined,
                  label: 'Maps',
                  onTap: _openInGoogleMaps,
                ),
              if (b != null && b.pickupLat != 0) const SizedBox(height: 8),
              // Copy driver coordinates
              if (hasDriver)
                _MapOverlayChip(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: _copyDriverLocation,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Compact chip-style overlay button shown on top of the map ─────────────────

class _MapOverlayChip extends StatelessWidget {
  const _MapOverlayChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.textPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CANCEL REASON SHEET  (customer-side)
// ─────────────────────────────────────────────────────────────────────────────

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet({
    required this.subtitle,
    required this.reasons,
  });
  final String       subtitle;
  final List<String> reasons;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;
  bool    _isOther = false;
  final   _otherCtrl = TextEditingController();

  @override
  void dispose() { _otherCtrl.dispose(); super.dispose(); }

  String? get _effectiveReason {
    if (_isOther) {
      final t = _otherCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Text('Cancel trip?', style: AppTextStyles.h4),
          const SizedBox(height: 4),
          Text(widget.subtitle,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Predefined reasons
          ...widget.reasons.map((r) => _CustomerReasonTile(
                label: r,
                selected: !_isOther && _selected == r,
                onTap: () => setState(() { _selected = r; _isOther = false; }),
              )),

          // "Other" option
          _CustomerReasonTile(
            label: 'Other (please specify)',
            selected: _isOther,
            onTap: () => setState(() { _isOther = true; _selected = null; }),
          ),

          // Text field for custom reason
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _isOther
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: TextField(
                      controller: _otherCtrl,
                      autofocus: true,
                      maxLines: 2,
                      maxLength: 200,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Describe the reason…',
                        hintStyle: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Confirm cancel — disabled until reason chosen
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _effectiveReason == null
                  ? null
                  : () => Navigator.pop(context, _effectiveReason),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.disabled,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              child: Text('CANCEL TRIP',
                  style: AppTextStyles.labelLarge
                      .copyWith(letterSpacing: 0.6, color: AppColors.white)),
            ),
          ),

          const SizedBox(height: 10),

          // Keep trip
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, null),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              child: Text('KEEP TRIP',
                  style: AppTextStyles.labelLarge
                      .copyWith(letterSpacing: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerReasonTile extends StatelessWidget {
  const _CustomerReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.error.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.error : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.error : AppColors.divider,
                    width: 2,
                  ),
                  color: selected ? AppColors.error : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.error : AppColors.textPrimary,
                    )),
              ),
            ],
          ),
        ),
      );
}
