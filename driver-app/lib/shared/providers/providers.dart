import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../data/models/driver_model.dart';
import '../../data/models/job_model.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/driver_auth_repository.dart';
import '../../data/repositories/driver_repository.dart';

final apiClientProvider = Provider<ApiClient>((_) => ApiClient.instance);

final secureStorageProvider = Provider<SecureStorage>((_) => SecureStorage.instance);

final driverAuthRepositoryProvider = Provider<DriverAuthRepository>((ref) {
  return DriverAuthRepository(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  );
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.read(apiClientProvider));
});

final currentDriverProvider = StateProvider<DriverModel?>((ref) => null);

final driverAuthInitProvider = FutureProvider<DriverModel?>((ref) async {
  final repo   = ref.read(driverAuthRepositoryProvider);
  final driver = await repo.getCachedDriver();
  if (driver != null) {
    ref.read(currentDriverProvider.notifier).state = driver;
  }
  return driver;
});

// ── Auth mode & locations ────────────────────────────────────────────────────

/// Driver auth mode: 'both' | 'otp' | 'password'
final driverAuthConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    return await ref.read(contentRepositoryProvider).getDriverAuthConfig();
  } catch (_) {
    return {'mode': 'both'};
  }
});

final driverAuthModeProvider = Provider<String>((ref) {
  final v    = ref.watch(driverAuthConfigProvider).valueOrNull;
  final mode = v?['mode']?.toString() ?? 'both';
  return ['otp', 'password', 'both'].contains(mode) ? mode : 'both';
});

/// List of {state: String, lgas: List} — empty when not configured.
final driverLocationsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    return await ref.read(contentRepositoryProvider).getDriverLocations();
  } catch (_) {
    return [];
  }
});

// ── Driver repository & job providers ────────────────────────────────────────

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.read(apiClientProvider));
});

/// Online/offline state — optimistic, synced with backend on change.
final driverOnlineProvider = StateProvider<bool>((ref) {
  return ref.read(currentDriverProvider)?.isOnline ?? false;
});

/// Active jobs assigned to the driver.
final driverJobsProvider = FutureProvider<List<JobModel>>((ref) async {
  try {
    return await ref.read(driverRepositoryProvider).getJobs();
  } catch (_) {
    return [];
  }
});

/// Recent trip history (last 20).
final driverHistoryProvider = FutureProvider<List<JobModel>>((ref) async {
  try {
    return await ref.read(driverRepositoryProvider).getHistory();
  } catch (_) {
    return [];
  }
});

/// Unread notification count — used for badge in the top bar.
final driverUnreadNotifCountProvider = FutureProvider<int>((ref) async {
  try {
    final notifs = await ref.read(driverRepositoryProvider).getNotifications();
    return notifs.where((n) => n['is_read'] == 0 || n['is_read'] == '0').length;
  } catch (_) {
    return 0;
  }
});

// ── Map settings ─────────────────────────────────────────────────────────────

final mapSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(contentRepositoryProvider);
  return await repo.getMapSettings();
});

final mapApiKeyProvider = Provider<String>((ref) {
  final v = ref.watch(mapSettingsProvider).valueOrNull;
  return v?['api_key']?.toString() ?? '';
});
