import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

/// Fetches public CMS content: app details, T&C, privacy policy.
class ContentRepository {
  const ContentRepository(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getCommonDetails() async {
    return await _client.get<Map<String, dynamic>>(ApiEndpoints.contentCommon) ?? {};
  }

  Future<Map<String, String>> getTcAndPolicy() async {
    final data = await _client.get<Map<String, dynamic>>(ApiEndpoints.contentTcp) ?? {};
    return {
      'terms':  data['terms']?.toString()  ?? '',
      'policy': data['policy']?.toString() ?? '',
    };
  }

  Future<Map<String, dynamic>> getMapSettings() async {
    return await _client.get<Map<String, dynamic>>(ApiEndpoints.mapSettings) ?? {};
  }

  /// Returns {'mode': 'both'|'otp'|'password'}
  Future<Map<String, dynamic>> getDriverAuthConfig() async {
    return await _client.get<Map<String, dynamic>>(ApiEndpoints.driverAuthConfig) ?? {'mode': 'both'};
  }

  /// Returns list of {state, lgas:[...]} objects.
  Future<List<dynamic>> getDriverLocations() async {
    final data = await _client.get<dynamic>(ApiEndpoints.driverLocations);
    if (data is List) return data;
    if (data is Map && data['locations'] is List) return data['locations'] as List;
    return [];
  }
}
