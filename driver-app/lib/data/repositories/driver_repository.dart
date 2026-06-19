import '../models/job_model.dart';
import '../models/trip_message_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/errors/app_exception.dart';

class DriverRepository {
  DriverRepository(this._client);
  final ApiClient _client;

  // ── Availability ─────────────────────────────────────────────────────────────

  Future<void> setAvailability(bool isOnline) async {
    final res = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.driverAvailability,
      body: {'is_online': isOnline ? 1 : 0},
    );
    if (res == null) throw const ApiException('Failed to update availability');
  }

  // ── Location ping ─────────────────────────────────────────────────────────────

  Future<void> pingLocation(double lat, double lng) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverLocationPing,
      body: {'lat': lat, 'lng': lng},
    );
  }

  // ── Active jobs ───────────────────────────────────────────────────────────────

  /// PHP returns `{ code, message, data: [...] }`.
  /// ApiClient already unwraps `body['data']` and returns it as T.
  /// Use `get<List>` so the List cast succeeds; `get<Map>` would throw TypeError.
  Future<List<JobModel>> getJobs() async {
    final res = await _client.get<List>(ApiEndpoints.driverJobs);
    if (res == null) return [];
    return res
        .whereType<Map<String, dynamic>>()
        .map(JobModel.fromJson)
        .toList();
  }

  Future<JobModel> getJobById(String id) async {
    // Single-job endpoint returns data: { booking... } — Map is correct here.
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.driverJobById(id),
    );
    if (res is Map<String, dynamic>) return JobModel.fromJson(res);
    throw const ApiException('Job not found');
  }

  // ── Job lifecycle ─────────────────────────────────────────────────────────────

  Future<void> acceptJob(String id) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.acceptJob(id),
      body: {},
    );
  }

  Future<void> rejectJob(String id) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.rejectJob(id),
      body: {},
    );
  }

  Future<void> cancelJob(String id, {required String reason}) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.cancelJob(id),
      body: {'reason': reason},
    );
  }

  Future<void> arriveAtPickup(
    String id, {
    double? lat,
    double? lng,
    double? gpsAccuracyM,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.arriveJob(id),
      body: {
        // ignore: use_null_aware_elements
        if (lat != null) 'lat': lat,
        // ignore: use_null_aware_elements
        if (lng != null) 'lng': lng,
        // ignore: use_null_aware_elements
        if (gpsAccuracyM != null) 'gps_accuracy_m': gpsAccuracyM,
      },
    );
  }

  Future<void> confirmPickupPayment(String id) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.confirmPickupPayment(id),
      body: {},
    );
  }

  Future<void> pickupPackage(String id) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.pickupJob(id),
      body: {},
    );
  }

  Future<void> startTrip(String id) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.startJob(id),
      body: {},
    );
  }

  Future<void> completeTrip(String id, {double? distanceKm, double? durationMinutes}) async {
    final body = <String, dynamic>{};
    if (distanceKm != null) body['distance_km'] = distanceKm;
    if (durationMinutes != null) body['duration_minutes'] = durationMinutes;
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.completeJob(id),
      body: body,
    );
  }

  /// Called from the payment screen after the driver physically collects
  /// payment. Transitions the job from `payment_pending` → `completed`.
  Future<void> confirmPayment(String id) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.confirmPayment(id),
      body: {},
    );
  }

  Future<void> reachStop(String jobId, String stopId) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.reachStop(jobId, stopId),
      body: {},
    );
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Fetches chat messages for a job. If [since] is provided, only messages
  /// created after that timestamp are returned (incremental poll).
  Future<List<TripMessageModel>> getMessages(String jobId, {DateTime? since}) async {
    final res = await _client.get<List>(
      ApiEndpoints.jobMessages(jobId),
      params: {if (since != null) 'since': since.toIso8601String()},
    );
    if (res == null) return [];
    return res
        .whereType<Map<String, dynamic>>()
        .map(TripMessageModel.fromJson)
        .toList();
  }

  Future<TripMessageModel> sendMessage(String jobId, String message) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.jobMessages(jobId),
      body: {'message': message},
    );
    return TripMessageModel.fromJson(res!);
  }

  // ── History ───────────────────────────────────────────────────────────────────

  Future<List<JobModel>> getHistory({int page = 1, int limit = 20}) async {
    final res = await _client.get<List>(
      '/driver/history',
      params: {'page': page, 'limit': limit},
    );
    if (res == null) return [];
    return res
        .whereType<Map<String, dynamic>>()
        .map(JobModel.fromJson)
        .toList();
  }

  // ── Notifications ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await _client.get<List>('/driver/notifications');
    if (res == null) return [];
    return res.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _client.put<Map<String, dynamic>>(
      '/driver/notifications/$id/read',
      body: {},
    );
  }

  Future<List<Map<String, dynamic>>> getChatThreads() async {
    final list = await _client.get<List<dynamic>>(ApiEndpoints.driverChatThreads);
    return (list ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> markChatRead(String bookingId) async {
    await _client.post<void>(ApiEndpoints.markDriverChatRead(bookingId), body: {});
  }
}
