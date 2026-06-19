import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/router.dart';
import '../../../core/maps/google_maps_js_loader.dart';
import '../../../core/maps/maps_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle_type_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';

class CourierSelectVehicleScreen extends ConsumerStatefulWidget {
  const CourierSelectVehicleScreen({super.key});

  @override
  ConsumerState<CourierSelectVehicleScreen> createState() =>
      _CourierSelectVehicleScreenState();
}

class _CourierSelectVehicleScreenState
    extends ConsumerState<CourierSelectVehicleScreen> {
  // ── Vehicle / fare state ────────────────────────────────────────────────────
  List<VehicleTypeModel> _types = [];
  Map<String, Map<String, dynamic>> _fareCache = {};
  String? _selectedId;
  bool _loading = true;
  String? _error;
  String _paymentMethod = 'cash';

  // ── Map state ───────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

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
    _initMap();
    _loadVehicles();
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Map ─────────────────────────────────────────────────────────────────────

  void _initMap() {
    final d = ref.read(bookingDraftProvider);
    if (!d.hasPickup || !d.hasDestination) return;
    final pickup = LatLng(d.pickupLat, d.pickupLng);
    final dest   = LatLng(d.destinationLat, d.destinationLng);
    setState(() {
      _markers = {
        Marker(
          markerId:    const MarkerId('pickup'),
          position:    pickup,
          icon:        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow:  InfoWindow(title: d.pickupAddress),
        ),
        Marker(
          markerId:    const MarkerId('dest'),
          position:    dest,
          icon:        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow:  InfoWindow(title: d.destinationAddress),
        ),
      };
    });
    MapsService.getDirectionsRoute(pickup, dest).then((pts) {
      if (!mounted) return;
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points:     pts,
            color:      AppColors.primary,
            width:      4,
          ),
        };
      });
    }).catchError((_) {});
  }

  void _fitBounds() {
    if (!mounted || _mapCtrl == null) return;
    final d = ref.read(bookingDraftProvider);
    if (!d.hasPickup || !d.hasDestination) return;
    final sw = LatLng(math.min(d.pickupLat, d.destinationLat), math.min(d.pickupLng, d.destinationLng));
    final ne = LatLng(math.max(d.pickupLat, d.destinationLat), math.max(d.pickupLng, d.destinationLng));
    try {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80));
    } catch (_) {}
  }

  // ── Vehicle loading ──────────────────────────────────────────────────────────

  Future<void> _loadVehicles() async {
    final draft = ref.read(bookingDraftProvider);
    setState(() { _loading = true; _error = null; });
    try {
      final repo  = ref.read(bookingRepositoryProvider);
      final raw   = await repo.getVehicleTypes(bookingType: 'delivery');
      final types = raw.map((j) => VehicleTypeModel.fromJson(j as Map<String, dynamic>)).toList();
      if (types.isEmpty) throw Exception('No delivery vehicle types configured');

      final fares = await Future.wait(
        types.map((vt) => repo.estimateFare(
          vehicleTypeId:  vt.id,
          pickupLat:      draft.pickupLat,
          pickupLng:      draft.pickupLng,
          destinationLat: draft.destinationLat,
          destinationLng: draft.destinationLng,
        ).then((f) => MapEntry(vt.id, f)).catchError((_) => MapEntry(vt.id, <String, dynamic>{}))),
      );

      if (!mounted) return;
      setState(() {
        _types     = types;
        _fareCache = Map.fromEntries(fares);
        _selectedId = types.first.id;
        _loading   = false;
      });
      _seedDraft(types.first.id);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _seedDraft(String vtId) {
    final fare = _fareCache[vtId];
    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
      vehicleTypeId:   vtId,
      vehicleTypeName: _types.firstWhere((v) => v.id == vtId).name,
      estimatedFare:   _toDouble(fare?['estimated_fare']),
      distanceKm:      _toDouble(fare?['distance_km']),
    ));
  }

  void _select(VehicleTypeModel vt) {
    setState(() => _selectedId = vt.id);
    _seedDraft(vt.id);
  }

  void _confirm() {
    if (_selectedId == null) return;
    ref.read(selectedPaymentMethodProvider.notifier).state = _paymentMethod;
    context.push(AppRoutes.courierReceiveDetails);
  }

  Future<void> _editPaymentMethod() async {
    final selected = await context.push<String>(
      AppRoutes.paymentMethods,
      extra: _paymentMethod,
    );
    if (!mounted || selected == null) return;
    setState(() => _paymentMethod = selected);
    ref.read(selectedPaymentMethodProvider.notifier).state = selected;
  }

  String get _paymentLabel => _paymentMethod == 'flutterwave'
      ? AppStrings.payWithFlutterwave
      : AppStrings.cash;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mapKey  = ref.watch(mapApiKeyProvider);
    final screenH = MediaQuery.sizeOf(context).height;
    final draft   = ref.read(bookingDraftProvider);
    final center  = draft.hasPickup
        ? LatLng((draft.pickupLat + draft.destinationLat) / 2,
                 (draft.pickupLng + draft.destinationLng) / 2)
        : const LatLng(8.4966, 4.5421);

    return Scaffold(
      body: Stack(
        children: [
          // ── Map (direct Stack child — sizes the Stack to full screen) ──────
          kIsWeb
              ? FutureBuilder<bool>(
                  future: ensureGoogleMapsJsLoaded(apiKey: mapKey),
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done || snap.data != true) {
                      return const SizedBox.expand(child: ColoredBox(color: Color(0xFFF7F7F7)));
                    }
                    return _buildMap(center);
                  },
                )
              : _buildMap(center),

          // ── Back button ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                ),
              ),
            ),
          ),

          // ── Bottom panel ─────────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomPanel(screenH),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng center) => GoogleMap(
    initialCameraPosition: CameraPosition(target: center, zoom: 13),
    markers:               _markers,
    polylines:             _polylines,
    myLocationEnabled:     false,
    myLocationButtonEnabled: false,
    zoomControlsEnabled:   false,
    mapToolbarEnabled:     false,
    onMapCreated: (ctrl) {
      if (!mounted) return;
      _mapCtrl = ctrl;
      _fitBounds();
    },
  );

  Widget _buildBottomPanel(double screenH) {
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.66),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(AppStrings.chooseYourRide, style: AppTextStyles.h4, textAlign: TextAlign.center),
          ),

          // Vehicle list
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Text(
                    _error!.contains('configured')
                        ? 'No delivery vehicle types have been set up yet.'
                        : 'Could not load vehicle types.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _loadVehicles, child: const Text('Retry')),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _types.length,
                itemBuilder: (_, i) {
                  final vt       = _types[i];
                  final fare     = _fareCache[vt.id];
                  final selected = _selectedId == vt.id;
                  final estimated = _toDouble(fare?['estimated_fare']);
                  final eta       = fare?['eta_minutes'];
                  return _VehicleCard(
                    type:       vt,
                    estimated:  estimated,
                    etaMinutes: eta is num ? eta.toInt() : null,
                    selected:   selected,
                    onTap:      () => _select(vt),
                  );
                },
              ),
            ),

          // Payment method
          if (!_loading && _error == null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _PaymentTile(label: _paymentLabel, onTap: _editPaymentMethod),
            ),
          ],

          // Confirm button
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 12, 16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: AppButton(
              label: AppStrings.confirmRideBtn,
              onPressed: _selectedId != null && !_loading ? _confirm : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vehicle card ──────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.type,
    required this.estimated,
    required this.selected,
    required this.onTap,
    this.etaMinutes,
  });
  final VehicleTypeModel type;
  final double estimated;
  final bool selected;
  final VoidCallback onTap;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryLight : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64, height: 64,
            child: _VehicleIcon(type: type),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                if (etaMinutes != null)
                  Text(
                    '${_timeNow()} · $etaMinutes min',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (estimated > 0)
            Text(AppFormatters.naira(estimated),
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );

  String _timeNow() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _VehicleIcon extends StatelessWidget {
  const _VehicleIcon({required this.type});
  final VehicleTypeModel type;

  static final Map<String, Future<Uint8List>> _cache = {};

  @override
  Widget build(BuildContext context) {
    final icon = type.icon ?? '';
    if (icon.startsWith('http') || icon.isEmpty) return _placeholder();
    final future = _cache.putIfAbsent(icon, () async {
      try {
        final svg   = await rootBundle.loadString(icon);
        final match = RegExp(r'data:image\/png;base64,([^"]+)').firstMatch(svg);
        if (match == null) throw const FormatException('no PNG');
        return base64Decode(match.group(1)!);
      } catch (_) {
        return Uint8List(0);
      }
    });
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (_, snap) {
        if (snap.data == null || snap.data!.isEmpty) return _placeholder();
        return Image.memory(snap.data!, fit: BoxFit.contain);
      },
    );
  }

  Widget _placeholder() => const Icon(Icons.delivery_dining_rounded, size: 36, color: AppColors.textSecondary);
}

// ── Payment tile (dashed border) ──────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: CustomPaint(
      painter: _DashedBorderPainter(color: AppColors.textSecondary.withValues(alpha: 0.5)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const radius  = Radius.circular(12);
    final rrect   = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final path    = Path()..addRRect(rrect);
    const dash = 7.0;
    const gap  = 5.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dash).clamp(0, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}
