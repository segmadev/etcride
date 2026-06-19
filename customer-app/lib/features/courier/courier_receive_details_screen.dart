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
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_button.dart';

class CourierReceiveDetailsScreen extends ConsumerStatefulWidget {
  const CourierReceiveDetailsScreen({super.key});

  @override
  ConsumerState<CourierReceiveDetailsScreen> createState() =>
      _CourierReceiveDetailsScreenState();
}

class _CourierReceiveDetailsScreenState
    extends ConsumerState<CourierReceiveDetailsScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _senderCtrl = TextEditingController();
  final _recvCtrl   = TextEditingController();
  final _descCtrl   = TextEditingController();

  // ── Map state ───────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    final user  = ref.read(currentUserProvider);
    final draft = ref.read(bookingDraftProvider);
    _senderCtrl.text = draft.senderPhone ?? user?.phone ?? '';
    if (draft.recipientPhone    != null) _recvCtrl.text  = draft.recipientPhone!;
    if (draft.packageDescription != null) _descCtrl.text = draft.packageDescription!;
    _initMap();
  }

  @override
  void dispose() {
    _senderCtrl.dispose();
    _recvCtrl.dispose();
    _descCtrl.dispose();
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

  // ── Confirm ──────────────────────────────────────────────────────────────────

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final senderPhone    = _senderCtrl.text.trim();
    final recipientPhone = _recvCtrl.text.trim();
    final packageDesc    = _descCtrl.text.trim();

    ref.read(bookingDraftProvider.notifier).state =
        ref.read(bookingDraftProvider).copyWith(
          senderPhone:        senderPhone,
          recipientPhone:     recipientPhone,
          packageDescription: packageDesc,
        );
    context.push(AppRoutes.deliveryRules);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mapKey  = ref.watch(mapApiKeyProvider);
    final draft   = ref.watch(bookingDraftProvider);
    final screenH = MediaQuery.sizeOf(context).height;
    final center  = draft.hasPickup
        ? LatLng((draft.pickupLat + draft.destinationLat) / 2,
                 (draft.pickupLng + draft.destinationLng) / 2)
        : const LatLng(8.4966, 4.5421);

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            child: _buildBottomPanel(draft, screenH),
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

  Widget _buildBottomPanel(dynamic draft, double screenH) {
    final fare = ref.watch(bookingDraftProvider).estimatedFare;
    final btnLabel = fare > 0
        ? 'CONFIRM DELIVERY  ·  ${AppFormatters.naira(fare)}'
        : 'CONFIRM DELIVERY';

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.70),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Form(
        key: _formKey,
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
              child: Center(child: Text('Receive Details', style: AppTextStyles.h4)),
            ),

            // Form fields (scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sender phone
                    Text("Sender's Phone Number",
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _PhoneField(controller: _senderCtrl, validator: Validators.phone),

                    const SizedBox(height: 20),

                    // Receiver phone
                    Text("Receiver's Phone Number",
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _PhoneField(controller: _recvCtrl, validator: Validators.phone),

                    const SizedBox(height: 20),

                    // Package description
                    Row(
                      children: [
                        Text('Package description',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _confirm(),
                      validator: Validators.required,
                      decoration: InputDecoration(
                        hintText: 'Describe the parcel',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Confirm button
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 12, 20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: AppButton(label: btnLabel, onPressed: _confirm),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phone field with country code prefix ─────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.validator});
  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      controller,
      keyboardType:    TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator:       validator,
      style:           AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: '812 345 6789',
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            // Nigerian flag
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 26, height: 18,
                child: Row(
                  children: [
                    Expanded(child: Container(color: const Color(0xFF008751))),
                    Expanded(child: Container(color: Colors.white)),
                    Expanded(child: Container(color: const Color(0xFF008751))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('+234', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: AppColors.divider),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
