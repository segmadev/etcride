import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/router.dart';
import '../../../core/maps/maps_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_route_row.dart';
import '../booking/search_destination_screen.dart';

class TripDetailsScreen extends ConsumerStatefulWidget {
  const TripDetailsScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  BookingModel? _booking;
  bool _loading = true;
  GoogleMapController? _mapCtrl;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(bookingRepositoryProvider).getBooking(widget.bookingId);
      if (mounted) {
        final polyline = b.routePolyline;
        final pts = (polyline != null && polyline.isNotEmpty)
            ? MapsService.decodePolyline(polyline)
            : <LatLng>[LatLng(b.pickupLat, b.pickupLng), LatLng(b.destinationLat, b.destinationLng)];
        setState(() { _booking = b; _routePoints = pts; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fitBounds() {
    final b = _booking;
    final ctrl = _mapCtrl;
    if (b == null || ctrl == null) return;
    final pts = [
      LatLng(b.pickupLat, b.pickupLng),
      LatLng(b.destinationLat, b.destinationLng),
      ..._routePoints,
    ];
    final bounds = MapsService.boundsFromPoints(pts);
    if (bounds != null) ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  }

  String _statusLabel(BookingStatus s) => switch (s) {
    BookingStatus.completed || BookingStatus.paid => 'Successful',
    BookingStatus.cancelled || BookingStatus.rejected => 'Cancelled',
    BookingStatus.inProgress => 'In Progress',
    BookingStatus.pending => 'Pending',
    BookingStatus.assigned => 'Assigned',
    BookingStatus.accepted => 'Accepted',
    _ => 'Processing',
  };

  Color _statusColor(BookingStatus s) => switch (s) {
    BookingStatus.completed || BookingStatus.paid => AppColors.success,
    BookingStatus.cancelled || BookingStatus.rejected => AppColors.error,
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : b == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      const Text('Trip not found'),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Go home')),
                    ],
                  ),
                )
              : _buildContent(b),
    );
  }

  Widget _buildContent(BookingModel b) {
    final fare = b.finalFare != 0 ? b.finalFare : b.estimatedFare;
    final createdDate = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
    final dateStr = createdDate != null ? DateFormat("MMM d, y.").format(createdDate) : '—';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Custom header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CircleBackButton(onTap: () {
                    if (context.canPop()) { context.pop(); }
                    else { context.go(AppRoutes.tripHistory); }
                  }),
                ),
                Text(dateStr, style: AppTextStyles.h4),
              ],
            ),
          ),

          // ── Map ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 190,
                child: AbsorbPointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(b.pickupLat, b.pickupLng),
                      zoom: 12,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: LatLng(b.pickupLat, b.pickupLng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ),
                      Marker(
                        markerId: const MarkerId('dest'),
                        position: LatLng(b.destinationLat, b.destinationLng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                      ),
                    },
                    polylines: _routePoints.isNotEmpty
                        ? {
                            Polyline(
                              polylineId: const PolylineId('route'),
                              points: _routePoints,
                              color: AppColors.primary,
                              width: 4,
                            ),
                          }
                        : {},
                    liteModeEnabled: true,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (ctrl) {
                      _mapCtrl = ctrl;
                      Future.delayed(const Duration(milliseconds: 400), _fitBounds);
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable content ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route + Rebook
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: LocationRouteRow(
                          pickup: b.pickupAddress,
                          destination: b.destinationAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RebookButton(
                        onTap: () => showSearchDestinationDrawer(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fare ~ Status
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: AppFormatters.naira(fare),
                          style: AppTextStyles.h3,
                        ),
                        TextSpan(
                          text: ' ~ ',
                          style: AppTextStyles.h3.copyWith(color: AppColors.textHint),
                        ),
                        TextSpan(
                          text: _statusLabel(b.status),
                          style: AppTextStyles.h3.copyWith(color: _statusColor(b.status)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, thickness: 1, color: AppColors.divider),
                  const SizedBox(height: 20),

                  // Duration + Distance
                  Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          icon: Icons.access_time_rounded,
                          label: 'Duration',
                          value: b.durationMinutes > 0
                              ? AppFormatters.duration(b.durationMinutes)
                              : '0 min',
                        ),
                      ),
                      Expanded(
                        child: _StatCell(
                          icon: Icons.near_me_outlined,
                          label: 'Distance',
                          value: b.distanceKm > 0
                              ? AppFormatters.distance(b.distanceKm)
                              : '0 km',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, thickness: 1, color: AppColors.divider),
                  const SizedBox(height: 20),

                  // Driver + Vehicle
                  if (b.driverName != null && b.driverName!.isNotEmpty) ...[
                    _DriverVehicleCard(booking: b),
                    const SizedBox(height: 20),
                    const Divider(height: 1, thickness: 1, color: AppColors.divider),
                    const SizedBox(height: 20),
                  ],

                  // View Receipt
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push(AppRoutes.tripReceipt, extra: widget.bookingId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 22, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Text('View Receipt', style: AppTextStyles.bodyMedium),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textHint),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Bottom buttons
                  Row(
                    children: [
                      Expanded(
                        child: _GrayPillButton(
                          label: 'REMOVE TRIP',
                          onTap: () => _confirmRemove(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BlackPillButton(
                          label: 'REPORT ISSUE',
                          onTap: () => _reportIssue(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Trip'),
        content: const Text('This will remove the trip from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (context.canPop()) context.pop();
            },
            child: Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _reportIssue(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report Issue'),
        content: const Text('Our support team will review your report and respond shortly.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _RebookButton extends StatelessWidget {
  const _RebookButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.replay_rounded, size: 15, color: AppColors.white),
              const SizedBox(width: 6),
              Text(
                'Rebook',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      );
}

class _DriverVehicleCard extends StatelessWidget {
  const _DriverVehicleCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final vehicleAsset = b.bookingType == BookingType.delivery
        ? AppAssets.courierIcon
        : AppAssets.carIcon;
    final rating = b.driverRating.clamp(0.0, 5.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Driver avatar
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: b.driverAvatar != null && b.driverAvatar!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(b.driverAvatar!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.person_rounded, size: 28, color: AppColors.textHint),
            ),
            const SizedBox(width: 12),
            // Vehicle image
            SvgPicture.asset(vehicleAsset, width: 72, height: 52),
            const Spacer(),
            // Vehicle info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (b.vehicleTypeName != null)
                  Text(
                    b.vehicleTypeName!,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                if (b.vehiclePlate != null)
                  Text(
                    b.vehiclePlate!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                if (b.vehicleColor != null)
                  Text(
                    b.vehicleColor!.toUpperCase(),
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          b.driverName ?? '',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        _StarRating(rating: rating),
      ],
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i < rating.floor();
          final half = !filled && (i < rating);
          return Icon(
            half ? Icons.star_half_rounded : Icons.star_rounded,
            size: 18,
            color: (filled || half) ? AppColors.starFilled : AppColors.starEmpty,
          );
        }),
      );
}

class _GrayPillButton extends StatelessWidget {
  const _GrayPillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.disabled,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}

class _BlackPillButton extends StatelessWidget {
  const _BlackPillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}
