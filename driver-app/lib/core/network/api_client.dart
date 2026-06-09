import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// Pre-configured Dio instance shared across all repositories.
/// Singleton so we don't create multiple Dio instances.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio = _buildDio();

  Dio get dio => _dio;

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: Duration(seconds: AppConfig.connectTimeout),
        receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(),
      ErrorInterceptor(),
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader:  false,
          requestBody:    true,
          responseBody:   false, // disabled: response bodies can contain sensitive data (e.g. API keys)
          error:          true,
          compact:        true,
        ),
    ]);

    return dio;
  }

  /// Convenience method — extracts `data` from the standard
  /// `{ code, message, data }` envelope and throws on error codes.
  Future<T?> request<T>({
    required String path,
    required String method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    T Function(dynamic json)? fromJson,
  }) async {
    late final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.request<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        data: data,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      final err = e.error;
      if (err is AppException) throw err;
      rethrow;
    }

    final body = response.data;
    if (body == null) throw const ParseException('Empty server response.');

    final codeRaw = body['code'];
    final code = switch (codeRaw) {
      int v => v,
      String v => int.tryParse(v),
      _ => null,
    };
    if (code != null && code >= 400) {
      final msg = body['message']?.toString().trim();
      throw ApiException(
        (msg == null || msg.isEmpty) ? 'Request failed.' : msg,
        statusCode: code,
      );
    }

    final payload = body['data'];
    if (payload == null) return null;
    return fromJson != null ? fromJson(payload) : payload as T;
  }

  Future<T?> get<T>(String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromJson,
  }) => request(path: path, method: 'GET', queryParameters: params, fromJson: fromJson);

  Future<T?> post<T>(String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
  }) => request(path: path, method: 'POST', data: body, fromJson: fromJson);

  Future<T?> put<T>(String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
  }) => request(path: path, method: 'PUT', data: body, fromJson: fromJson);

  Future<void> delete(String path) =>
      request(path: path, method: 'DELETE');

  /// Sends a multipart/form-data POST (for file uploads like KYC).
  Future<T?> postFormData<T>(String path, {
    required FormData formData,
    T Function(dynamic)? fromJson,
  }) async {
    late final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        path,
        data: formData,
        options: Options(
          method: 'POST',
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      final err = e.error;
      if (err is AppException) throw err;
      rethrow;
    }

    final body = response.data;
    if (body == null) throw const ParseException('Empty server response.');

    final codeRaw = body['code'];
    final code = switch (codeRaw) {
      int v => v,
      String v => int.tryParse(v),
      _ => null,
    };
    if (code != null && code >= 400) {
      final msg = body['message']?.toString().trim();
      throw ApiException(
        (msg == null || msg.isEmpty) ? 'Request failed.' : msg,
        statusCode: code,
      );
    }

    final payload = body['data'];
    if (payload == null) return null;
    return fromJson != null ? fromJson(payload) : payload as T;
  }
}
