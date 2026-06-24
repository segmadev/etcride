import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/router.dart';

// Must be a top-level function — Flutter requires this for background isolate.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the system; no UI work here.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId   = 'etcride_main';
  static const _channelName = 'EtcRide Notifications';

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Route saved from terminated-state launch; consumed by HomeScreen.
  String? _pendingRoute;
  String? _pendingExtra;

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

      // Create Android notification channel.
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

      // Show a local notification when a message arrives in the foreground.
      FirebaseMessaging.onMessage.listen(_showLocal);

      // App was in background; user tapped the system notification.
      FirebaseMessaging.onMessageOpenedApp.listen(_navigateNow);

      // iOS permission request.
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Terminated-state: app was launched by tapping a notification.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final (route, extra) = _routeFor(initial.data);
        _pendingRoute = route;
        _pendingExtra = extra;
      }

      _initialized = true;
    } catch (e) {
      // FCM setup failed (e.g. google-services.json missing).
      // App continues to work normally; push notifications are silently disabled.
      debugPrint('[FCM] NotificationService.initialize() failed: $e');
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

  /// Call from HomeScreen.initState (via addPostFrameCallback).
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

  (String?, String?) _routeFor(Map<String, dynamic> data) {
    final type      = data['type']?.toString() ?? '';
    final bookingId = data['booking_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) {
      return (null, null);
    }
    return switch (type) {
      'driver_search'     => (AppRoutes.requesting,      bookingId),
      'driver_assigned'   => (AppRoutes.requesting,      bookingId),
      'driver_accepted'   => (AppRoutes.driverAssigned,  bookingId),
      'driver_arrived'    => (AppRoutes.driverAssigned,  bookingId),
      'trip_started'      => (AppRoutes.tripInProgress,  bookingId),
      'package_picked_up' => (AppRoutes.tripInProgress,  bookingId),
      'stop_reached'      => (AppRoutes.tripInProgress,  bookingId),
      'trip_completed'    => (AppRoutes.tripCompleted,   bookingId),
      'payment_required'  => (AppRoutes.payment,         bookingId),
      _                   => (null,                      null),
    };
  }
}
