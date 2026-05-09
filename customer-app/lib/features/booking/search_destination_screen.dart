import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../core/maps/maps_service.dart';
import '../../core/maps/boundary_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_bottom_drawer.dart';
import '../../shared/widgets/loading_overlay.dart';
import 'select_ride_screen.dart';

enum _ActiveField { pickup, destination }
enum SearchDestinationResult { openSelectRide }

class SearchDestinationScreen extends ConsumerStatefulWidget {
  const SearchDestinationScreen({super.key, this.asSheet = false});

  final bool asSheet;
  @override
  ConsumerState<SearchDestinationScreen> createState() => _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends ConsumerState<SearchDestinationScreen> {
  final _pickupCtrl  = TextEditingController();
  final _destCtrl    = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus   = FocusNode();

  _ActiveField _active = _ActiveField.destination;
  bool _loading        = false;
  String? _error;

  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  Timer? _debounce;

  // Prevents autocomplete firing when text is set programmatically
  bool _programmatic = false;

  final _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();

    final draft = ref.read(bookingDraftProvider);
    if (draft.hasPickup) _setPickupText(draft.pickupAddress);

    _pickupCtrl.addListener(() => _onFieldChanged(_ActiveField.pickup));
    _destCtrl.addListener(()   => _onFieldChanged(_ActiveField.destination));

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) setState(() => _active = _ActiveField.pickup);
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus) setState(() => _active = _ActiveField.destination);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _destFocus.requestFocus());
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
    if (q.isEmpty) {
      setState(() { _suggestions = const []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _fetchSuggestions(q),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    final results = await MapsService.autocomplete(query, sessionToken: _sessionToken);
    if (!mounted) return;
    setState(() { _suggestions = results; _searching = false; });
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
    setState(() { _loading = true; _error = null; _suggestions = const []; });
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
    if (!enabled) return null;
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location permission in your browser/device settings.'),
              backgroundColor: AppColors.error,
            ),
          );
          if (!kIsWeb) context.push(AppRoutes.locationPermission);
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
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  bool get _activeIsSearching =>
      _searching && _activeCtrl.text.trim().isNotEmpty;

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
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(AppStrings.whereAreYouGoing, style: AppTextStyles.h4),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
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
    return Column(
      children: [
        _RouteCard(
          pickupCtrl:  _pickupCtrl,
          destCtrl:    _destCtrl,
          pickupFocus: _pickupFocus,
          destFocus:   _destFocus,
          activeField: _active,
          searching:   _activeIsSearching,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        ListTile(
          leading: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
                color: AppColors.successLight, shape: BoxShape.circle),
            child: const Icon(Icons.my_location_rounded,
                color: AppColors.success, size: 20),
          ),
          title: Text(AppStrings.useCurrentLoc, style: AppTextStyles.bodyLarge),
          subtitle: Text('Set as your pickup location',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          onTap: _useCurrentLocation,
        ),
        const Divider(height: 1),
        if (_suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _active == _ActiveField.pickup
                    ? 'Pickup suggestions'
                    : 'Destination suggestions',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final query = _activeCtrl.text.trim();

    if (_suggestions.isNotEmpty) {
      return ListView.separated(
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, i) {
          final s        = _suggestions[i];
          final isPickup = _active == _ActiveField.pickup;
          return ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppColors.surface, shape: BoxShape.circle),
              child: Icon(Icons.location_on_rounded,
                  color: isPickup ? AppColors.pickupPin : AppColors.destinationPin,
                  size: 20),
            ),
            title: Text(s.mainText, style: AppTextStyles.bodyLarge),
            subtitle: s.secondaryText.isNotEmpty
                ? Text(s.secondaryText,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary))
                : null,
            onTap: () => _selectSuggestion(s),
          );
        },
      );
    }

    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(
                _active == _ActiveField.pickup
                    ? 'Type to search for a pickup location'
                    : 'Type a destination to search',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickupCtrl,
    required this.destCtrl,
    required this.pickupFocus,
    required this.destFocus,
    required this.activeField,
    required this.searching,
  });

  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final FocusNode pickupFocus;
  final FocusNode destFocus;
  final _ActiveField activeField;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Route dots + connecting line ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _dot(AppColors.pickupPin),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.pickupPin.withValues(alpha: 0.5),
                            AppColors.destinationPin.withValues(alpha: 0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _dot(AppColors.destinationPin),
                ],
              ),
            ),

            // ── Fields ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  _SearchField(
                    controller:  pickupCtrl,
                    focusNode:   pickupFocus,
                    hint:        'Pickup location',
                    isActive:    activeField == _ActiveField.pickup,
                    showSpinner: activeField == _ActiveField.pickup && searching,
                  ),
                  const Divider(height: 1, indent: 0, endIndent: 16),
                  _SearchField(
                    controller:  destCtrl,
                    focusNode:   destFocus,
                    hint:        'Where to?',
                    isActive:    activeField == _ActiveField.destination,
                    showSpinner: activeField == _ActiveField.destination && searching,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 11, height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4),
          ],
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isActive,
    required this.showSpinner,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isActive;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                isDense:        true,
                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 0),
                border:         InputBorder.none,
              ),
            ),
          ),
          if (showSpinner)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                focusNode.requestFocus();
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.clear_rounded,
                    size: 18, color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> showSearchDestinationDrawer(
  BuildContext context, {
  bool openSelectRideAfter = true,
}) async {
  final result = await showAppBottomDrawer<SearchDestinationResult>(
    context: context,
    child: const SearchDestinationScreen(asSheet: true),
  );
  if (result != SearchDestinationResult.openSelectRide) return false;
  if (!context.mounted) return false;
  if (openSelectRideAfter) {
    await showSelectRideDrawer(context);
  }
  return true;
}
