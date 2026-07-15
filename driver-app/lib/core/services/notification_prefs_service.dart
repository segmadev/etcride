import 'package:shared_preferences/shared_preferences.dart';

class DriverNotificationPrefsService {
  DriverNotificationPrefsService._();
  static final DriverNotificationPrefsService instance = DriverNotificationPrefsService._();

  static const String kNewJobs    = 'notif_pref_new_jobs';
  static const String kJobUpdates = 'notif_pref_job_updates';
  static const String kPayments   = 'notif_pref_payments';
  static const String kMessages   = 'notif_pref_messages';

  static const Map<String, String> _typeToKey = {
    'trip_interest_request': kNewJobs,
    'booking_cancelled'    : kJobUpdates,
    'payment_received'     : kPayments,
    'driver_rating'        : kPayments,
    'new_message'          : kMessages,
  };

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool isTypeEnabled(String type) {
    final key = _typeToKey[type];
    if (key == null) return true;
    return _prefs?.getBool(key) ?? true;
  }

  Future<void> setEnabled(String prefKey, bool value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
    _prefs = prefs;
  }

  bool getEnabled(String prefKey) => _prefs?.getBool(prefKey) ?? true;
}
