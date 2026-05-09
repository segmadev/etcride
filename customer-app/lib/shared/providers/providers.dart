import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../data/models/booking_draft.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/content_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((_) => ApiClient.instance);

final secureStorageProvider = Provider<SecureStorage>((_) => SecureStorage.instance);

// ── Repositories ──────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.read(apiClientProvider),
      ref.read(secureStorageProvider),
    ));

final bookingRepositoryProvider = Provider<BookingRepository>((ref) => BookingRepository(
      ref.read(apiClientProvider),
    ));

final contentRepositoryProvider = Provider<ContentRepository>((ref) => ContentRepository(
      ref.read(apiClientProvider),
    ));

// ── Auth state ────────────────────────────────────────────────────────────────

/// Currently authenticated user. Null = not logged in.
final currentUserProvider = StateProvider<UserModel?>((ref) => null);

/// Async initialiser — loads cached user from secure storage on app start.
final authInitProvider = FutureProvider<UserModel?>((ref) async {
  final repo = ref.read(authRepositoryProvider);
  final user = await repo.getCachedUser();
  if (user != null) {
    ref.read(currentUserProvider.notifier).state = user;
  }
  return user;
});

// ── Booking draft (shared across booking flow screens) ───────────────────────

/// Holds the current booking being assembled across multiple screens.
final bookingDraftProvider = StateProvider<BookingDraft>((ref) => const BookingDraft());

// ── Payment ───────────────────────────────────────────────────────────────────

final selectedPaymentMethodProvider = StateProvider<String>((ref) => 'cash');

final mapSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(contentRepositoryProvider);
  return await repo.getMapSettings();
});

final mapApiKeyProvider = Provider<String>((ref) {
  final v = ref.watch(mapSettingsProvider).valueOrNull;
  return v?['api_key']?.toString() ?? '';
});

/// The user's first active booking (ride or delivery). Null when idle.
/// Refresh by calling ref.invalidate(activeBookingProvider).
final activeBookingProvider = FutureProvider.autoDispose<BookingModel?>((ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return null;
  final list = await ref.read(bookingRepositoryProvider).getMyBookings();
  return list.where((b) => b.status.isActive).firstOrNull;
});
