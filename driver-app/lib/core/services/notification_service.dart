import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/router.dart';

@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the system; no UI work here.
}

class DriverNotificationService {
  DriverNotificationService._();
  static final DriverNotificationService instance = DriverNotificationService._();

  static const _channelId   = 'etcride_driver_main';
  static const _channelName = 'EtcRide Driver Notifications';

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  String? _pendingRoute;
  String? _pendingExtra;

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              importance: Importance.high,
            ),
          );

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (details) {
          _handlePayload(details.payload);
        },
      );

      FirebaseMessaging.onMessage.listen(_showLocal);
      FirebaseMessaging.onMessageOpenedApp.listen(_navigateNow);

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final (route, extra) = _routeFor(initial.data);
        _pendingRoute = route;
        _pendingExtra = extra;
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] DriverNotificationService.initialize() failed: $e');
    }
  }

  Future<String?> getToken() async {
    if (!_initialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  void onTokenRefresh(void Function(String) callback) {
    if (!_initialized) return;
    FirebaseMessaging.instance.onTokenRefresh.listen(callback);
  }

  void consumePending(BuildContext context) {
    if (!_initialized) return;
    final route = _pendingRoute;
    final extra = _pendingExtra;
    _pendingRoute = null;
    _pendingExtra = null;
    if (route != null) appRouter.go(route, extra: extra);
  }

  // ── private ─────────────────────────────────────────────────────────────────

  void _navigateNow(RemoteMessage message) {
    final (route, extra) = _routeFor(message.data);
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.go(route, extra: extra);
    });
  }

  void _showLocal(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _localNotifications.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handlePayload(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final (route, extra) = _routeFor(data);
      if (route != null) appRouter.go(route, extra: extra);
    } catch (_) {}
  }

  // All driver notification types → home (new jobs/updates show there).
  (String?, String?) _routeFor(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    return switch (type) {
      'trip_interest_request' => (AppRoutes.home, null),
      'booking_cancelled'     => (AppRoutes.home, null),
      'payment_received'      => (AppRoutes.home, null),
      'driver_rating'         => (AppRoutes.home, null),
      _                       => (null,           null),
    };
  }
}
