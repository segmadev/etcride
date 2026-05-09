import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/maps/google_maps_js_loader.dart';

/// Full-size Google Map that handles web vs mobile transparently.
/// On web it waits for the JS SDK to load before rendering.
/// On mobile it renders immediately.
class GoogleMapView extends StatelessWidget {
  const GoogleMapView({
    super.key,
    required this.initialPosition,
    required this.apiKey,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.mapToolbarEnabled = false,
    this.zoom = 15,
  });

  final LatLng initialPosition;
  final String apiKey;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController)? onMapCreated;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final cameraPosition = CameraPosition(target: initialPosition, zoom: zoom);

    if (!kIsWeb) {
      return GoogleMap(
        initialCameraPosition: cameraPosition,
        markers: markers,
        polylines: polylines,
        myLocationEnabled: myLocationEnabled,
        myLocationButtonEnabled: myLocationButtonEnabled,
        zoomControlsEnabled: zoomControlsEnabled,
        mapToolbarEnabled: mapToolbarEnabled,
        onMapCreated: onMapCreated,
      );
    }

    return FutureBuilder<bool>(
      future: ensureGoogleMapsJsLoaded(apiKey: apiKey),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data != true) {
          return const _MapPlaceholder();
        }
        return GoogleMap(
          initialCameraPosition: cameraPosition,
          markers: markers,
          polylines: polylines,
          myLocationEnabled: myLocationEnabled,
          myLocationButtonEnabled: myLocationButtonEnabled,
          zoomControlsEnabled: zoomControlsEnabled,
          mapToolbarEnabled: mapToolbarEnabled,
          onMapCreated: onMapCreated,
        );
      },
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: const Icon(Icons.map_outlined, color: AppColors.textHint, size: 48),
      );
}
