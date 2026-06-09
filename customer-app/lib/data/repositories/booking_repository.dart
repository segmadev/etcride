import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/booking_model.dart';

class BookingRepository {
  const BookingRepository(this._client);
  final ApiClient _client;

  /// Maps the backend's snake_case booking row to the camelCase keys
  /// expected by [BookingModel.fromJson], and flattens the nested driver object.
  static Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    // Flatten nested driver object returned by show()
    final driver = raw['driver'] as Map<String, dynamic>?;

    // Status: backend stores snake_case ('in_progress', 'payment_pending')
    // but the generated enum map uses camelCase values.
    final rawStatus = (raw['status'] ?? 'pending').toString();
    final status = switch (rawStatus) {
      'in_progress'      => 'inProgress',
      'payment_pending'  => 'paymentPending',
      _                  => rawStatus,
    };

    // Payment method: backend stores snake_case
    final rawPay = (raw['payment_method'] ?? raw['pay_mode_snapshot'])?.toString();
    final paymentMethod = switch (rawPay) {
      'bank_transfer' => 'bankTransfer',
      'cash'          => 'cash',
      'flutterwave'   => 'flutterwave',
      _               => null,
    };

    return {
      'id':                 raw['id'] ?? '',
      'bookingCode':        raw['booking_code'] ?? '',
      'status':             status,
      'bookingType':        raw['booking_type'] ?? 'ride',
      'pickupAddress':      raw['pickup_address'] ?? '',
      'destinationAddress': raw['destination_address'] ?? '',
      'pickupLat':          _toDouble(raw['pickup_lat']),
      'pickupLng':          _toDouble(raw['pickup_lng']),
      'destinationLat':     _toDouble(raw['destination_lat']),
      'destinationLng':     _toDouble(raw['destination_lng']),
      'estimatedFare':      _toDouble(raw['estimated_fare']),
      'finalFare':          _toDouble(raw['final_fare']),
      'paymentStatus':      raw['payment_status'] ?? 'pending',
      'paymentMethod':      paymentMethod,
      // Driver fields: flat from index/show joins, or nested from show()
      'driverId':           raw['driver_id']     ?? driver?['id'],
      'driverName':         raw['driver_name']   ?? driver?['name'],
      'driverPhone':        raw['driver_phone']  ?? driver?['phone'],
      'driverAvatar':       raw['driver_avatar'] ?? driver?['photo'],
      'driverRating':       _toDouble(raw['driver_rating'] ?? driver?['rating']),
      'vehicleTypeName':    raw['vehicle_type_name'],
      'vehiclePlate':       raw['vehicle_plate'] ?? raw['plate_number'],
      'vehicleColor':       raw['vehicle_color'],
      'numStops':           _toInt(raw['num_stops']),
      'durationMinutes':    _toInt(raw['duration_minutes']),
      'distanceKm':         _toDouble(raw['distance_km']),
      'routePolyline':      raw['route_polyline'],
      'routeDistanceMeters': _toInt(raw['route_distance_meters']),
      'routeDurationSeconds': _toInt(raw['route_duration_seconds']),
      'cancellationReason': raw['cancellation_reason'],
      'createdAt':          raw['created_at'],
      'updatedAt':          raw['updated_at'],
      // Live tracking / search fields (computed server-side on each show() call)
      'driverEtaMinutes':   _toInt(raw['driver_eta_minutes']),
      'driverDistanceKm':   _toDouble(raw['driver_distance_km']),
      'lastEvent':          raw['last_event']?.toString(),
      'alternativeTypes':   (raw['alternative_types'] as List?) ?? const [],
      // Waiting time
      'arrivedAt':          raw['arrived_at']?.toString(),
      'freeWaitingMinutes': _toInt(raw['free_waiting_minutes'] ?? 3),
      'waitingChargePerMin': _toDouble(raw['waiting_charge_per_min'] ?? 0),
      'waitingExtraCharge': _toDouble(raw['waiting_extra_charge'] ?? 0),
    };
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Get fare estimate before booking.
  Future<Map<String, dynamic>> estimateFare({
    required String vehicleTypeId,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    List<Map<String, dynamic>> stops = const [],
    double? distanceKm,
  }) async {
    return await _client.post<Map<String, dynamic>>(
      ApiEndpoints.fareEstimate,
      body: {
        'vehicle_type_id': vehicleTypeId,
        'pickup_lat':       pickupLat,
        'pickup_lng':       pickupLng,
        'destination_lat':  destinationLat,
        'destination_lng':  destinationLng,
        if (stops.isNotEmpty) 'stops': stops,
        if (distanceKm != null) 'distance_km': distanceKm,
      },
    ) ?? {};
  }

  /// Create a new booking. Returns the created booking.
  Future<BookingModel> createBooking({
    required String vehicleTypeId,
    required String bookingType,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    List<Map<String, dynamic>> stops = const [],
    double? distanceKm,
    String? notes,
    String? recipientName,
    String? recipientPhone,
    String? packageDescription,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.bookings,
      body: {
        'vehicle_type_id':     vehicleTypeId,
        'booking_type':        bookingType,
        'pickup_address':      pickupAddress,
        'pickup_lat':          pickupLat,
        'pickup_lng':          pickupLng,
        'destination_address': destinationAddress,
        'destination_lat':     destinationLat,
        'destination_lng':     destinationLng,
        if (stops.isNotEmpty) 'stops': stops,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (notes != null) 'notes': notes,
        if (recipientName != null) 'recipient_name': recipientName,
        if (recipientPhone != null) 'recipient_phone': recipientPhone,
        if (packageDescription != null) 'package_description': packageDescription,
      },
    );
    if (data == null) throw const FormatException('Empty response.');
    return BookingModel.fromJson(_normalize(data));
  }

  /// Poll booking status (for requesting / driver assigned / in-progress screens).
  Future<BookingModel> getBooking(String id) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.bookingById(id),
    );
    if (data == null) throw const FormatException('Empty response.');
    return BookingModel.fromJson(_normalize(data));
  }

  Future<({String status, double? lat, double? lng, String? lastSeen})> trackBooking(String id) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.trackBooking(id),
    );
    final status = data?['status']?.toString() ?? '';
    final loc = data?['location'] as Map?;
    final lat = _toDouble(loc?['lat']);
    final lng = _toDouble(loc?['lng']);
    final lastSeen = loc?['last_seen']?.toString();
    return (
      status: status,
      lat: (lat == 0.0 && lng == 0.0) ? null : lat,
      lng: (lat == 0.0 && lng == 0.0) ? null : lng,
      lastSeen: lastSeen,
    );
  }

  /// Cancel a booking.
  /// Trigger a new driver search (unassigns current driver and re-searches).
  Future<void> findAnotherDriver(String id) async {
    await _client.post<void>(
      ApiEndpoints.findDriver(id),
      body: {},
    );
  }

  Future<void> cancelBooking(String id, {String reason = 'Cancelled by user'}) async {
    await _client.post<void>(
      ApiEndpoints.cancelBooking(id),
      body: {'reason': reason},
    );
  }

  Future<void> updatePaymentMethod(String bookingId, String paymentMethod) async {
    await _client.put<Map<String, dynamic>>(
      ApiEndpoints.paymentMethod(bookingId),
      body: {'payment_method': paymentMethod},
    );
  }

  Future<void> rateDriver(String bookingId, {required int rating, String? comment}) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.rateBooking(bookingId),
      body: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
  }

  Future<List<BookingModel>> getMyBookings({String? status}) async {
    final list = await _client.get<List<dynamic>>(
      ApiEndpoints.bookings,
      params: {if (status != null) 'status': status},
    );
    return (list ?? const [])
        .cast<Map<String, dynamic>>()
        .map((j) => BookingModel.fromJson(_normalize(j)))
        .toList();
  }

  /// Fetch active vehicle types for the booking flow.
  Future<List<dynamic>> getVehicleTypes({String? bookingType}) async {
    final data = await _client.get<List<dynamic>>(
      ApiEndpoints.vehicleTypes,
      params: {if (bookingType != null) 'type': bookingType},
    );
    return data ?? const [];
  }
}
