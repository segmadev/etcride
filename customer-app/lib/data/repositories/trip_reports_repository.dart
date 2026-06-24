import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class TripReportsRepository {
  const TripReportsRepository(this._client);

  final ApiClient _client;

  // Report a trip
  Future<Map<String, dynamic>> reportTrip({
    required String bookingId,
    required String reason,
    required String description,
  }) async {
    print('TripReportsRepository.reportTrip called');
    print('  bookingId: $bookingId');
    print('  reason: $reason');
    print('  description: $description');

    try {
      final endpoint = ApiEndpoints.reportTrip(bookingId);
      print('  endpoint: $endpoint');

      final response = await _client.post<Map<String, dynamic>>(
        endpoint,
        body: {
          'reason': reason,
          'description': description,
        },
      );

      print('  response: $response');
      return response ?? {};
    } catch (e) {
      print('  ERROR in reportTrip: $e');
      rethrow;
    }
  }

  // Request trip cancellation
  Future<Map<String, dynamic>> requestCancellation({
    required String bookingId,
    required String reason,
    required String description,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.requestCancellation(bookingId),
      body: {
        'reason': reason,
        'description': description,
      },
    );
    return response ?? {};
  }

  // Get report status
  Future<Map<String, dynamic>> getReportStatus(String bookingId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.reportStatus(bookingId),
    );
    return response ?? {};
  }

  // Get all customer reports
  Future<List<Map<String, dynamic>>> getMyReports() async {
    final response = await _client.get<List<dynamic>>(
      '/reports',
    );
    if (response == null) return [];
    return List<Map<String, dynamic>>.from(response);
  }
}
