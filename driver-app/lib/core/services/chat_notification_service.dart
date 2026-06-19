import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

typedef _ThreadFetcher = Future<List<Map<String, dynamic>>> Function();

/// Global background service that polls all chat threads every [_interval].
///
/// Exposes [unreadCounts] — a ValueNotifier<Map<bookingId, int>> that any
/// widget can listen to for live badge counts.
///
/// Chat screens set [activeChatBookingId] on open / clear on close so:
///   • the service skips playing sound for that thread (screen handles it)
///   • the service resets the count to 0 for that thread (user is reading it)
class ChatNotificationService {
  ChatNotificationService._();
  static final ChatNotificationService instance = ChatNotificationService._();

  /// Booking ID of the currently-open chat screen.
  static String? activeChatBookingId;

  /// Live per-booking unread counts.
  final ValueNotifier<Map<String, int>> unreadCounts =
      ValueNotifier(const {});

  static const _interval = Duration(seconds: 15);

  Timer?          _timer;
  _ThreadFetcher? _fetcher;
  final AudioPlayer         _player     = AudioPlayer();
  final Map<String, String> _lastSeenAt = {};
  bool _started = false;

  void start(_ThreadFetcher fetcher) {
    if (_started) return;
    _fetcher = fetcher;
    _started = true;
    _seedThenPoll();
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    _fetcher = null;
    _lastSeenAt.clear();
    unreadCounts.value = const {};
  }

  void dispose() {
    stop();
    _player.dispose();
    unreadCounts.dispose();
  }

  Future<void> _seedThenPoll() async {
    await _poll(seed: true);
    if (!_started) return;
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  Future<void> _poll({bool seed = false}) async {
    if (_fetcher == null) return;
    try {
      final threads = await _fetcher!();
      final counts  = <String, int>{};
      bool  played  = false;

      for (final t in threads) {
        final bookingId  = t['booking_id']       as String? ?? '';
        final lastAt     = t['last_message_at']  as String? ?? '';
        final senderRole = t['last_sender_role'] as String? ?? '';
        final unread     = (t['unread_count'] as num?)?.toInt() ?? 0;

        if (bookingId.isEmpty) continue;

        counts[bookingId] = (bookingId == activeChatBookingId) ? 0 : unread;

        if (seed || lastAt.isEmpty) {
          _lastSeenAt[bookingId] = lastAt;
          continue;
        }

        // Sound: new message from customer while screen is not open
        if (senderRole != 'driver' &&
            bookingId != activeChatBookingId &&
            lastAt.isNotEmpty &&
            lastAt != _lastSeenAt[bookingId]) {
          if (!played) {
            try {
              await _player.play(AssetSource('sounds/chat_notify.wav'));
              played = true;
            } catch (_) {}
          }
        }
        _lastSeenAt[bookingId] = lastAt;
      }

      unreadCounts.value = counts;
    } catch (_) {}
  }
}
