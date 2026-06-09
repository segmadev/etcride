import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../core/maps/boundary_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking_draft.dart';
import '../../data/models/vehicle_type_model.dart';
import '../auth/complete_profile_screen.dart';
import 'search_destination_screen.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_bottom_drawer.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/loading_overlay.dart';

class SelectRideScreen extends ConsumerStatefulWidget {
  const SelectRideScreen({super.key, this.asSheet = false});

  final bool asSheet;
  @override
  ConsumerState<SelectRideScreen> createState() => _SelectRideScreenState();
}

class _SelectRideScreenState extends ConsumerState<SelectRideScreen> {
  List<VehicleTypeModel> _vehicleTypes = [];
  Map<String, Map<String, dynamic>> _fareCache = {};
  String? _selectedId;
  bool _loading = true;
  bool _confirming = false;
  String? _error;
  String? _confirmError;
  String _paymentMethod = 'cash';

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _paymentMethod = ref.read(selectedPaymentMethodProvider);
    _loadVehicleTypes();
  }

  Future<void> _loadVehicleTypes() async {
    final draft = ref.read(bookingDraftProvider);
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(bookingRepositoryProvider);

      // Fetch vehicle types
      final raw = await repo.getVehicleTypes(bookingType: draft.bookingType);
      final types = raw
          .map((j) => VehicleTypeModel.fromJson(j as Map<String, dynamic>))
          .toList();

      if (types.isEmpty) throw Exception('No vehicle types available');

      // Fetch fares in parallel
      final fares = await Future.wait(
        types.map((vt) => repo.estimateFare(
          vehicleTypeId: vt.id,
          pickupLat:     draft.pickupLat,
          pickupLng:     draft.pickupLng,
          destinationLat: draft.destinationLat,
          destinationLng: draft.destinationLng,
        ).then((f) => MapEntry(vt.id, f)).catchError((_) => MapEntry(vt.id, <String, dynamic>{})))
      );

      setState(() {
        _vehicleTypes = types;
        _fareCache = Map.fromEntries(fares);
        _selectedId = types.first.id;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _fareFor(String vtId) {
    final f = _fareCache[vtId];
    if (f == null) return 0;
    return _toDouble(f['estimated_fare']);
  }

  double _distanceKm() {
    final f = _fareCache[_selectedId ?? ''];
    return _toDouble(f?['distance_km']);
  }

  Future<void> _confirm() async {
    var user = ref.read(currentUserProvider);
    if (user == null) {
      try {
        await ref.read(authInitProvider.future);
      } catch (_) {}
      user = ref.read(currentUserProvider);
    }
    final isComplete = user != null &&
        user.name.isNotEmpty &&
        (user.phone.isNotEmpty || user.email.isNotEmpty);

    if (!isComplete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileIncomplete),
          backgroundColor: AppColors.error,
        ),
      );
      showCompleteProfileDrawer(context);
      return;
    }

    if (_selectedId == null) return;
    final vt = _vehicleTypes.firstWhere((v) => v.id == _selectedId);
    final draft = ref.read(bookingDraftProvider);

    // Boundary enforcement — re-check at confirm time in case settings changed
    final mapSettings  = ref.read(mapSettingsProvider).valueOrNull;
    final boundary     = (mapSettings?['boundary']    as List?)  ?? const [];
    final enforcement  = (mapSettings?['enforcement'] as bool?)  ?? false;
    bool inBoundary(double lat, double lng) =>
        BoundaryService.isAllowed(lat: lat, lng: lng, boundary: boundary, enforcement: enforcement);

    if (!inBoundary(draft.pickupLat, draft.pickupLng)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup location is outside our service area.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (!inBoundary(draft.destinationLat, draft.destinationLng)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destination is outside our service area.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Update draft with vehicle selection
    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
      vehicleTypeId:  _selectedId,
      vehicleTypeName: vt.name,
      estimatedFare:  _fareFor(_selectedId!),
      distanceKm:     _distanceKm(),
    ));
    ref.read(selectedPaymentMethodProvider.notifier).state = _paymentMethod;

    setState(() { _confirming = true; _confirmError = null; });
    try {
      final booking = await ref.read(bookingRepositoryProvider).createBooking(
        vehicleTypeId:       _selectedId!,
        bookingType:         draft.bookingType,
        pickupAddress:       draft.pickupAddress,
        pickupLat:           draft.pickupLat,
        pickupLng:           draft.pickupLng,
        destinationAddress:  draft.destinationAddress,
        destinationLat:      draft.destinationLat,
        destinationLng:      draft.destinationLng,
        distanceKm:          _distanceKm(),
        recipientName:       draft.recipientName,
        recipientPhone:      draft.recipientPhone,
        packageDescription:  draft.packageDescription,
      );

      try {
        await ref.read(bookingRepositoryProvider).updatePaymentMethod(
              booking.id,
              _paymentMethod,
            );
      } catch (_) {}

      if (!mounted) return;
      if (widget.asSheet) {
        Navigator.of(context).pop(booking.id);
      } else {
        context.go(AppRoutes.requesting, extra: booking.id);
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() => _confirmError = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _editRoute() async {
    final updated = await showSearchDestinationDrawer(
      context,
      openSelectRideAfter: false,
    );
    if (!mounted) return;
    if (updated) {
      _loadVehicleTypes();
    }
  }

  Future<void> _editPaymentMethod() async {
    final selected = await context.push<String>(
      AppRoutes.paymentMethods,
      extra: _paymentMethod,
    );
    if (!mounted) return;
    if (selected == null) return;
    setState(() => _paymentMethod = selected);
    ref.read(selectedPaymentMethodProvider.notifier).state = selected;
  }

  String get _paymentLabel => switch (_paymentMethod) {
    'bank_transfer' => AppStrings.bankTransfer,
    'flutterwave' => AppStrings.payWithFlutterwave,
    _ => AppStrings.cash,
  };

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);

    return LoadingOverlay.wrap(
      loading: _confirming,
      child: widget.asSheet
          ? Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(AppStrings.chooseYourRide, style: AppTextStyles.h4),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _buildBody(draft)),
              ],
            )
          : Scaffold(
              backgroundColor: AppColors.white,
              appBar: AppBar(
                backgroundColor: AppColors.white,
                elevation: 0,
                leading: const BackButton(color: AppColors.textPrimary),
                title: Text(AppStrings.chooseYourRide, style: AppTextStyles.h4),
              ),
              body: _buildBody(draft),
            ),
    );
  }

  Widget _buildBody(BookingDraft draft) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return _buildError();
    }
    return Column(
      children: [
        _RouteBar(draft: draft, onEdit: _editRoute),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _vehicleTypes.length,
            itemBuilder: (_, i) {
              final vt = _vehicleTypes[i];
              final selected = vt.id == _selectedId;
              final fare = _fareFor(vt.id);
              return _VehicleCard(
                vt: vt,
                fare: fare,
                selected: selected,
                onTap: () => setState(() => _selectedId = vt.id),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _PaymentOptionTile(
            label: _paymentLabel,
            onTap: _editPaymentMethod,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_confirmError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _confirmError!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: AppStrings.confirmRideBtn,
                onPressed: _selectedId != null ? _confirm : null,
                enabled: _selectedId != null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', onPressed: _loadVehicleTypes),
            ],
          ),
        ),
      );
}

class _RouteBar extends StatelessWidget {
  const _RouteBar({required this.draft, required this.onEdit});
  final BookingDraft draft;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Column(
              children: [
                _markerDot(width: 18, height: 18),
                const SizedBox(height: 6),
                const _AnimatedDashedVLine(height: 26),
                const SizedBox(height: 6),
                _markerDot(width: 14, height: 14),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.pickupAddress,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Text(draft.destinationAddress,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                foregroundColor: AppColors.primary,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Edit'),
                ],
              ),
            ),
          ],
        ),
      );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vt,
    required this.fare,
    required this.selected,
    required this.onTap,
  });
  final VehicleTypeModel vt;
  final double fare;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.white,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: _EmbeddedPngFromSvgAsset(
                  assetPath: vt.category == 'delivery'
                      ? AppAssets.courierIcon
                      : AppAssets.carIcon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vt.name, style: AppTextStyles.bodyLarge),
                    if (vt.description != null && vt.description!.isNotEmpty)
                      Text(vt.description!,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(AppFormatters.naira(fare),
                      style: AppTextStyles.h4),
                  Text('Estimated',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      );
}

Widget _markerDot({double width = 14, double height = 14}) => Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.black,
        shape: BoxShape.circle,
      ),
    );

class _AnimatedDashedVLine extends StatefulWidget {
  const _AnimatedDashedVLine({this.height = 24});
  final double height;

  @override
  State<_AnimatedDashedVLine> createState() => _AnimatedDashedVLineState();
}

class _AnimatedDashedVLineState extends State<_AnimatedDashedVLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _MovingDashesPainter(phase: _controller.value),
        ),
      ),
    );
  }
}

class _MovingDashesPainter extends CustomPainter {
  _MovingDashesPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.black.withValues(alpha: 0.65)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dash = 6.0;
    const gap = 5.0;
    final step = dash + gap;

    final x = size.width / 2;
    final offset = ((1.0 - phase) * step) % step;
    var y = -offset;
    while (y < size.height) {
      final y1 = y.clamp(0.0, size.height);
      final y2 = (y + dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
      y += step;
    }
  }

  @override
  bool shouldRepaint(covariant _MovingDashesPainter oldDelegate) =>
      oldDelegate.phase != phase;
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

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedRoundedRectPainter(
          color: AppColors.textSecondary.withValues(alpha: 0.95),
          strokeWidth: 2,
          radius: 12,
          dash: 7,
          gap: 5,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppTextStyles.bodyMedium),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}

Future<void> showSelectRideDrawer(BuildContext context) async {
  final bookingId = await showAppBottomDrawer<String>(
    context: context,
    child: const SelectRideScreen(asSheet: true),
  );
  if (bookingId == null) return;
  if (!context.mounted) return;
  context.go(AppRoutes.requesting, extra: bookingId);
}
