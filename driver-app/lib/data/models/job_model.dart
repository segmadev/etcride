class JobStop {
  const JobStop({
    required this.id,
    required this.address,
    this.lat,
    this.lng,
    this.reachedAt,
  });

  final String  id;
  final String  address;
  final double? lat;
  final double? lng;
  final String? reachedAt;

  bool get isReached => reachedAt != null;

  factory JobStop.fromJson(Map<String, dynamic> j) => JobStop(
        id:         j['id']?.toString()      ?? '',
        address:    j['address']?.toString() ?? '',
        lat:        double.tryParse(j['lat']?.toString() ?? ''),
        lng:        double.tryParse(j['lng']?.toString() ?? ''),
        reachedAt:  j['reached_at']?.toString(),
      );
}

class JobModel {
  const JobModel({
    required this.id,
    required this.status,
    required this.bookingRef,
    required this.bookingType,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.estimatedFare,
    required this.createdAt,
    this.passengerName,
    this.passengerPhone,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.stops = const [],
    this.finalFare,
    this.paymentMethod,
    this.paymentStatus,
    this.distanceKm,
    this.completedAt,
    this.durationMinutes,
    this.routePolyline,
    this.arrivedAt,
    this.freeWaitingMinutes = 3,
    this.waitingChargePerMin = 0.0,
    this.cancelledByRole,
    this.cancellationReason,
  });

  final String  id;
  final String  status;        // assigned | accepted | driver_arrived | started | completed | cancelled
  final String  bookingRef;
  final String  bookingType;   // ride | delivery
  final String  pickupAddress;
  final String  destinationAddress;
  final double  estimatedFare;
  final String  createdAt;

  final String? passengerName;
  final String? passengerPhone;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final List<JobStop> stops;
  final double? finalFare;
  final String? paymentMethod;
  final String? paymentStatus;
  final double? distanceKm;
  final String? completedAt;
  final int?    durationMinutes;
  final String? routePolyline;
  final String? arrivedAt;
  final int     freeWaitingMinutes;
  final double  waitingChargePerMin;
  final String? cancelledByRole;      // 'customer' | 'driver' | 'admin' | null
  final String? cancellationReason;

  double get displayFare => finalFare ?? estimatedFare;

  // PHP lifecycle: pending → assigned → accepted → arrived → in_progress → payment_pending → completed
  bool get isActive    => ['assigned', 'accepted', 'arrived', 'in_progress', 'payment_pending'].contains(status);
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// True when driver has accepted but not yet marked arrival
  bool get canArrive   => status == 'accepted';
  /// True when driver has arrived at pickup, waiting to start
  bool get canStart    => status == 'arrived';
  /// True when trip is in progress
  bool get canComplete => status == 'in_progress';

  factory JobModel.fromJson(Map<String, dynamic> j) {
    final List<JobStop> stops = [];
    final rawStops = j['stops'];
    if (rawStops is List) {
      for (final s in rawStops) {
        if (s is Map<String, dynamic>) stops.add(JobStop.fromJson(s));
      }
    }

    // Passenger may be nested under 'user' or top-level
    final user = j['user'] is Map<String, dynamic>
        ? j['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    return JobModel(
      id:                   j['id']?.toString()                    ?? '',
      status:               j['status']?.toString()                ?? 'assigned',
      bookingRef:           (j['booking_ref'] ?? j['booking_code'])?.toString() ?? '',
      bookingType:          j['booking_type']?.toString()          ?? 'ride',
      pickupAddress:        j['pickup_address']?.toString()        ?? '',
      destinationAddress:   j['destination_address']?.toString()   ?? '',
      estimatedFare:        double.tryParse(j['estimated_fare']?.toString() ?? '0') ?? 0,
      createdAt:            j['created_at']?.toString()            ?? '',
      // PHP returns customer_name / customer_phone at top-level; user object as fallback
      passengerName:        (j['customer_name'] ?? user['name'] ?? j['passenger_name'])?.toString(),
      passengerPhone:       (j['customer_phone'] ?? user['phone'] ?? j['passenger_phone'])?.toString(),
      pickupLat:            double.tryParse(j['pickup_lat']?.toString()         ?? ''),
      pickupLng:            double.tryParse(j['pickup_lng']?.toString()         ?? ''),
      destinationLat:       double.tryParse(j['destination_lat']?.toString()    ?? ''),
      destinationLng:       double.tryParse(j['destination_lng']?.toString()    ?? ''),
      stops:                stops,
      finalFare:            double.tryParse(j['final_fare']?.toString()         ?? ''),
      paymentMethod:        j['payment_method']?.toString(),
      paymentStatus:        j['payment_status']?.toString(),
      distanceKm:           double.tryParse(j['distance_km']?.toString()        ?? ''),
      completedAt:          j['completed_at']?.toString(),
      durationMinutes:      int.tryParse(j['duration_minutes']?.toString()      ?? ''),
      routePolyline:        j['route_polyline']?.toString(),
      arrivedAt:            j['arrived_at']?.toString(),
      freeWaitingMinutes:   int.tryParse(j['free_waiting_minutes']?.toString()    ?? '3') ?? 3,
      waitingChargePerMin:  double.tryParse(j['waiting_charge_per_min']?.toString() ?? '0') ?? 0.0,
      cancelledByRole:      j['cancelled_by_role']?.toString(),
      cancellationReason:   j['cancellation_reason']?.toString(),
    );
  }
}
