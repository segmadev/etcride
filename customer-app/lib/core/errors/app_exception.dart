/// Typed exceptions thrown by the network / repository layer.
/// UI layers catch these and show appropriate messages.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 4xx client errors returned by the API (e.g. validation, not-found).
final class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode});
  final int? statusCode;
}

/// 401 — token missing or expired.
final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired. Please log in again.']);
}

/// Network unreachable / timeout.
final class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection.']);
}

/// Unexpected / 5xx server errors.
final class ServerException extends AppException {
  const ServerException([super.message = 'Something went wrong. Please try again.']);
}

/// Parsing / serialisation errors.
final class ParseException extends AppException {
  const ParseException([super.message = 'Failed to parse server response.']);
}
