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
        handler.next(err.copyWith(error: const NetworkException()));
        return;

      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        final msg = _extractMessage(err.response);

        if (status == 401) {
          final path = err.requestOptions.path;
          final isPublicAuth = path.startsWith('/auth/') &&
              path != '/auth/logout' &&
              path != '/auth/profile';
          handler.next(
            err.copyWith(
              error: isPublicAuth
                  ? ApiException(msg, statusCode: status)
                  : UnauthorizedException(msg),
            ),
          );
          return;
        }

        if (status >= 500) {
          handler.next(err.copyWith(error: ServerException(msg)));
          return;
        }

        handler.next(err.copyWith(error: ApiException(msg, statusCode: status)));
        return;

      default:
        handler.next(err.copyWith(error: ServerException(err.message ?? 'Unexpected error.')));
        return;
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
