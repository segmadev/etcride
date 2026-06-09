import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../core/maps/maps_service.dart';
import '../../core/maps/boundary_service.dart';
import '../../data/models/booking_draft.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_bottom_drawer.dart';
import '../../shared/widgets/loading_overlay.dart';
import 'select_ride_screen.dart';

enum _ActiveField { pickup, destination }
enum SearchDestinationResult { openSelectRide, pickupUpdated }

class SearchDestinationScreen extends ConsumerStatefulWidget {
  const SearchDestinationScreen({
    super.key,
    this.asSheet = false,
    this.focusPickupInitially = false,
    this.pickupOnly = false,
  });

  final bool asSheet;
  final bool focusPickupInitially;
  final bool pickupOnly;
  @override
  ConsumerState<SearchDestinationScreen> createState() => _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends ConsumerState<SearchDestinationScreen> {
  final _pickupCtrl  = TextEditingController();
  final _destCtrl    = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus   = FocusNode();

  late _ActiveField _active;
  bool _loading        = false;
  String? _error;

  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  Timer? _debounce;
  bool _requestInFlight = false;
  String? _queuedQuery;
  int _searchEpoch = 0;
  final Map<String, Future<double?>> _distanceCache = {};

  // Prevents autocomplete firing when text is set programmatically
  bool _programmatic = false;

  final _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();

    _active = widget.focusPickupInitially || widget.pickupOnly
        ? _ActiveField.pickup
        : _ActiveField.destination;

    final draft = ref.read(bookingDraftProvider);
    if (draft.hasPickup) _setPickupText(draft.pickupAddress);
    if (draft.hasDestination) _setDestText(draft.destinationAddress);

    _pickupCtrl.addListener(() => _onFieldChanged(_ActiveField.pickup));
    _destCtrl.addListener(()   => _onFieldChanged(_ActiveField.destination));

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) setState(() => _active = _ActiveField.pickup);
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus) setState(() => _active = _ActiveField.destination);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.focusPickupInitially || widget.pickupOnly) {
        _pickupFocus.requestFocus();
      } else {
        _destFocus.requestFocus();
      }
    });
  }

  // Set controller text without triggering autocomplete search
  void _setPickupText(String text) {
    _programmatic = true;
    _pickupCtrl.text = text;
    _programmatic = false;
  }

  void _setDestText(String text) {
    _programmatic = true;
    _destCtrl.text = text;
    _programmatic = false;
  }

  TextEditingController get _activeCtrl =>
      _active == _ActiveField.pickup ? _pickupCtrl : _destCtrl;

  void _onFieldChanged(_ActiveField field) {
    if (_programmatic || field != _active) return;
    _debounce?.cancel();
    final q = _activeCtrl.text.trim();
    final qLen = q.replaceAll(RegExp(r'\s+'), '').length;
    if (q.isEmpty || qLen < 3) {
      setState(() { _suggestions = const []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 900),
      () => _fetchSuggestions(q),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    final q = query.trim();
    final qLen = q.replaceAll(RegExp(r'\s+'), '').length;
    if (qLen < 3) return;

    if (_requestInFlight) {
      _queuedQuery = q;
      return;
    }

    _requestInFlight = true;
    final epoch = ++_searchEpoch;

    try {
      final results = await MapsService.autocomplete(q, sessionToken: _sessionToken);
      if (!mounted) return;
      if (epoch != _searchEpoch) return;
      setState(() { _suggestions = results; _searching = false; });
    } catch (_) {
      if (!mounted) return;
      if (epoch != _searchEpoch) return;
      setState(() { _suggestions = const []; _searching = false; });
    } finally {
      if (!mounted) return;
      if (epoch != _searchEpoch) {
        _requestInFlight = false;
        return;
      }
      _requestInFlight = false;
      final next = _queuedQuery;
      _queuedQuery = null;
      if (next == null) return;
      final nextLen = next.replaceAll(RegExp(r'\s+'), '').length;
      if (nextLen < 3) return;
      if (next == q) return;
      setState(() => _searching = true);
      await _fetchSuggestions(next);
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<double?> _distanceToSuggestionKm(PlaceSuggestion s) {
    final draft = ref.read(bookingDraftProvider);
    double? baseLat;
    double? baseLng;
    if (_active == _ActiveField.destination && draft.hasPickup) {
      baseLat = draft.pickupLat;
      baseLng = draft.pickupLng;
    } else if (_active == _ActiveField.pickup && draft.hasDestination) {
      baseLat = draft.destinationLat;
      baseLng = draft.destinationLng;
    }
    if (baseLat == null || baseLng == null) return Future.value(null);
    final key = '${baseLat.toStringAsFixed(5)},${baseLng.toStringAsFixed(5)}:${s.placeId}';
    return _distanceCache.putIfAbsent(key, () async {
      final loc = await MapsService.placeDetails(s.placeId, sessionToken: _sessionToken);
      if (loc == null) return null;
      return _haversineKm(baseLat!, baseLng!, loc.lat, loc.lng);
    });
  }

  // Returns (boundary, enforcement) from mapSettings, or ([], false) on error.
  ({List<dynamic> boundary, bool enforcement}) _getBoundary() {
    final settings = ref.read(mapSettingsProvider).valueOrNull;
    if (settings == null) return (boundary: const [], enforcement: false);
    final boundary    = (settings['boundary']   as List?)   ?? const [];
    final enforcement = (settings['enforcement'] as bool?)  ?? false;
    return (boundary: boundary, enforcement: enforcement);
  }

  bool _checkBoundary(double lat, double lng) {
    final (:boundary, :enforcement) = _getBoundary();
    return BoundaryService.isAllowed(
      lat: lat, lng: lng,
      boundary: boundary,
      enforcement: enforcement,
    );
  }

  Future<void> _selectSuggestion(PlaceSuggestion place) async {
    _debounce?.cancel();
    _queuedQuery = null;
    _searchEpoch++;
    setState(() { _loading = true; _searching = false; _error = null; _suggestions = const []; });
    try {
      final loc = await MapsService.placeDetails(place.placeId, sessionToken: _sessionToken);
      if (loc == null) throw Exception();

      if (!_checkBoundary(loc.lat, loc.lng)) {
        setState(() => _error = 'That location is outside our service area.');
        return;
      }

      if (_active == _ActiveField.pickup) {
        _setPickupText(place.fullText);
        ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
          pickupAddress: place.fullText,
          pickupLat:     loc.lat,
          pickupLng:     loc.lng,
        ));
        if (widget.pickupOnly) {
          if (!mounted) return;
          if (widget.asSheet) {
            Navigator.of(context).pop(SearchDestinationResult.pickupUpdated);
          } else {
            context.pop(true);
          }
          return;
        }
        if (mounted) {
          _destFocus.requestFocus();
          setState(() => _active = _ActiveField.destination);
        }
      } else {
        _setDestText(place.fullText);
        ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
          destinationAddress: place.fullText,
          destinationLat:     loc.lat,
          destinationLng:     loc.lng,
        ));
        if (!mounted) return;
        final draft = ref.read(bookingDraftProvider);
        if (draft.hasPickup) {
          if (widget.asSheet) {
            Navigator.of(context).pop(SearchDestinationResult.openSelectRide);
          } else {
            showSelectRideDrawer(context);
          }
        } else {
          _pickupFocus.requestFocus();
          setState(() => _active = _ActiveField.pickup);
        }
      }
    } catch (_) {
      setState(() => _error = 'Could not find that location. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position?> _getPosition() async {
    if (kIsWeb) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (_) { return null; }
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pos = await _getPosition();
      if (pos == null) {
        if (mounted) {
          if (kIsWeb) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enable location permission in your browser settings.'),
                backgroundColor: AppColors.error,
              ),
            );
          } else {
            await context.push(AppRoutes.locationPermission);
          }
        }
        final retry = await _getPosition();
        if (retry == null) return;

        if (!_checkBoundary(retry.latitude, retry.longitude)) {
          setState(() => _error = 'Your current location is outside our service area.');
          return;
        }

        final address = await MapsService.reverseGeocode(retry.latitude, retry.longitude);
        final label   = address ?? 'My Location';

        _setPickupText(label);
        ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
          pickupAddress: label,
          pickupLat:     retry.latitude,
          pickupLng:     retry.longitude,
        ));

        if (!mounted) return;
        final draft = ref.read(bookingDraftProvider);
        if (draft.hasDestination) {
          if (widget.asSheet) {
            Navigator.of(context).pop(SearchDestinationResult.openSelectRide);
          } else {
            showSelectRideDrawer(context);
          }
        } else {
          _destFocus.requestFocus();
          setState(() => _active = _ActiveField.destination);
        }
        return;
      }

      if (!_checkBoundary(pos.latitude, pos.longitude)) {
        setState(() => _error = 'Your current location is outside our service area.');
        return;
      }

      final address = await MapsService.reverseGeocode(pos.latitude, pos.longitude);
      final label   = address ?? 'My Location';

      // Use programmatic setter so the listener doesn't trigger autocomplete
      _setPickupText(label);
      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
        pickupAddress: label,
        pickupLat:     pos.latitude,
        pickupLng:     pos.longitude,
      ));

      if (!mounted) return;
      final draft = ref.read(bookingDraftProvider);
      if (draft.hasDestination) {
        if (widget.asSheet) {
          Navigator.of(context).pop(SearchDestinationResult.openSelectRide);
        } else {
          showSelectRideDrawer(context);
        }
      } else {
        _destFocus.requestFocus();
        setState(() => _active = _ActiveField.destination);
      }
    } catch (_) {
      setState(() => _error = 'Could not get your location.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queuedQuery = null;
    _searchEpoch++;
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay.wrap(
      loading: _loading,
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
                const SizedBox(height: 18),
                Text(AppStrings.whereAreYouGoing, style: AppTextStyles.h3),
                Expanded(child: _buildBody()),
              ],
            )
          : Scaffold(
              backgroundColor: AppColors.white,
              appBar: AppBar(
                backgroundColor: AppColors.white,
                elevation: 0,
                leading: const BackButton(color: AppColors.textPrimary),
                title: Text(AppStrings.whereAreYouGoing, style: AppTextStyles.h4),
              ),
              body: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    final draft = ref.watch(bookingDraftProvider);
    return Column(
      children: [
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _RouteInputs(
            pickupCtrl: _pickupCtrl,
            destCtrl: _destCtrl,
            pickupFocus: _pickupFocus,
            destFocus: _destFocus,
            activeField: _active,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: _buildList(draft),
        ),
      ],
    );
  }

  Widget _buildList(BookingDraft draft) {
    final query = _activeCtrl.text.trim();

    if (_suggestions.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final s        = _suggestions[i];
          final match = query.isEmpty ? null : query;
          return GestureDetector(
            onTap: () => _selectSuggestion(s),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 2),
                  SvgPicture.asset(
                    AppAssets.mapPin,
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: s.mainText,
                          highlight: match,
                        ),
                        if (s.secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.secondaryText,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FutureBuilder<double?>(
                    future: _distanceToSuggestionKm(s),
                    builder: (context, snap) {
                      final v = snap.data;
                      if (v == null) return const SizedBox(width: 44);
                      return Text(
                        '${v.toStringAsFixed(1)}km',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
        children: [
          GestureDetector(
            onTap: _useCurrentLocation,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 22, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.useCurrentLoc,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          if (draft.hasPickup) ...[
            _RecentRow(
              title: draft.pickupAddress,
              subtitle: '',
              onTap: () {
                _setPickupText(draft.pickupAddress);
                _pickupFocus.requestFocus();
                setState(() => _active = _ActiveField.pickup);
              },
            ),
            const Divider(height: 1),
          ],
          if (draft.hasDestination) ...[
            _RecentRow(
              title: draft.destinationAddress,
              subtitle: '',
              onTap: () {
                _setDestText(draft.destinationAddress);
                _destFocus.requestFocus();
                setState(() => _active = _ActiveField.destination);
              },
            ),
            const Divider(height: 1),
          ],
          const SizedBox(height: 8),
        ],
      );
    }

    if (!_searching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text('No results found.\nTry a different search.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _RouteInputs extends StatelessWidget {
  const _RouteInputs({
    required this.pickupCtrl,
    required this.destCtrl,
    required this.pickupFocus,
    required this.destFocus,
    required this.activeField,
  });

  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final FocusNode pickupFocus;
  final FocusNode destFocus;
  final _ActiveField activeField;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              _markerDot(width: 20, height: 20),
              const SizedBox(height: 6),
              const _AnimatedDashedVLine(),
              const SizedBox(height: 6),
              _markerDot(),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              _BoxField(
                controller: pickupCtrl,
                focusNode: pickupFocus,
                hint: 'Pickup location',
                trailing: const SizedBox(width: 10),
              ),
              const SizedBox(height: 10),
              _BoxField(
                controller: destCtrl,
                focusNode: destFocus,
                hint: 'where to?',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (destCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          destCtrl.clear();
                          destFocus.requestFocus();
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.divider,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Icon(Icons.map_outlined, size: 16, color: AppColors.textSecondary),
                        ),
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
}

class _BoxField extends StatelessWidget {
  const _BoxField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller:      controller,
              focusNode:       focusNode,
              style:           AppTextStyles.bodyMedium,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText:       hint,
                hintStyle:      AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textHint),
                filled:         true,
                fillColor:      Colors.transparent,
                isDense:        true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                border:         InputBorder.none,
                enabledBorder:  InputBorder.none,
                focusedBorder:  InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _AnimatedDashedVLine extends StatefulWidget {
  const _AnimatedDashedVLine();

  @override
  State<_AnimatedDashedVLine> createState() => _AnimatedDashedVLineState();
}

class _AnimatedDashedVLineState extends State<_AnimatedDashedVLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: 52,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _MovingDashesPainter(
              phase: _ctrl.value,
              color: AppColors.black,
              strokeWidth: 2,
              dash: 6,
              gap: 6,
              radius: 2,
            ),
          );
        },
      ),
    );
  }
}

class _MovingDashesPainter extends CustomPainter {
  const _MovingDashesPainter({
    required this.phase,
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
    required this.radius,
  });

  final double phase;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final step = dash + gap;
    final offset = ((1.0 - phase) * step) % step;
    var y = -offset;
    final x = size.width / 2;
    while (y < size.height) {
      final y2 = (y + dash).clamp(0.0, size.height);
      final y1 = y.clamp(0.0, size.height);
      if (y2 > y1) {
        canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
      }
      y += step;
    }
  }

  @override
  bool shouldRepaint(covariant _MovingDashesPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.highlight});

  final String text;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final h = highlight?.trim();
    if (h == null || h.isEmpty) {
      return Text(text, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700));
    }
    final lower = text.toLowerCase();
    final target = h.toLowerCase();
    final idx = lower.indexOf(target);
    if (idx < 0) {
      return Text(text, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700));
    }
    final pre = text.substring(0, idx);
    final mid = text.substring(idx, idx + h.length);
    final post = text.substring(idx + h.length);
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        children: [
          TextSpan(text: pre),
          TextSpan(text: mid, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
          TextSpan(text: post),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

Future<bool> showSearchDestinationDrawer(
  BuildContext context, {
  bool openSelectRideAfter = true,
  bool focusPickupInitially = false,
  bool pickupOnly = false,
}) async {
  final result = await showAppBottomDrawer<SearchDestinationResult>(
    context: context,
    child: SearchDestinationScreen(
      asSheet: true,
      focusPickupInitially: focusPickupInitially,
      pickupOnly: pickupOnly,
    ),
  );
  if (result != SearchDestinationResult.openSelectRide &&
      result != SearchDestinationResult.pickupUpdated) {
    return false;
  }
  if (!context.mounted) return false;
  if (result == SearchDestinationResult.openSelectRide && openSelectRideAfter) {
    await showSelectRideDrawer(context);
  }
  return true;
}
