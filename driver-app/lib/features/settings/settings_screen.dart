import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_prefs_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_back_button.dart';

class DriverSettingsScreen extends ConsumerStatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  ConsumerState<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends ConsumerState<DriverSettingsScreen> {
  bool _biometricsAvailable  = false;
  bool _biometricsEnabled    = false;
  bool _loggingOut           = false;
  bool _notificationsEnabled = false;
  bool _notifLoading         = false;
  bool _notifNewJobs    = true;
  bool _notifJobUpdates = true;
  bool _notifPayments   = true;
  bool _notifMessages   = true;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    final enabled = await DriverNotificationService.instance.hasPermission();
    final prefs   = DriverNotificationPrefsService.instance;
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _notifNewJobs    = prefs.getEnabled(DriverNotificationPrefsService.kNewJobs);
        _notifJobUpdates = prefs.getEnabled(DriverNotificationPrefsService.kJobUpdates);
        _notifPayments   = prefs.getEnabled(DriverNotificationPrefsService.kPayments);
        _notifMessages   = prefs.getEnabled(DriverNotificationPrefsService.kMessages);
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (_notifLoading) return;
    if (value) {
      setState(() => _notifLoading = true);
      final token = await DriverNotificationService.instance.requestPermissionAndGetToken();
      if (!mounted) return;
      final granted = token != null && token.isNotEmpty;
      if (granted) {
        final driver = ref.read(currentDriverProvider);
        if (driver != null) {
          try {
            await ref.read(driverAuthRepositoryProvider).updateProfile(
              name: driver.name,
              fcmToken: token,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications enabled.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save notification token: $e')),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get notification token. Check device notification settings.')),
          );
        }
      }
      if (mounted) setState(() { _notificationsEnabled = granted; _notifLoading = false; });
    } else {
      setState(() => _notifLoading = true);
      final driver = ref.read(currentDriverProvider);
      try {
        if (driver != null) {
          await ref.read(driverAuthRepositoryProvider).updateProfile(
            name: driver.name,
            fcmToken: 'disabled',
          );
        }
        if (mounted) {
          setState(() { _notificationsEnabled = false; _notifLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Push notifications disabled.')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _notifLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to disable notifications: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadBiometrics() async {
    final bio = BiometricService.instance;
    final available = await bio.isAvailable;
    final enabled   = available ? await bio.isEnabled : false;
    if (mounted) setState(() { _biometricsAvailable = available; _biometricsEnabled = enabled; });
  }

  Future<void> _toggleBiometrics(bool value) async {
    // If enabling, require biometric authentication to confirm device ownership
    if (value) {
      try {
        final authenticated = await BiometricService.instance.authenticate();
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication canceled.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          // Keep toggle disabled
          if (mounted) setState(() => _biometricsEnabled = false);
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        // Keep toggle disabled
        if (mounted) setState(() => _biometricsEnabled = false);
        return;
      }
    }
    // Either disabling, or authentication succeeded
    await BiometricService.instance.setEnabled(enabled: value);
    if (mounted) setState(() => _biometricsEnabled = value);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await ref.read(driverAuthRepositoryProvider).logout();
      ref.read(currentDriverProvider.notifier).state = null;
      if (mounted) context.go(AppRoutes.signIn);
    } catch (_) {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            const AppBackButton(),
            const SizedBox(height: 20),
            Text('Settings', style: AppTextStyles.h2),
            const SizedBox(height: 24),

            Text('ACCOUNT', style: AppTextStyles.labelSmall),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              subtitle: driver?.name,
              onTap: () => context.push(AppRoutes.driverProfile),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.directions_car_filled_outlined,
              label: 'Assigned Vehicle',
              onTap: () => context.push(AppRoutes.assignedVehicle),
            ),

            const SizedBox(height: 24),
            Text('PREFERENCES', style: AppTextStyles.labelSmall),
            const SizedBox(height: 8),
            _NotificationTile(
              loading: _notifLoading,
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
            if (_notificationsEnabled) ...[
              const SizedBox(height: 4),
              _NotifSubTile(
                label: 'New Jobs',
                value: _notifNewJobs,
                onChanged: (v) async {
                  setState(() => _notifNewJobs = v);
                  await DriverNotificationPrefsService.instance.setEnabled(DriverNotificationPrefsService.kNewJobs, v);
                },
              ),
              _NotifSubTile(
                label: 'Job Updates',
                value: _notifJobUpdates,
                onChanged: (v) async {
                  setState(() => _notifJobUpdates = v);
                  await DriverNotificationPrefsService.instance.setEnabled(DriverNotificationPrefsService.kJobUpdates, v);
                },
              ),
              _NotifSubTile(
                label: 'Payments',
                value: _notifPayments,
                onChanged: (v) async {
                  setState(() => _notifPayments = v);
                  await DriverNotificationPrefsService.instance.setEnabled(DriverNotificationPrefsService.kPayments, v);
                },
              ),
              _NotifSubTile(
                label: 'Messages',
                value: _notifMessages,
                onChanged: (v) async {
                  setState(() => _notifMessages = v);
                  await DriverNotificationPrefsService.instance.setEnabled(DriverNotificationPrefsService.kMessages, v);
                },
              ),
            ],
            if (_biometricsAvailable) ...[
              const SizedBox(height: 8),
              _BiometricTile(
                value: _biometricsEnabled,
                onChanged: _toggleBiometrics,
              ),
            ],

            const SizedBox(height: 24),
            Text('ABOUT', style: AppTextStyles.labelSmall),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'App Version',
              subtitle: AppConfig.appVersion,
            ),

            const SizedBox(height: 24),
            _SettingsTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Account',
              subtitle: 'Permanently delete your account',
              onTap: () => context.push(AppRoutes.accountDeletion),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loggingOut ? null : _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loggingOut
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                      )
                    : const Text('Log Out'),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.loading, required this.value, required this.onChanged});

  final bool loading;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_none_rounded, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(child: Text('Push Notifications', style: AppTextStyles.h4)),
          if (loading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }
}

class _NotifSubTile extends StatelessWidget {
  const _NotifSubTile({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _BiometricTile extends StatelessWidget {
  const _BiometricTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.fingerprint_rounded, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Biometric Sign-In', style: AppTextStyles.h4),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.h4),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
