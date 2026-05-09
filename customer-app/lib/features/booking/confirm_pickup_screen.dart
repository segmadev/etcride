import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/maps/maps_service.dart';
import '../../data/models/booking_draft.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import 'search_destination_screen.dart';
import 'select_ride_screen.dart';

class ConfirmPickupScreen extends ConsumerStatefulWidget {
  const ConfirmPickupScreen({super.key});
  @override
  ConsumerState<ConfirmPickupScreen> createState() => _ConfirmPickupScreenState();
}

class _ConfirmPickupScreenState extends ConsumerState<ConfirmPickupScreen> {
  GoogleMapController?    _mapCtrl;
  StreamSubscription<Position>? _gpsSub;
  LatLng? _pickupLatLng;
  String  _pickupAddress  = 'Locating...';
  double? _gpsAccuracy;   // metres — null until first fix
  bool    _resolving      = false;
  bool    _redetecting    = false;

  static const _defaultCenter = LatLng(8.4966, 4.5421);

  @override
  void initState() {
    super.initState();
    _initPickup();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }

  // ── Location helpers ────────────────────────────────────────────────────────

  Future<bool> _ensurePermission() async {
    if (kIsWeb) return true;
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied &&
        perm != LocationPermission.deniedForever;
  }

  Future<void> _initPickup() async {
    final draft = ref.read(bookingDraftProvider);
    if (draft.hasPickup) {
      _pickupLatLng  = LatLng(draft.pickupLat, draft.pickupLng);
      _pickupAddress = draft.pickupAddress;
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_pickupLatLng!, 16)));
      return;
    }
    await _detectLocation(initial: true);
  }

  /// Streams GPS fixes until accuracy ≤ 30 m or 20-second timeout,
  /// so the pin keeps improving rather than locking onto a weak first fix.
  Future<void> _detectLocation({bool initial = false}) async {
    final hasPermission = await _ensurePermission();
    if (!hasPermission) {
      if (mounted && !kIsWeb) context.push(AppRoutes.locationPermission);
      _pickupLatLng  = _defaultCenter;
      _pickupAddress = 'Ilorin, Kwara State';
      if (mounted) setState(() {});
      return;
    }

    if (mounted) setState(() { _redetecting = true; _gpsAccuracy = null; });

    // Cancel any previous stream
    await _gpsSub?.cancel();
    _gpsSub = null;

    // Phase 1 — last known for instant visual feedback
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _pickupLatLng = LatLng(last.latitude, last.longitude);
          _gpsAccuracy  = last.accuracy;
        });
        _mapCtrl?.animateCamera(
            CameraUpdate.newLatLngZoom(_pickupLatLng!, 16));
      }
    } catch (_) {}

    // Phase 2 — stream live fixes; stop when accuracy ≤ 30 m or after 20 s
    final done = Completer<void>();

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: (sink) => sink.close(),
    ).listen(
      (pos) {
        if (!mounted) return;
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _pickupLatLng = ll;
          _gpsAccuracy  = pos.accuracy;
        });
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 16));
        if (pos.accuracy <= 30) {
          // Good enough — stop streaming and resolve address
          _gpsSub?.cancel();
          _gpsSub = null;
          _reverseGeocode(ll).then((_) {
            if (mounted) setState(() => _redetecting = false);
          });
          if (!done.isCompleted) done.complete();
        }
      },
      onDone: () {
        // Stream closed (timeout or cancelled)
        if (!done.isCompleted) done.complete();
        if (mounted) {
          if (_pickupLatLng != null) {
            _reverseGeocode(_pickupLatLng!).then((_) {
              if (mounted) setState(() => _redetecting = false);
            });
          } else {
            setState(() {
              _redetecting  = false;
              _pickupLatLng = _defaultCenter;
              _pickupAddress = 'Ilorin, Kwara State';
            });
          }
        }
      },
      onError: (e) {
        if (!done.isCompleted) done.complete();
        if (mounted) {
          setState(() {
            _redetecting = false;
            _pickupLatLng ??= _defaultCenter;
          });
        }
      },
      cancelOnError: true,
    );

    await done.future;
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _resolving = true);
    try {
      final address = await MapsService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) setState(() => _pickupAddress = address ?? 'Selected location');
    } catch (_) {
      if (mounted) setState(() => _pickupAddress = 'Selected location');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _onMapTap(LatLng pos) async {
    // Cancel any ongoing GPS stream — user has manually chosen a position
    await _gpsSub?.cancel();
    _gpsSub = null;
    setState(() {
      _pickupLatLng = pos;
      _redetecting  = false;
    });
    await _reverseGeocode(pos);
  }

  void _changePickup() {
    // Open search screen; user can edit pickup field there
    showSearchDestinationDrawer(context, openSelectRideAfter: false).then((_) {
      // Re-read the draft after search — it may have updated the pickup
      final draft = ref.read(bookingDraftProvider);
      if (draft.hasPickup && mounted) {
        setState(() {
          _pickupLatLng  = LatLng(draft.pickupLat, draft.pickupLng);
          _pickupAddress = draft.pickupAddress;
        });
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_pickupLatLng!, 16));
      }
    });
  }

  void _confirm() {
    if (_pickupLatLng == null) return;
    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
      pickupAddress: _pickupAddress,
      pickupLat:     _pickupLatLng!.latitude,
      pickupLng:     _pickupLatLng!.longitude,
    ));
    final draft = ref.read(bookingDraftProvider);
    if (!draft.hasDestination) {
      showSearchDestinationDrawer(context);
    } else {
      showSelectRideDrawer(context);
    }
  }

  // ── Map markers ─────────────────────────────────────────────────────────────

  Set<Marker> get _markers {
    final draft = ref.read(bookingDraftProvider);
    final markers = <Marker>{};

    if (_pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup — drag to adjust'),
        onDragEnd: (p) async {
          setState(() => _pickupLatLng = p);
          await _reverseGeocode(p);
        },
      ));
    }
    if (draft.hasDestination) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(draft.destinationLat, draft.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: draft.destinationAddress),
      ));
    }
    return markers;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final draft  = ref.watch(bookingDraftProvider);
    final mapKey = ref.watch(mapApiKeyProvider);
    final busy   = _resolving || _redetecting;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
          kIsWeb
              ? FutureBuilder<bool>(
                  future: ensureGoogleMapsJsLoaded(apiKey: mapKey),
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done ||
                        snap.data != true) {
                      return _placeholder;
                    }
                    return _map(draft);
                  },
                )
              : _map(draft),

          // ── Back ────────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 20, color: AppColors.textPrimary),
                ),
              ),
            ),
          ),

          // ── Re-detect button (floating, right side) ──────────────────────
          Positioned(
            right: 16,
            bottom: 220,
            child: _RedetectButton(
              loading: _redetecting,
              onTap: () => _detectLocation(),
            ),
          ),

          // ── Bottom card ─────────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + change link
                  Row(
                    children: [
                      Expanded(
                          child: Text(AppStrings.confirmPickup,
                              style: AppTextStyles.h4)),
                      TextButton.icon(
                        onPressed: _changePickup,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.primary,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.edit_location_alt_rounded,
                            size: 16),
                        label: const Text('Change',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pickup address row
                  _AddressRow(
                    icon: Icons.location_on_rounded,
                    color: AppColors.pickupPin,
                    label: busy ? 'Detecting your location...' : _pickupAddress,
                    hint: busy
                        ? (_gpsAccuracy != null
                            ? 'Improving accuracy (±${_gpsAccuracy!.round()} m)…'
                            : null)
                        : (_gpsAccuracy != null && _gpsAccuracy! > 50
                            ? 'Weak GPS (±${_gpsAccuracy!.round()} m) — tap map or drag pin to adjust'
                            : 'Tap map or drag pin to adjust'),
                    loading: busy,
                  ),

                  // Destination row (if set)
                  if (draft.hasDestination) ...[
                    const SizedBox(height: 8),
                    _AddressRow(
                      icon: Icons.location_on_rounded,
                      color: AppColors.destinationPin,
                      label: draft.destinationAddress,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      // Re-detect (secondary)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _redetecting ? null : () => _detectLocation(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            foregroundColor: AppColors.textPrimary,
                          ),
                          icon: _redetecting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textSecondary),
                                )
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(
                            'Re-detect',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Confirm (primary)
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: AppStrings.confirmPickupBtn,
                          onPressed: _pickupLatLng != null && !busy
                              ? _confirm
                              : null,
                          enabled: _pickupLatLng != null && !busy,
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

  Widget get _placeholder => Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child:
            const Icon(Icons.map_outlined, color: AppColors.textHint, size: 48),
      );

  Widget _map(BookingDraft draft) => GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _pickupLatLng ?? _defaultCenter,
          zoom: 15,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: _markers,
        onTap: _onMapTap,
        onMapCreated: (c) {
          _mapCtrl = c;
          if (_pickupLatLng != null) {
            c.animateCamera(
                CameraUpdate.newLatLngZoom(_pickupLatLng!, 16));
          }
        },
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.color,
    required this.label,
    this.hint,
    this.loading = false,
  });
  final IconData icon;
  final Color    color;
  final String   label;
  final String?  hint;
  final bool     loading;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hint != null && !loading)
                  Text(
                    hint!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint),
                  ),
              ],
            ),
          ),
        ],
      );
}

class _RedetectButton extends StatelessWidget {
  const _RedetectButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)
            ],
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : const Icon(Icons.my_location_rounded,
                  size: 20, color: AppColors.primary),
        ),
      );
}
