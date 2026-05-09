import 'package:intl/intl.dart';

abstract final class AppFormatters {
  /// Formats a number as Nigerian Naira: ₦4,800.00
  static String naira(num amount) =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 2, locale: 'en_NG')
          .format(amount);

  /// Compact fare without decimals if whole number: ₦4,800
  static String nairaCompact(num amount) {
    if (amount == amount.truncate()) {
      return NumberFormat.currency(symbol: '₦', decimalDigits: 0, locale: 'en_NG')
          .format(amount);
    }
    return naira(amount);
  }

  /// e.g. "Apr 22 • 9:03AM" — accepts DateTime or ISO-8601 String?
  static String tripDate(Object? dt) {
    final d = _toDateTime(dt);
    if (d == null) return '—';
    return DateFormat("MMM d • h:mma").format(d);
  }

  /// e.g. "Apr 22, 2026" — accepts DateTime or ISO-8601 String?
  static String fullDate(Object? dt) {
    final d = _toDateTime(dt);
    if (d == null) return '—';
    return DateFormat("MMM d, y").format(d);
  }

  static DateTime? _toDateTime(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Greeting based on time of day
  static String greeting(String name) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    return '$greet $name!';
  }

  /// Countdown timer string: "00:30"
  static String countdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Distance: "7.7 km" or "320 m"
  static String distance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  /// Duration: "8 mins"
  static String duration(int minutes) =>
      minutes == 1 ? '1 min' : '$minutes mins';
}
