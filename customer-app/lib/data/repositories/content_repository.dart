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
}
