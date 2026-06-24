import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../data/models/driver_model.dart';
import '../../data/models/job_model.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/driver_auth_repository.dart';
import '../../data/repositories/driver_repository.dart';
import '../../data/repositories/terms_repository.dart';
import '../../data/repositories/account_deletion_repository.dart';

final apiClientProvider = Provider<ApiClient>((_) => ApiClient.instance);

final secureStorageProvider = Provider<SecureStorage>((_) => SecureStorage.instance);

final driverAuthRepositoryProvider = Provider<DriverAuthRepository>((ref) {
  return DriverAuthRepository(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  );
});

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.read(apiClientProvider));
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.read(apiClientProvider));
});

final termsRepositoryProvider = Provider<TermsRepository>((ref) {
  return TermsRepository(ref.read(apiClientProvider));
});

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((ref) {
  return AccountDeletionRepository(ref.read(apiClientProvider));
});

final currentDriverProvider = StateProvider<DriverModel?>((ref) => null);

final driverOnlineProvider = StateProvider<bool>((ref) {
  return ref.watch(currentDriverProvider)?.isOnline ?? false;
});

final driverAuthInitProvider = FutureProvider<DriverModel?>((ref) async {
  final repo = ref.read(driverAuthRepositoryProvider);
  final driver = await repo.getCachedDriver();
  if (driver != null) {
    ref.read(currentDriverProvider.notifier).state = driver;
  }
  return driver;
});

/// Validates the current auth token. Returns true if valid, false otherwise.
final driverAuthValidationProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(driverAuthRepositoryProvider);
  final isValid = await repo.validateAuth();
  if (!isValid) {
    // Token is invalid — clear driver and force re-login
    ref.read(currentDriverProvider.notifier).state = null;
    await ref.read(secureStorageProvider).clearAll();
  }
  return isValid;
});

final mapSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(contentRepositoryProvider);
  return await repo.getMapSettings();
});

final commonDetailsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(contentRepositoryProvider).getCommonDetails();
});

final mapApiKeyProvider = Provider<String>((ref) {
  final v = ref.watch(mapSettingsProvider).valueOrNull;
  return v?['api_key']?.toString() ?? '';
});

final driverJobsProvider = FutureProvider<List<JobModel>>((ref) async {
  return ref.read(driverRepositoryProvider).getJobs();
});

final driverHistoryProvider = FutureProvider<List<JobModel>>((ref) async {
  return ref.read(driverRepositoryProvider).getHistory();
});

final driverNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(driverRepositoryProvider).getNotifications();
});

bool _isUnread(Map<String, dynamic> n) {
  final v = n['is_read'];
  return !(v == 1 || v == '1' || v == true);
}

final driverUnreadNotifCountProvider = FutureProvider<int>((ref) async {
  final notifs = await ref.watch(driverNotificationsProvider.future);
  return notifs.where(_isUnread).length;
});

/// Auth mode returned by /content/driver-auth-config: 'otp' | 'password' | 'both'
final driverAuthConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(contentRepositoryProvider).getDriverAuthConfig();
});

final driverAuthModeProvider = Provider<String>((ref) {
  return ref.watch(driverAuthConfigProvider).valueOrNull?['mode']?.toString() ?? 'both';
});

/// List of {state, lgas:[...]} from /content/driver-locations
final driverLocationsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(contentRepositoryProvider).getDriverLocations();
});
