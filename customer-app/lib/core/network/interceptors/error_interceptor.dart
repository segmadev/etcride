import 'package:dio/dio.dart';
import 'dart:convert';
import '../../errors/app_exception.dart';
import '../session_expired_notifier.dart';
import '../account_deactivation_notifier.dart';

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
          if (!isPublicAuth) {
            // Notify the app root so it can clear credentials and redirect.
            SessionExpiredNotifier.instance.signal();
          }
          handler.next(
            err.copyWith(
              error: isPublicAuth
                  ? ApiException(msg, statusCode: status)
                  : UnauthorizedException(msg),
            ),
          );
          return;
        }

        if (status == 403) {
          // Account has been deactivated due to deletion request
          if (msg.toLowerCase().contains('deactivated')) {
            AccountDeactivationNotifier.instance.signal();
          }
          handler.next(err.copyWith(
            error: ApiException(msg, statusCode: status),
          ));
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
      final map  = data is Map
          ? data
          : data is String
              ? (jsonDecode(data) as Map?)
              : null;
      if (map == null) return 'Request failed.';

      final message = map['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;

      // Fall back to first field-level validation error when message is absent.
      final errors = map['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        if (first is String && first.isNotEmpty) return first;
      }
    } catch (_) {}
    return 'Request failed.';
  }
}
