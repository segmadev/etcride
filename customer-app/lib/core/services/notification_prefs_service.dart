import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefsService {
  NotificationPrefsService._();
  static final NotificationPrefsService instance = NotificationPrefsService._();

  static const String kTripUpdates = 'notif_pref_trip_updates';
  static const String kPayments    = 'notif_pref_payments';
  static const String kMessages    = 'notif_pref_messages';

  static const Map<String, String> _typeToKey = {
    'driver_search'     : kTripUpdates,
    'driver_assigned'   : kTripUpdates,
    'driver_accepted'   : kTripUpdates,
    'driver_arrived'    : kTripUpdates,
    'trip_started'      : kTripUpdates,
    'trip_completed'    : kTripUpdates,
    'package_picked_up' : kTripUpdates,
    'stop_reached'      : kTripUpdates,
    'payment_required'  : kPayments,
    'payment_confirmed' : kPayments,
    'new_message'       : kMessages,
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
