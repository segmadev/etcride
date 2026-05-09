import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles FCM registration and foreground message routing.
/// Call [PushService.init] once after Firebase.initializeApp().
///
/// SETUP REQUIRED:
///   1. Add google-services.json to android/app/
///   2. Add GoogleService-Info.plist to ios/Runner/
///   3. Run: flutterfire configure  (or manually add firebase_options.dart)
///   4. Call Firebase.initializeApp() in main() before runApp()

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the OS — no UI updates needed here.
  // The app will navigate when the user taps the notification.
}

class PushService {
  PushService._();

  static final FirebaseMessaging _fm = FirebaseMessaging.instance;

  static Future<void> init() async {
    if (kIsWeb) return; // FCM web requires a service worker; skip for now

    await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _onForegroundMessage(message);
    });
  }

  static void _onForegroundMessage(RemoteMessage message) {
    // Foreground messages: the booking screens already poll status,
    // so a notification arriving in the foreground doesn't need extra
    // navigation — the poll will pick up the state change within seconds.
    debugPrint('[FCM] foreground: ${message.notification?.title}');
  }

  /// Returns the FCM registration token for this device.
  /// Send this to the backend when the user logs in so the server
  /// can target push notifications to this device.
  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    return _fm.getToken();
  }

  /// Call after login to register the token with the backend.
  static Future<void> registerToken(Future<void> Function(String token) callback) async {
    final token = await getToken();
    if (token != null) await callback(token);
  }
}

// ── Riverpod provider for the FCM token ──────────────────────────────────────

final fcmTokenProvider = FutureProvider<String?>((ref) => PushService.getToken());
