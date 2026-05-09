import 'package:dio/dio.dart';
import '../../errors/app_exception.dart';

/// Converts Dio errors and non-2xx API responses into typed [AppException]s.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        throw const NetworkException();

      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        final msg = _extractMessage(err.response);

        if (status == 401) throw const UnauthorizedException();
        if (status >= 500) throw ServerException(msg);
        throw ApiException(msg, statusCode: status);

      default:
        throw ServerException(err.message ?? 'Unexpected error.');
    }
  }

  String _extractMessage(Response? response) {
    try {
      final data = response?.data;
      if (data is Map) return data['message']?.toString() ?? 'Request failed.';
    } catch (_) {}
    return 'Request failed.';
  }
}
