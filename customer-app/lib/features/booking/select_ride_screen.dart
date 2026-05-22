import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    // Profile gate — name and phone are sufficient; email is optional.
    final user = ref.read(currentUserProvider);
    final isComplete = user != null &&
        user.name.isNotEmpty &&
        user.phone.isNotEmpty;

    if (!isComplete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your profile before booking'),
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
        _PaymentPicker(
          selected: _paymentMethod,
          onChanged: (v) => setState(() => _paymentMethod = v),
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
                Container(width: 10, height: 10,
                    decoration: const BoxDecoration(
                        color: AppColors.pickupPin, shape: BoxShape.circle)),
                Container(width: 2, height: 24, color: AppColors.divider),
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: AppColors.destinationPin,
                        borderRadius: BorderRadius.circular(2))),
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
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  vt.category == 'delivery'
                      ? Icons.delivery_dining_rounded
                      : Icons.directions_car_rounded,
                  color: AppColors.textSecondary,
                  size: 28,
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

class _PaymentPicker extends StatelessWidget {
  const _PaymentPicker({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text('Payment:', style: AppTextStyles.bodyMedium),
            const SizedBox(width: 12),
            _Chip('Cash',    'cash',         selected, onChanged, Icons.payments_outlined),
            const SizedBox(width: 8),
            _Chip('Transfer','bank_transfer', selected, onChanged, Icons.account_balance_rounded),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, this.selected, this.onChanged, this.icon);
  final String label, value, selected;
  final ValueChanged<String> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.black : AppColors.inputFill,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: active ? AppColors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? AppColors.white : AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
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
