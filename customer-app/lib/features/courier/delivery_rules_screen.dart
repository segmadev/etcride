import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/router.dart';
import '../../../core/maps/google_maps_js_loader.dart';
import '../../../core/maps/maps_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_overlay.dart';

class DeliveryRulesScreen extends ConsumerStatefulWidget {
  const DeliveryRulesScreen({super.key});

  @override
  ConsumerState<DeliveryRulesScreen> createState() => _DeliveryRulesScreenState();
}

class _DeliveryRulesScreenState extends ConsumerState<DeliveryRulesScreen> {
  // ── Rules state ─────────────────────────────────────────────────────────────
  List<String> _rules = const [];
  bool _loadingRules = true;
  bool _booking = false;
  String? _error;

  // ── Map state ───────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _fetchRules();
    _initMap();
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
          markerId:   const MarkerId('pickup'),
          position:   pickup,
          icon:       BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: d.pickupAddress),
        ),
        Marker(
          markerId:   const MarkerId('dest'),
          position:   dest,
          icon:       BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: d.destinationAddress),
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

  // ── Rules ────────────────────────────────────────────────────────────────────

  Future<void> _fetchRules() async {
    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(ApiEndpoints.deliveryRules);
      final raw  = data?['rules'];
      if (raw is List) {
        setState(() { _rules = raw.map((e) => e.toString()).toList(); _loadingRules = false; });
        return;
      }
    } catch (_) {}
    setState(() => _loadingRules = false);
  }

  // ── Booking ───────────────────────────────────────────────────────────────────

  Future<void> _gotIt() async {
    setState(() { _booking = true; _error = null; });
    final draft = ref.read(bookingDraftProvider);
    try {
      final booking = await ref.read(bookingRepositoryProvider).createBooking(
        vehicleTypeId:      draft.vehicleTypeId,
        bookingType:        'delivery',
        pickupAddress:      draft.pickupAddress,
        pickupLat:          draft.pickupLat,
        pickupLng:          draft.pickupLng,
        destinationAddress: draft.destinationAddress,
        destinationLat:     draft.destinationLat,
        destinationLng:     draft.destinationLng,
        distanceKm:         draft.distanceKm > 0 ? draft.distanceKm : null,
        senderPhone:        draft.senderPhone,
        recipientPhone:     draft.recipientPhone,
        packageDescription: draft.packageDescription,
      );
      if (!mounted) return;
      context.go(AppRoutes.requesting, extra: booking.id);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mapKey  = ref.watch(mapApiKeyProvider);
    final draft   = ref.read(bookingDraftProvider);
    final screenH = MediaQuery.sizeOf(context).height;
    final center  = draft.hasPickup
        ? LatLng((draft.pickupLat + draft.destinationLat) / 2,
                 (draft.pickupLng + draft.destinationLng) / 2)
        : const LatLng(8.4966, 4.5421);

    return LoadingOverlay.wrap(
      loading: _booking,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Map (direct Stack child — sizes the Stack to full screen) ──
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

            // ── Back button ────────────────────────────────────────────────
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

            // ── Bottom panel ───────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomPanel(screenH),
            ),
          ],
        ),
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
      constraints: BoxConstraints(maxHeight: screenH * 0.68),
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
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Delivery Rules', style: AppTextStyles.h4, textAlign: TextAlign.center),
          ),

          // Subtitle
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Make sure before sending a parcel',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),

          // Rules list
          Flexible(
            child: _loadingRules
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ))
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _rules.length,
                    itemBuilder: (_, i) => _RuleItem(rule: _rules[i]),
                  ),
          ),

          // Bottom links
          if (!_loadingRules) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Text('Weight Requirements',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.legalDocuments),
                    child: Text('Terms of Use',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],

          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ),

          // GOT IT button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20, 16, 20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: AppButton(
              label: 'GOT IT',
              onPressed: (_booking || _loadingRules) ? null : _gotIt,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rule item ─────────────────────────────────────────────────────────────────

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.rule});
  final String rule;

  static const _termsPattern = 'Terms of Use';

  @override
  Widget build(BuildContext context) {
    final hasTerms = rule.contains(_termsPattern);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: hasTerms ? _buildRichText(rule) : Text(rule, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    final idx = text.indexOf(_termsPattern);
    return Text.rich(
      TextSpan(
        style: AppTextStyles.bodyMedium,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: _termsPattern,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (idx + _termsPattern.length < text.length)
            TextSpan(text: text.substring(idx + _termsPattern.length)),
        ],
      ),
    );
  }
}
