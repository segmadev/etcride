import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/maps/maps_service.dart';
import '../../data/models/driver_model.dart';
import '../onboarding/location_permission_screen.dart';
import '../../data/models/job_model.dart';
import '../../services/location_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';

// ── Brand amber ───────────────────────────────────────────────────────────────
const _kAmber = Color(0xFFE2A322);

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT SCREEN — Scaffold with Drawer + 3 tabs
// ─────────────────────────────────────────────────────────────────────────────

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: _kAmber,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    super.dispose();
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawer: _DriverDrawer(scaffoldKey: _scaffoldKey),
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(onMenuTap: _openDrawer),
          const _EarningsTab(),
          const _HistoryTab(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM NAVIGATION  (Home · Earnings · History)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 4,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_outlined,    activeIcon: Icons.home_rounded,
              label: 'Home',     index: 0, current: current, onTap: onTap),
          _NavItem(icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: 'Earnings', index: 1, current: current, onTap: onTap),
          _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded,
              label: 'History',  index: 2, current: current, onTap: onTap),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon, required this.activeIcon, required this.label,
    required this.index, required this.current, required this.onTap,
  });
  final IconData icon, activeIcon;
  final String   label;
  final int      index, current;
  final ValueChanged<int> onTap;

  bool get _selected => current == index;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_selected ? activeIcon : icon, size: 24,
                  color: _selected ? _kAmber : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                    color: _selected ? _kAmber : AppColors.textSecondary,
                    fontWeight: _selected ? FontWeight.w700 : FontWeight.w400,
                  )),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  DRAWER
// ─────────────────────────────────────────────────────────────────────────────

class _DriverDrawer extends ConsumerWidget {
  const _DriverDrawer({required this.scaffoldKey});
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverProvider);
    final unread = ref.watch(driverUnreadNotifCountProvider).valueOrNull ?? 0;

    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              color: _kAmber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  _DriverAvatar(driver: driver, radius: 36),
                  const SizedBox(height: 14),
                  Text('Hello',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 2),
                  Text(driver?.name ?? 'Driver',
                      style: AppTextStyles.h3.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          driver?.kycStatus == 'verified'
                              ? 'Approved Driver'
                              : 'Driver',
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (driver?.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          driver!.rating!.toStringAsFixed(1),
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Nav links ────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      onTap: () => _close(context)),
                  _DrawerTile(
                      icon: Icons.directions_car_outlined,
                      label: 'Assigned Vehicle',
                      onTap: () => _close(context)),
                  _DrawerTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Earnings',
                      onTap: () => _close(context)),
                  _DrawerTile(
                      icon: Icons.history_rounded,
                      label: 'Trip History',
                      onTap: () => _close(context)),
                  _DrawerTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    badge: unread > 0 ? '$unread' : null,
                    onTap: () => _close(context),
                  ),
                  _DrawerTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () => _close(context)),
                  _DrawerTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => _close(context)),
                ],
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AppColors.error, size: 20),
              title: Text('Log Out',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(context).pop(); // close drawer
                await ref.read(driverAuthRepositoryProvider).logout();
                ref.read(currentDriverProvider.notifier).state = null;
                if (!context.mounted) return;
                context.go(AppRoutes.signIn);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _close(BuildContext context) => Navigator.of(context).pop();
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });
  final IconData  icon;
  final String    label;
  final VoidCallback onTap;
  final String?   badge;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 20),
        title: Text(label, style: AppTextStyles.bodyMedium),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              )
            : null,
        onTap: onTap,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER BAR  (hamburger · status capsule · notification bell)
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderBar extends ConsumerWidget {
  const _HeaderBar({
    required this.isOnline,
    required this.toggling,
    required this.onToggle,
    required this.onMenuTap,
    required this.driver,
  });
  final bool          isOnline, toggling;
  final VoidCallback  onToggle, onMenuTap;
  final DriverModel?  driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(driverUnreadNotifCountProvider).valueOrNull ?? 0;
    final top    = MediaQuery.of(context).padding.top;

    return Container(
      color: _kAmber,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 14),
      child: Row(
        children: [
          // Hamburger
          GestureDetector(
            onTap: onMenuTap,
            child: const SizedBox(
              width: 40, height: 40,
              child: Center(
                child: Icon(Icons.menu_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
          ),

          const Spacer(),

          // ── Status capsule ─────────────────────────────────────────────
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile thumbnail
                _DriverAvatar(driver: driver, radius: 15),
                const SizedBox(width: 8),
                // Online / Offline text
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                // Toggle switch
                toggling
                    ? const SizedBox(
                        width: 32, height: 20,
                        child: Center(
                          child: SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kAmber),
                          ),
                        ),
                      )
                    : Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isOnline,
                          onChanged: (_) => onToggle(),
                          activeThumbColor: AppColors.success,
                          activeTrackColor: AppColors.success
                              .withValues(alpha: 0.3),
                          inactiveThumbColor: AppColors.textSecondary,
                          inactiveTrackColor: AppColors.disabled,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
              ],
            ),
          ),

          const Spacer(),

          // Notification bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  width: 40, height: 40,
                  child: Center(
                    child: Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: 6, right: 4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DRIVER AVATAR  (reusable)
// ─────────────────────────────────────────────────────────────────────────────

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.driver, required this.radius});
  final DriverModel? driver;
  final double       radius;

  @override
  Widget build(BuildContext context) {
    final url  = driver?.photo;
    final name = driver?.name ?? '';

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _kAmber.withValues(alpha: 0.2),
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'D',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: _kAmber,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 0 — HOME (state-driven dashboard)
// ═══════════════════════════════════════════════════════════════════════════════

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab({required this.onMenuTap});
  final VoidCallback onMenuTap;

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  bool        _togglingOnline = false;
  Timer?      _jobPollTimer;

  /// Tracks which job IDs have already triggered the "new trip" banner.
  final Set<String> _banneredJobIds = {};
  bool _initialJobsLoaded = false;

  /// Tracks whether we are mid-payment action (for the payment screen).
  bool _processingPayment = false;

  /// True while the auto-arrive dialog is showing (prevents duplicate dialogs).
  bool _autoArrivePending = false;

  /// IDs of jobs the driver was actively working — used to detect
  /// customer-initiated cancellation when the job disappears from active list.
  final Set<String> _trackedActiveJobIds   = {};
  final Set<String> _cancelNotifiedJobIds  = {};

  /// Default threshold in metres matching the backend default for auto_arrive_radius_m.
  static const double _autoArriveDefaultM = 20.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(driverOnlineProvider)) _startTracking();
    });
    LocationService.instance.positionNotifier.addListener(_checkAutoArrive);
  }

  @override
  void dispose() {
    LocationService.instance.positionNotifier.removeListener(_checkAutoArrive);
    _jobPollTimer?.cancel();
    LocationService.instance.stop();
    super.dispose();
  }

  // ── Auto-arrive detection ────────────────────────────────────────────────────

  static double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // metres
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180);
    final dLng = (lng2 - lng1) * (3.141592653589793 / 180);
    final la1  = lat1 * (3.141592653589793 / 180);
    final la2  = lat2 * (3.141592653589793 / 180);
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLng / 2);
    final h  = s1 * s1 + math.cos(la1) * math.cos(la2) * s2 * s2;
    return r * 2 * math.asin(math.sqrt(h));
  }

  void _checkAutoArrive() {
    if (!mounted || _autoArrivePending) return;
    final pos = LocationService.instance.lastPosition;
    if (pos == null) return;

    final jobs = ref.read(driverJobsProvider).valueOrNull;
    if (jobs == null) return;

    JobModel? accepted;
    for (final j in jobs) {
      if (j.status == 'accepted' && j.canArrive) { accepted = j; break; }
    }
    if (accepted == null) return;

    final pLat = accepted.pickupLat;
    final pLng = accepted.pickupLng;
    if (pLat == null || pLng == null) return;

    final effectiveM = _autoArriveDefaultM + pos.accuracy;
    final distM = _haversineMeters(pos.latitude, pos.longitude, pLat, pLng);

    if (distM <= effectiveM) {
      _autoArrivePending = true;
      _showAutoArriveDialog(accepted);
    }
  }

  void _showAutoArriveDialog(JobModel job) {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('You\'ve arrived!',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: const Text(
            'You appear to be at the pickup location. Confirm arrival?',
            style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, arrived'),
          ),
        ],
      ),
    ).then((confirmed) {
      _autoArrivePending = false;
      if (confirmed == true && mounted) {
        final repo = ref.read(driverRepositoryProvider);
        final pos  = LocationService.instance.lastPosition;
        _doJobAction(
          () => repo.arriveAtPickup(
            job.id,
            lat:          pos?.latitude,
            lng:          pos?.longitude,
            gpsAccuracyM: pos?.accuracy,
          ),
          onSuccess: () => _showInfoSnack('Marked as arrived! Waiting for passenger.'),
        );
      }
    });
  }

  // ── Online / offline helpers ────────────────────────────────────────────────

  void _startTracking() {
    LocationService.instance.start(ref.read(driverRepositoryProvider));
    _jobPollTimer?.cancel();
    _jobPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(driverJobsProvider);
    });
  }

  void _stopTracking() {
    LocationService.instance.stop();
    _jobPollTimer?.cancel();
    _jobPollTimer = null;
  }

  /// Returns true if location permission is currently granted, false otherwise.
  /// When denied (but requestable) shows the onboarding screen to explain why
  /// we need it and requests the system dialog from there.
  /// When permanently denied shows the "Open Settings" variant of that screen.
  Future<bool> _ensureLocationPermission() async {
    if (kIsWeb) return true;
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      return true;
    }
    if (!mounted) return false;
    // Both `denied` and `deniedForever` — push the onboarding screen.
    // It handles the difference internally (request vs open settings).
    final granted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LocationPermissionScreen()),
    );
    return granted == true;
  }

  Future<void> _toggleOnline() async {
    final current = ref.read(driverOnlineProvider);

    // Going online requires location permission — show onboarding screen if needed.
    if (!current) {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return; // user declined — stay offline
    }

    setState(() => _togglingOnline = true);
    try {
      await ref.read(driverRepositoryProvider).setAvailability(!current);
      ref.read(driverOnlineProvider.notifier).state = !current;
      final driver = ref.read(currentDriverProvider);
      if (driver != null) {
        final updated = driver.copyWith(isOnline: !current);
        ref.read(currentDriverProvider.notifier).state = updated;
        await ref.read(driverAuthRepositoryProvider).updateCachedDriver(updated);
      }
      if (!current) { _startTracking(); } else { _stopTracking(); }
    } catch (_) {
      // silently revert
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  // ── New-job notification banner ─────────────────────────────────────────────

  void _showNewJobBanner(JobModel job) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _kAmber,
        content: Row(
          children: [
            const Icon(Icons.notification_important_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New Trip Request!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  Text(job.pickupAddress,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Trip complete dialog ─────────────────────────────────────────────────────

  void _showTripSuccessDialog(JobModel job) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TripSuccessDialog(job: job),
    );
  }

  // ── Customer-cancelled notification ─────────────────────────────────────────

  void _showCancelledByCustomerDialog(JobModel job) {
    if (!mounted) return;
    final who = job.cancelledByRole == 'admin' ? 'Admin' : 'Customer';
    final reason = (job.cancellationReason ?? '').trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Trip Cancelled',
                style: AppTextStyles.h4.copyWith(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$who has cancelled this trip.',
                style: AppTextStyles.bodyMedium),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('"$reason"',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAmber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Driver-initiated cancel with reason picker ───────────────────────────────

  Future<void> _showDriverCancelSheet(JobModel job) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancelReasonSheet(
        title: 'Cancel Trip',
        subtitle: 'Please tell us why you\'re cancelling.',
        reasons: const [
          'Customer not showing up',
          'Customer is unresponsive',
          'Unsafe situation',
          'Vehicle breakdown',
          'Wrong pickup location provided',
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _doJobAction(
      () => ref.read(driverRepositoryProvider).cancelJob(job.id, reason: reason),
      onSuccess: () => _showInfoSnack('Trip cancelled.'),
    );
  }

  // ── Job action helpers ───────────────────────────────────────────────────────

  Future<void> _doJobAction(Future<void> Function() action,
      {VoidCallback? onSuccess}) async {
    try {
      await action();
      ref.invalidate(driverJobsProvider);
      onSuccess?.call();
    } on ApiException catch (e) {
      if (mounted) _showErrorSnack(e.message);
    } catch (e) {
      // Surface unexpected errors (network timeout, parse failure, etc.)
      if (mounted) _showErrorSnack('Something went wrong. Please try again.');
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final driver    = ref.watch(currentDriverProvider);
    final isOnline  = ref.watch(driverOnlineProvider);
    final jobsAsync = ref.watch(driverJobsProvider);

    // ── Job-list change listener ───────────────────────────────────────────
    ref.listen<AsyncValue<List<JobModel>>>(driverJobsProvider, (_, next) {
      final jobs = next.valueOrNull;
      if (jobs == null) return;

      if (!_initialJobsLoaded) {
        _initialJobsLoaded = true;
        for (final j in jobs) {
          _banneredJobIds.add(j.id);
          if (j.isActive) _trackedActiveJobIds.add(j.id);
        }
        return;
      }

      for (final j in jobs) {
        // New incoming assignment — show banner
        if (j.status == 'assigned' && !_banneredJobIds.contains(j.id)) {
          _banneredJobIds.add(j.id);
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showNewJobBanner(j));
          break;
        }

        // Job was active before and is now cancelled by customer or admin
        if (j.isCancelled &&
            _trackedActiveJobIds.contains(j.id) &&
            !_cancelNotifiedJobIds.contains(j.id) &&
            j.cancelledByRole != 'driver') {
          _cancelNotifiedJobIds.add(j.id);
          _trackedActiveJobIds.remove(j.id);
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showCancelledByCustomerDialog(j));
        }

        // Track newly active jobs
        if (j.isActive) _trackedActiveJobIds.add(j.id);
      }
    });

    // Pick most-urgent active job
    final activeJob = jobsAsync.valueOrNull
        ?.where((j) => j.isActive)
        .fold<JobModel?>(null, (best, j) {
      if (best == null) return j;
      const order = [
        'in_progress', 'arrived', 'accepted', 'payment_pending', 'assigned'
      ];
      final bi = order.indexOf(best.status);
      final ji = order.indexOf(j.status);
      return (ji < bi) ? j : best;
    });

    return Column(
      children: [
        _HeaderBar(
          isOnline:  isOnline,
          toggling:  _togglingOnline,
          onToggle:  _toggleOnline,
          onMenuTap: widget.onMenuTap,
          driver:    driver,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildBody(
              context: context,
              driver: driver,
              job: activeJob,
              jobsLoading: jobsAsync.isLoading,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required DriverModel? driver,
    required JobModel?    job,
    required bool         jobsLoading,
  }) {
    final repo = ref.read(driverRepositoryProvider);

    // ── Payment pending ────────────────────────────────────────────────────
    if (job != null && job.status == 'payment_pending') {
      return _PaymentView(
        key: ValueKey('payment_${job.id}'),
        job: job,
        processing: _processingPayment,
        onConfirm: () async {
          setState(() => _processingPayment = true);
          await _doJobAction(
            () => repo.confirmPayment(job.id),
            onSuccess: () {
              setState(() => _processingPayment = false);
              Future.delayed(const Duration(milliseconds: 400), () {
                _showTripSuccessDialog(job);
              });
            },
          );
          if (mounted) setState(() => _processingPayment = false);
        },
      );
    }

    // ── Active trip (accepted / arrived / in_progress) ─────────────────────
    if (job != null &&
        ['accepted', 'arrived', 'in_progress'].contains(job.status)) {
      // Calculate driver → pickup distance for proximity gating
      final driverPos  = LocationService.instance.lastPosition;
      final pickupLat  = job.pickupLat;
      final pickupLng  = job.pickupLng;
      double? distToPickupM;
      if (driverPos != null && pickupLat != null && pickupLng != null) {
        distToPickupM = _haversineMeters(
            driverPos.latitude, driverPos.longitude, pickupLat, pickupLng);
      }
      final effectiveThresholdM =
          _autoArriveDefaultM + (driverPos?.accuracy ?? 0);
      final nearPickup = distToPickupM != null && distToPickupM <= effectiveThresholdM;

      return _ActiveTripView(
        key: ValueKey('active_${job.id}'),
        job:          job,
        nearPickup:   job.status == 'accepted' ? nearPickup : true,
        distToPickupM: distToPickupM,
        onArrive: job.canArrive
            ? () => _doJobAction(
                () {
                  final pos = LocationService.instance.lastPosition;
                  return repo.arriveAtPickup(
                    job.id,
                    lat:          pos?.latitude,
                    lng:          pos?.longitude,
                    gpsAccuracyM: pos?.accuracy,
                  );
                },
                onSuccess: () => _showInfoSnack(
                    'Marked as arrived! Waiting for passenger.'))
            : null,
        onStart: job.canStart
            ? () => _doJobAction(
                () => repo.startTrip(job.id),
                onSuccess: () => _showInfoSnack(
                    'Passenger on board. You can now start the trip.'))
            : null,
        onComplete: job.canComplete
            ? () => _doJobAction(() => repo.completeTrip(job.id))
            : null,
        // Cancel only allowed before trip starts (accepted / arrived)
        onCancel: (job.status == 'accepted' || job.status == 'arrived')
            ? () => _showDriverCancelSheet(job)
            : null,
        onCallPassenger: () => _callPhone(job.passengerPhone),
        onChatPassenger: () => context.push(AppRoutes.chat, extra: job),
      );
    }

    // ── Incoming request ───────────────────────────────────────────────────
    if (job != null && job.status == 'assigned') {
      return _DashboardScroll(
        key: ValueKey('incoming_${job.id}'),
        driver: driver,
        child: _IncomingRequestCard(
          job: job,
          onAccept: () => _doJobAction(
              () => repo.acceptJob(job.id),
              onSuccess: () =>
                  _showInfoSnack('Trip accepted! Head to the pickup point.')),
          onDecline: () => _doJobAction(() => repo.rejectJob(job.id)),
        ),
      );
    }

    // ── Idle ───────────────────────────────────────────────────────────────
    return _DashboardScroll(
      key: const ValueKey('idle'),
      driver: driver,
      child: _IdleStatusCard(jobsLoading: jobsLoading),
    );
  }

  void _showInfoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DASHBOARD SCROLL WRAPPER  (used for idle + incoming states)
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardScroll extends ConsumerWidget {
  const _DashboardScroll({
    super.key,
    required this.driver,
    required this.child,
  });
  final DriverModel? driver;
  final Widget       child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: _kAmber,
      onRefresh: () async {
        ref.invalidate(driverJobsProvider);
        ref.invalidate(driverHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          _TodayEarningsCard(driver: driver),
          const SizedBox(height: 12),
          const _LocationStatusCard(),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOCATION STATUS CARD
//  Shows the driver's current GPS position (reverse-geocoded address) in
//  real-time with a reload button.  Listens to LocationService.positionNotifier
//  so it refreshes automatically on every 30-second ping.
//  Geocoding is only triggered on (a) first load with a known position, and
//  (b) manual reload — to avoid hammering the API on every ping.
// ─────────────────────────────────────────────────────────────────────────────

class _LocationStatusCard extends StatefulWidget {
  const _LocationStatusCard();

  @override
  State<_LocationStatusCard> createState() => _LocationStatusCardState();
}

// Tracks what the card is currently showing so the UI renders the right state.
enum _LocState { loading, denied, serviceOff, unavailable, ok }

class _LocationStatusCardState extends State<_LocationStatusCard> {
  static const _tag = '[LocCard]';

  String?   _address;
  String?   _coords;
  DateTime? _updatedAt;
  bool      _geocoding  = false;
  int       _geocodeSeq = 0;
  _LocState _state      = _LocState.loading;

  @override
  void initState() {
    super.initState();
    debugPrint('$_tag initState()');
    LocationService.instance.positionNotifier.addListener(_onPositionUpdate);

    final last = LocationService.instance.lastPosition;
    debugPrint('$_tag initState: lastPosition=${last == null ? "null" : "${last.latitude}, ${last.longitude}"}');
    if (last != null) {
      _updateCoords(last);
      _geocodeAddress(last);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('$_tag postFrameCallback firing — calling _reload(auto: true)');
        if (mounted) _reload(auto: true);
      });
    }
  }

  @override
  void dispose() {
    debugPrint('$_tag dispose()');
    LocationService.instance.positionNotifier.removeListener(_onPositionUpdate);
    super.dispose();
  }

  // ── Listener ────────────────────────────────────────────────────────────────

  void _onPositionUpdate() {
    final pos = LocationService.instance.positionNotifier.value;
    debugPrint('$_tag _onPositionUpdate: pos=${pos == null ? "null" : "${pos.latitude}, ${pos.longitude}"}');
    if (pos == null) return;
    _updateCoords(pos);
  }

  void _updateCoords(Position position) {
    debugPrint('$_tag _updateCoords: ${position.latitude}, ${position.longitude}  acc=${position.accuracy}m');
    if (!mounted) { debugPrint('$_tag _updateCoords: not mounted, skipping'); return; }
    setState(() {
      _state     = _LocState.ok;
      _coords    = '${position.latitude.toStringAsFixed(5)}, '
                   '${position.longitude.toStringAsFixed(5)}';
      _updatedAt = DateTime.now();
    });
    debugPrint('$_tag _updateCoords: state → ok, coords=$_coords');
  }

  // ── Reverse geocoding ───────────────────────────────────────────────────────

  Future<void> _geocodeAddress(Position position) async {
    final seq = ++_geocodeSeq;
    debugPrint('$_tag _geocodeAddress seq=$seq: ${position.latitude}, ${position.longitude}');
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final addr = await MapsService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      debugPrint('$_tag _geocodeAddress seq=$seq result: ${addr ?? "(null — will fall back to coords)"}');
      if (!mounted || seq != _geocodeSeq) {
        debugPrint('$_tag _geocodeAddress seq=$seq: stale (current=$_geocodeSeq) or unmounted, discarding');
        return;
      }
      setState(() { _address = addr; _geocoding = false; });
    } catch (e, st) {
      debugPrint('$_tag _geocodeAddress seq=$seq threw: $e\n$st');
      if (mounted && seq == _geocodeSeq) setState(() => _geocoding = false);
    }
  }

  // ── Reload ──────────────────────────────────────────────────────────────────

  Future<void> _reload({bool auto = false}) async {
    debugPrint('$_tag _reload(auto=$auto) START — state=$_state  kIsWeb=$kIsWeb');

    // ── 1. GPS hardware on? (native only — browser always "on") ─────────────
    if (!kIsWeb) {
      final svcOn = await Geolocator.isLocationServiceEnabled();
      debugPrint('$_tag _reload: locationServiceEnabled=$svcOn');
      if (!svcOn) {
        if (mounted) setState(() { _state = _LocState.serviceOff; _geocoding = false; });
        debugPrint('$_tag _reload: GPS service OFF → serviceOff state');
        return;
      }
    }

    // ── 2. Permission ────────────────────────────────────────────────────────
    final perm = await Geolocator.checkPermission();
    debugPrint('$_tag _reload: checkPermission=$perm');

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (auto) {
        // On first load: don't interrupt the user — just show the hint.
        // Web browsers will show their own native permission prompt when we call
        // requestPermission(), so we can do that directly on first load for web.
        if (kIsWeb) {
          // Web: request the browser dialog immediately (no custom screen needed)
          debugPrint('$_tag _reload(auto, web): calling requestPermission() for browser dialog');
          final newPerm = await Geolocator.requestPermission();
          debugPrint('$_tag _reload(auto, web): after requestPermission=$newPerm');
          if (newPerm == LocationPermission.denied ||
              newPerm == LocationPermission.deniedForever) {
            if (mounted) setState(() { _state = _LocState.denied; _geocoding = false; });
            return;
          }
          // Granted — fall through to fetch
        } else {
          // Native: don't push a screen on auto-load, just show the card hint
          if (mounted) setState(() { _state = _LocState.denied; _geocoding = false; });
          debugPrint('$_tag _reload(auto, native): permission $perm → denied state, waiting for user tap');
          return;
        }
      } else {
        // Manual tap: show the full permission screen on native; request directly on web
        if (kIsWeb) {
          debugPrint('$_tag _reload(manual, web): calling requestPermission()');
          final newPerm = await Geolocator.requestPermission();
          debugPrint('$_tag _reload(manual, web): result=$newPerm');
          if (newPerm == LocationPermission.denied ||
              newPerm == LocationPermission.deniedForever) {
            if (mounted) setState(() { _state = _LocState.denied; _geocoding = false; });
            return;
          }
        } else {
          debugPrint('$_tag _reload(manual, native): pushing LocationPermissionScreen');
          if (!mounted) return;
          final granted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const LocationPermissionScreen()),
          );
          debugPrint('$_tag _reload(manual, native): screen returned granted=$granted');
          if (granted != true) {
            if (mounted) setState(() { _state = _LocState.denied; _geocoding = false; });
            return;
          }
        }
      }
    }

    // ── 3. Fetch ─────────────────────────────────────────────────────────────
    debugPrint('$_tag _reload: permission OK — fetching position');
    if (mounted) setState(() { _state = _LocState.loading; _geocoding = true; });

    await LocationService.instance.refreshPosition();
    debugPrint('$_tag _reload: refreshPosition() returned');

    if (!mounted) { debugPrint('$_tag _reload: not mounted after refresh'); return; }

    final pos = LocationService.instance.lastPosition;
    debugPrint('$_tag _reload: lastPosition = ${pos == null ? "NULL" : "${pos.latitude}, ${pos.longitude}"}');

    if (pos != null) {
      _updateCoords(pos);
      await _geocodeAddress(pos);
    } else {
      debugPrint('$_tag _reload: no position obtained → unavailable state');
      setState(() { _state = _LocState.unavailable; _geocoding = false; });
    }
    debugPrint('$_tag _reload(auto=$auto) END — final state=$_state');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _fmtAge(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes  < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isError = _state == _LocState.denied    ||
                         _state == _LocState.serviceOff ||
                         _state == _LocState.unavailable;
    final bool isFetching = _state == _LocState.loading && _coords == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Pin icon ─────────────────────────────────────────────────────
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isError ? AppColors.warningLight : const Color(0xFFFFF3CD),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isError ? Icons.location_off_rounded : Icons.my_location_rounded,
                size: 18,
                color: _kAmber,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Text area ────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Location',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),

                // ── Main line: error hint, fetching, or address ─────────
                if (isError)
                  Text(
                    switch (_state) {
                      _LocState.serviceOff  => 'GPS is turned off — enable it in device settings',
                      _LocState.denied      => 'Location permission needed — tap ↻ to allow',
                      _LocState.unavailable => 'Couldn\'t get a GPS fix — tap ↻ to retry',
                      _                    => '',
                    },
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (isFetching)
                  Text(
                    'Fetching location…',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else ...[
                  // Address (primary) — shows "Looking up address…" while geocoding
                  if (_geocoding && _address == null)
                    Row(
                      children: [
                        const SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: _kAmber),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Looking up address…',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _address ?? _coords ?? '',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Coordinates (secondary) — always shown below the address
                  if (_coords != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _coords!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  // Timestamp
                  if (_updatedAt != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      _fmtAge(_updatedAt!),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(width: 4),

          // ── Reload button / spinner ──────────────────────────────────────
          SizedBox(
            width: 36, height: 36,
            child: (isFetching)
                ? const Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kAmber),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: _kAmber, size: 20),
                    onPressed: _reload,
                    tooltip: 'Refresh location',
                    padding: EdgeInsets.zero,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TODAY EARNINGS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TodayEarningsCard extends ConsumerWidget {
  const _TodayEarningsCard({required this.driver});
  final DriverModel? driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(driverHistoryProvider).valueOrNull ?? [];
    final now  = DateTime.now();
    final todayJobs = jobs.where((j) {
      if (!j.isCompleted || j.completedAt == null) return false;
      final d = DateTime.tryParse(j.completedAt!);
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    final todayEarnings =
        todayJobs.fold<double>(0, (s, j) => s + j.displayFare);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kAmber,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today Earnings',
              style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text(
            '₦${todayEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.directions_car_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Text('${todayJobs.length} Trip${todayJobs.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 20),
              const Icon(Icons.star_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                driver?.rating != null
                    ? driver!.rating!.toStringAsFixed(1)
                    : 'N/A',
                style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  IDLE STATUS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _IdleStatusCard extends StatelessWidget {
  const _IdleStatusCard({required this.jobsLoading});
  final bool jobsLoading;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text('Current Status',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
            const SizedBox(height: 20),
            SvgPicture.asset(
              'assets/icons/no-trip.svg',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 20),
            Text(
              'No trips assigned yet',
              style: AppTextStyles.h4
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay online to receive job requests from riders.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                  height: 1.5,
                  color: AppColors.textSecondary),
            ),
            if (jobsLoading) ...[
              const SizedBox(height: 16),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kAmber),
              ),
            ],
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  INCOMING RIDE REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _IncomingRequestCard extends StatefulWidget {
  const _IncomingRequestCard({
    required this.job,
    required this.onAccept,
    required this.onDecline,
  });
  final JobModel                 job;
  final Future<void> Function()  onAccept, onDecline;

  @override
  State<_IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<_IncomingRequestCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action(); // spinner stays until API returns
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('INCOMING RIDE REQUEST',
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
                const Spacer(),
                Text(
                  '₦${job.estimatedFare.toStringAsFixed(0)}',
                  style: AppTextStyles.h4.copyWith(
                      color: _kAmber,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route
                _RouteRow(
                  icon: Icons.radio_button_on,
                  iconColor: AppColors.success,
                  label: 'Pickup',
                  address: job.pickupAddress,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 9, top: 2, bottom: 2),
                  child: Column(
                    children: List.generate(
                        3,
                        (_) => Container(
                              width: 1,
                              height: 5,
                              color: AppColors.divider,
                              margin:
                                  const EdgeInsets.symmetric(vertical: 1),
                            )),
                  ),
                ),
                _RouteRow(
                  icon: Icons.location_on,
                  iconColor: AppColors.error,
                  label: 'Destination',
                  address: job.destinationAddress,
                ),

                // Meta info row
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (job.distanceKm != null) ...[
                      _MetaChip(
                          icon: Icons.straighten_rounded,
                          value:
                              '${job.distanceKm!.toStringAsFixed(1)} km'),
                      const SizedBox(width: 10),
                    ],
                    _MetaChip(
                        icon: Icons.directions_car_outlined,
                        value: job.bookingType.toUpperCase()),
                    if (job.stops.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      _MetaChip(
                          icon: Icons.pin_drop_outlined,
                          value: '+${job.stops.length} stop'),
                    ],
                  ],
                ),

                if (job.passengerName != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 15,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(job.passengerName!,
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'DECLINE',
                        variant: AppButtonVariant.ghost,
                        loading: _busy,
                        height: 48,
                        fontSize: 13,
                        onPressed: _busy
                            ? null
                            : () => _run(widget.onDecline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'ACCEPT TRIP',
                        variant: AppButtonVariant.primary,
                        loading: _busy,
                        height: 48,
                        fontSize: 13,
                        onPressed: _busy
                            ? null
                            : () => _run(widget.onAccept),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.value});
  final IconData icon;
  final String   value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _kAmber),
            const SizedBox(width: 4),
            Text(value,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTIVE TRIP VIEW  (map placeholder + bottom panel)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveTripView extends StatelessWidget {
  const _ActiveTripView({
    super.key,
    required this.job,
    required this.nearPickup,
    this.distToPickupM,
    this.onArrive,
    this.onStart,
    this.onComplete,
    this.onCancel,
    required this.onCallPassenger,
    required this.onChatPassenger,
  });
  final JobModel                  job;
  final bool                      nearPickup;
  final double?                   distToPickupM;
  final Future<void> Function()?  onArrive, onStart, onComplete;
  final VoidCallback?             onCancel;
  final VoidCallback               onCallPassenger, onChatPassenger;

  int get _progressStep {
    switch (job.status) {
      case 'accepted':    return 0;
      case 'arrived':     return 1;
      case 'in_progress': return 2;
      default:            return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Live map ──────────────────────────────────────────────────────
        Expanded(child: _TripMapView(job: job)),

        // ── Bottom trip panel ──────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.disabled,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip ID + status pill
                    Row(
                      children: [
                        Text(
                          '#${job.bookingRef.isNotEmpty ? job.bookingRef : job.id.substring(0, 8).toUpperCase()}',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 10),
                        _StatusPill(status: job.status),
                        const Spacer(),
                        if (job.distanceKm != null)
                          Text(
                            '${job.distanceKm!.toStringAsFixed(1)} km',
                            style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Progress tracker
                    _TripProgressTracker(step: _progressStep),

                    const SizedBox(height: 16),

                    // Customer row
                    Row(
                      children: [
                        const _DriverAvatar(driver: null, radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.passengerName ?? 'Passenger',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700),
                              ),
                              if (job.passengerPhone != null)
                                Text(job.passengerPhone!,
                                    style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        // Call button
                        _CircleAction(
                          icon: Icons.call_rounded,
                          color: AppColors.success,
                          onTap: onCallPassenger,
                          tooltip: 'Call passenger',
                        ),
                        const SizedBox(width: 10),
                        // Chat button
                        _CircleAction(
                          icon: Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary,
                          onTap: onChatPassenger,
                          tooltip: 'Chat with passenger',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Pickup / Destination
                    _RouteRow(
                        icon: Icons.radio_button_on,
                        iconColor: AppColors.success,
                        label: 'Pickup',
                        address: job.pickupAddress),
                    const SizedBox(height: 8),
                    _RouteRow(
                        icon: Icons.location_on,
                        iconColor: AppColors.error,
                        label: 'Destination',
                        address: job.destinationAddress),

                    const SizedBox(height: 18),

                    // Primary action button
                    _TripActionButton(
                      job:          job,
                      nearPickup:   nearPickup,
                      distToPickupM: distToPickupM,
                      onArrive:     onArrive,
                      onStart:      onStart,
                      onComplete:   onComplete,
                    ),

                    // Cancel button — only for accepted / arrived
                    if (onCancel != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                          ),
                          child: const Text(
                            'Cancel Trip',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],

                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Progress tracker ──────────────────────────────────────────────────────────

class _TripProgressTracker extends StatelessWidget {
  const _TripProgressTracker({required this.step});
  /// 0 = Going to pickup, 1 = Picked up, 2 = On the way
  final int step;

  static const _labels = ['Going to pickup', 'Picked up', 'On the way'];

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(3, (i) {
          final done   = i < step;
          final active = i == step;
          return Expanded(
            child: Row(
              children: [
                // Connector line before (except first)
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done || active
                          ? _kAmber
                          : AppColors.divider,
                    ),
                  ),

                // Step node
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done || active ? _kAmber : AppColors.surface,
                        border: Border.all(
                          color: done || active
                              ? _kAmber
                              : AppColors.divider,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white)
                            : active
                                ? Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9,
                        fontWeight: active || done
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: active || done
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                // Connector line after (except last)
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color:
                          done ? _kAmber : AppColors.divider,
                    ),
                  ),
              ],
            ),
          );
        }),
      );
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'assigned'        => ('Assigned',       AppColors.warningLight, AppColors.warning),
      'accepted'        => ('Heading to you', AppColors.primaryLight,  _kAmber),
      'arrived'         => ('Arrived',        AppColors.successLight, AppColors.success),
      'in_progress'     => ('Trip In Progress', AppColors.primaryLight, _kAmber),
      'payment_pending' => ('Awaiting Payment', AppColors.warningLight, AppColors.warning),
      _                 => (status,           AppColors.surface,      AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg)),
    );
  }
}

// ── Circle action button ──────────────────────────────────────────────────────

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final String       tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      );
}

// ── Trip action button ────────────────────────────────────────────────────────

class _TripActionButton extends StatefulWidget {
  const _TripActionButton({
    required this.job,
    required this.nearPickup,
    this.distToPickupM,
    this.onArrive,
    this.onStart,
    this.onComplete,
  });
  final JobModel                  job;
  final bool                      nearPickup;
  final double?                   distToPickupM;
  final Future<void> Function()? onArrive, onStart, onComplete;

  @override
  State<_TripActionButton> createState() => _TripActionButtonState();
}

class _TripActionButtonState extends State<_TripActionButton> {
  bool   _busy = false;
  Timer? _waitTimer;
  int    _waitElapsedSecs = 0;

  @override
  void initState() {
    super.initState();
    _syncWaitTimer(widget.job);
  }

  @override
  void didUpdateWidget(_TripActionButton old) {
    super.didUpdateWidget(old);
    if (widget.job.status != old.job.status ||
        widget.job.arrivedAt != old.job.arrivedAt) {
      _syncWaitTimer(widget.job);
    }
  }

  void _syncWaitTimer(JobModel job) {
    if (job.status == 'arrived') {
      final arrivedAt = job.arrivedAt;
      if (_waitTimer == null) {
        // First call: seed the counter from server time
        if (arrivedAt != null) {
          try {
            final t = DateTime.parse(arrivedAt).toLocal();
            _waitElapsedSecs = DateTime.now().difference(t).inSeconds.clamp(0, 86400);
          } catch (_) {}
        }
        _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _waitElapsedSecs++);
        });
      } else if (arrivedAt != null) {
        // Subsequent calls: drift-correct only if off by more than 2 s
        try {
          final t = DateTime.parse(arrivedAt).toLocal();
          final serverElapsed = DateTime.now().difference(t).inSeconds.clamp(0, 86400);
          if ((serverElapsed - _waitElapsedSecs).abs() > 2 && mounted) {
            setState(() => _waitElapsedSecs = serverElapsed);
          }
        } catch (_) {}
      }
    } else {
      _waitTimer?.cancel();
      _waitTimer = null;
      _waitElapsedSecs = 0;
    }
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null) return;
    setState(() => _busy = true);
    try {
      await action(); // properly awaited — spinner stays until API returns
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final (label, action) = switch (widget.job.status) {
      'accepted'    => ('ARRIVED AT PICKUP', widget.onArrive),
      'arrived'     => ('PASSENGER PICKED UP', widget.onStart),
      'in_progress' => ('COMPLETE TRIP', widget.onComplete),
      _             => ('', null),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    // For 'accepted' status, gate the arrive button on proximity
    final isArriveBtn = widget.job.status == 'accepted';
    final canPress    = !isArriveBtn || widget.nearPickup;
    final dist        = widget.distToPickupM;

    // Waiting timer (visible when status == 'arrived')
    final isArrived        = widget.job.status == 'arrived';
    final freeWaitSecs     = widget.job.freeWaitingMinutes * 60;
    final remaining        = (freeWaitSecs - _waitElapsedSecs).clamp(0, freeWaitSecs);
    final overFreeTime     = _waitElapsedSecs > freeWaitSecs;
    final overSecs         = overFreeTime ? (_waitElapsedSecs - freeWaitSecs) : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Waiting timer row (status == arrived) ─────────────────────────
        if (isArrived) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: overFreeTime
                  ? const Color(0xFFFBE9E7)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  overFreeTime ? Icons.timer_off_rounded : Icons.timer_rounded,
                  size: 16,
                  color: overFreeTime
                      ? const Color(0xFFD84315)
                      : AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  overFreeTime
                      ? 'Customer waiting: ${_fmt(overSecs)} over free time'
                      : 'Free waiting: ${_fmt(remaining)} remaining',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: overFreeTime
                        ? const Color(0xFFD84315)
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Proximity hint (only when driver hasn't reached pickup yet)
        if (isArriveBtn && !widget.nearPickup && dist != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${dist.round()} m from pickup — get closer to enable',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

        AppButton(
          label: label,
          variant: AppButtonVariant.primary,
          loading: _busy,
          height: 52,
          fontSize: 14,
          onPressed: canPress && action != null ? () => _run(action) : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LIVE TRIP MAP
//  Displays pickup (green) + destination (red) markers, an animated driver
//  pin (azure, flat, rotated toward heading), and the decoded route polyline.
//  Falls back to a straight-line polyline when route_polyline is absent.
// ─────────────────────────────────────────────────────────────────────────────

class _TripMapView extends StatefulWidget {
  const _TripMapView({required this.job});
  final JobModel job;

  @override
  State<_TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<_TripMapView> {
  GoogleMapController? _ctrl;
  int _camVersion = 0;

  // Cached JS-loader future — never recreated so FutureBuilder never blinks
  Future<bool>? _loadFuture;

  // Decoded route
  List<LatLng> _routePts = [];
  LatLngBounds? _bounds;

  // Driver live position + heading
  LatLng? _driverPos;
  double  _driverBearing = 0;
  StreamSubscription<Position>? _posSub;
  Timer?  _animTimer;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _loadFuture = ensureGoogleMapsJsLoaded(apiKey: AppConfig.googleMapsKey);
    _initDriverPos();
    _buildRoute(widget.job);
    if (!kIsWeb) _startPosStream();
  }

  @override
  void didUpdateWidget(_TripMapView old) {
    super.didUpdateWidget(old);
    // Rebuild only when route-relevant fields change; status change alone is fine
    final changed = widget.job.id              != old.job.id              ||
                    widget.job.routePolyline   != old.job.routePolyline   ||
                    widget.job.pickupLat       != old.job.pickupLat       ||
                    widget.job.destinationLat  != old.job.destinationLat;
    if (changed) { _buildRoute(widget.job); }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _animTimer?.cancel();
    _ctrl?.dispose();
    _ctrl = null; // prevent use-after-dispose in pending Future.delayed callbacks
    super.dispose();
  }

  // ── Driver position ─────────────────────────────────────────────────────────

  void _initDriverPos() {
    final last = LocationService.instance.lastPosition;
    if (last != null) _driverPos = LatLng(last.latitude, last.longitude);
  }

  void _startPosStream() {
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 m of movement
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  void _onPosition(Position pos) {
    final to = LatLng(pos.latitude, pos.longitude);
    if (_driverPos != null) {
      _driverBearing = _bearingDeg(_driverPos!, to);
    }
    _animateTo(to);
  }

  void _animateTo(LatLng target) {
    _animTimer?.cancel();
    final from = _driverPos ?? target;
    int step = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) { t.cancel(); return; }
      step++;
      final frac = (step / 20).clamp(0.0, 1.0);
      setState(() {
        _driverPos = LatLng(
          from.latitude  + (target.latitude  - from.latitude)  * frac,
          from.longitude + (target.longitude - from.longitude) * frac,
        );
      });
      if (step >= 20) t.cancel();
    });
  }

  static double _bearingDeg(LatLng from, LatLng to) {
    final lat1 = from.latitude  * math.pi / 180;
    final lat2 = to.latitude    * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
               math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ── Route ───────────────────────────────────────────────────────────────────

  void _buildRoute(JobModel job) {
    final pLat = job.pickupLat, pLng = job.pickupLng;
    final dLat = job.destinationLat, dLng = job.destinationLng;
    if (pLat == null || dLat == null) return;

    final pickup = LatLng(pLat, pLng!);
    final dest   = LatLng(dLat, dLng!);

    final List<LatLng> pts = (job.routePolyline?.isNotEmpty == true)
        ? MapsService.decodePolylineBest(job.routePolyline!,
              origin: pickup, destination: dest)
        : [pickup, dest];

    final allPts = <LatLng>[...pts, if (_driverPos != null) _driverPos!];
    final bounds = MapsService.boundsFromPoints(allPts);

    setState(() {
      _routePts = pts;
      _bounds   = bounds;
    });

    if (_ctrl != null) _fitCamera();
  }

  void _fitCamera() {
    if (!mounted || _ctrl == null || _bounds == null) return;
    final v  = ++_camVersion;
    final sw = _bounds!.southwest;
    final ne = _bounds!.northeast;
    // Skip if points are too close together (prevents over-zooming)
    if ((ne.latitude  - sw.latitude).abs()  < 0.0002 &&
        (ne.longitude - sw.longitude).abs() < 0.0002) { return; }
    try {
      _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 72))
          .then((_) { if (v != _camVersion) return; });
    } catch (_) { _ctrl = null; }
  }

  // ── Map data ────────────────────────────────────────────────────────────────

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final j = widget.job;

    if (j.pickupLat != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(j.pickupLat!, j.pickupLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: j.pickupAddress),
      ));
    }

    if (j.destinationLat != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(j.destinationLat!, j.destinationLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: j.destinationAddress),
      ));
    }

    // Animated driver pin (flat, rotated toward heading)
    if (_driverPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: _driverBearing,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      ));
    }

    return markers;
  }

  Set<Polyline> get _polylines {
    final lines = <Polyline>{};
    final j = widget.job;

    // ── Full route (pickup → destination) ────────────────────────────────────
    if (_routePts.length >= 2) {
      lines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _routePts,
        color: _kAmber,
        width: 5,
        startCap: Cap.roundCap,
        endCap:   Cap.roundCap,
      ));
    }

    // ── Approach line (driver current pos → pickup) ───────────────────────────
    // Shown when driver accepted but hasn't started the trip yet (status:
    // 'accepted' or 'arrived'). A dashed amber line so it's visually distinct.
    final dPos = _driverPos;
    final pLat = j.pickupLat, pLng = j.pickupLng;
    final isApproaching = j.status == 'accepted' || j.status == 'arrived';
    if (dPos != null && pLat != null && pLng != null && isApproaching) {
      final pickup = LatLng(pLat, pLng);
      lines.add(Polyline(
        polylineId: const PolylineId('approach'),
        points:     [dPos, pickup],
        color:      _kAmber.withValues(alpha: 0.75),
        width:      3,
        patterns:   [PatternItem.dot, PatternItem.gap(8)],
        startCap:   Cap.roundCap,
        endCap:     Cap.roundCap,
      ));
    }

    return lines;
  }

  LatLng get _initialTarget {
    if (_bounds != null) {
      final sw = _bounds!.southwest;
      final ne = _bounds!.northeast;
      return LatLng((sw.latitude + ne.latitude) / 2,
                    (sw.longitude + ne.longitude) / 2);
    }
    if (widget.job.pickupLat != null) {
      return LatLng(widget.job.pickupLat!, widget.job.pickupLng!);
    }
    if (_driverPos != null) return _driverPos!;
    return const LatLng(6.5244, 3.3792); // Lagos fallback
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final map = GoogleMap(
      initialCameraPosition: CameraPosition(target: _initialTarget, zoom: 13),
      markers:   _markers,
      polylines: _polylines,
      myLocationEnabled:       false, // using animated driver marker instead
      myLocationButtonEnabled: false,
      zoomControlsEnabled:     false,
      mapToolbarEnabled:       false,
      compassEnabled:          true,
      onMapCreated: (ctrl) {
        _ctrl = ctrl;
        Future.delayed(const Duration(milliseconds: 300), _fitCamera);
      },
    );

    if (!kIsWeb) return map;

    return FutureBuilder<bool>(
      future: _loadFuture, // cached in initState — never causes a blink
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data != true) {
          return Container(
            color: AppColors.surface,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return map;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAYMENT VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentView extends StatelessWidget {
  const _PaymentView({
    super.key,
    required this.job,
    required this.processing,
    required this.onConfirm,
  });
  final JobModel      job;
  final bool          processing;
  final VoidCallback  onConfirm;

  @override
  Widget build(BuildContext context) {
    final method = job.paymentMethod ?? 'cash';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Fare card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kAmber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('Collect Payment',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 10),
                Text(
                  '₦${job.displayFare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        method == 'cash'
                            ? Icons.payments_outlined
                            : Icons.credit_card_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        method.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Trip summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Passenger',
                  value: job.passengerName ?? 'Passenger',
                ),
                const Divider(height: 20),
                _SummaryRow(
                  label: 'Booking Ref',
                  value: job.bookingRef.isNotEmpty
                      ? '#${job.bookingRef}'
                      : '#${job.id.substring(0, 8).toUpperCase()}',
                ),
                if (job.distanceKm != null) ...[
                  const Divider(height: 20),
                  _SummaryRow(
                    label: 'Distance',
                    value: '${job.distanceKm!.toStringAsFixed(1)} km',
                  ),
                ],
                const Divider(height: 20),
                _SummaryRow(
                  label: 'Payment method',
                  value: method[0].toUpperCase() + method.substring(1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          AppButton(
            label: 'PAYMENT RECEIVED',
            variant: AppButtonVariant.primary,
            loading: processing,
            height: 54,
            fontSize: 15,
            onPressed: processing ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TRIP SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _TripSuccessDialog extends ConsumerWidget {
  const _TripSuccessDialog({required this.job});
  final JobModel job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(driverHistoryProvider).valueOrNull ?? [];
    final now  = DateTime.now();
    final todayCompleted = jobs.where((j) {
      if (!j.isCompleted || j.completedAt == null) return false;
      final d = DateTime.tryParse(j.completedAt!);
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    final todayEarnings =
        todayCompleted.fold<double>(0, (s, j) => s + j.displayFare);

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.check_circle_outline_rounded,
                    size: 42, color: AppColors.success),
              ),
            ),
            const SizedBox(height: 18),
            Text('Trip Closed Successfully',
                style: AppTextStyles.h3
                    .copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Great job! The trip has been completed.',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      icon: Icons.account_balance_wallet_rounded,
                      label: "Today's Earning",
                      value:
                          '₦${todayEarnings.toStringAsFixed(0)}',
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 50,
                      color: AppColors.divider),
                  Expanded(
                    child: _StatBox(
                      icon: Icons.directions_car_rounded,
                      label: 'Completed Trips',
                      value: '${todayCompleted.length}',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            AppButton(
              label: 'BACK TO DASHBOARD',
              variant: AppButtonVariant.primary,
              height: 50,
              fontSize: 14,
              onPressed: () {
                Navigator.of(context).pop();
                ref.invalidate(driverJobsProvider);
                ref.invalidate(driverHistoryProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String   label, value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: _kAmber, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: AppTextStyles.h3
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED WIDGET — Route row
// ─────────────────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });
  final IconData icon;
  final Color    iconColor;
  final String   label, address;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child:
                Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                Text(address,
                    style: AppTextStyles.bodyMedium
                        .copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 1 — EARNINGS
// ═══════════════════════════════════════════════════════════════════════════════

class _EarningsTab extends ConsumerWidget {
  const _EarningsTab();

  double _earnFor(List<JobModel> jobs, DateTime? from, DateTime? to) =>
      jobs.where((j) {
        if (!j.isCompleted || j.completedAt == null) return false;
        final d = DateTime.tryParse(j.completedAt!);
        if (d == null) return false;
        if (from != null && d.isBefore(from)) return false;
        if (to   != null && d.isAfter(to))   return false;
        return true;
      }).fold(0, (s, j) => s + j.displayFare);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top    = MediaQuery.of(context).padding.top;
    final driver = ref.watch(currentDriverProvider);
    final jobs   = ref.watch(driverHistoryProvider)
            .valueOrNull
            ?.where((j) => j.isCompleted)
            .toList() ??
        [];
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final wkAgo  = now.subtract(const Duration(days: 7));
    final moAgo  = now.subtract(const Duration(days: 30));

    final totalEarnings =
        jobs.fold<double>(0, (s, j) => s + j.displayFare);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: _kAmber,
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
          child: Text('Earnings',
              style: AppTextStyles.h2.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Total card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _kAmber,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Earned',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white
                                .withValues(alpha: 0.85))),
                    const SizedBox(height: 8),
                    Text(
                      '₦${totalEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${jobs.length} completed trips',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white
                                    .withValues(alpha: 0.75))),
                        if (driver?.rating != null) ...[
                          const SizedBox(width: 16),
                          const Icon(Icons.star_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            driver!.rating!.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Breakdown',
                        style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    _EarningsRow(
                        label: 'Today',
                        amount: _earnFor(jobs, today, null)),
                    _EarningsRow(
                        label: 'Last 7 days',
                        amount: _earnFor(jobs, wkAgo, null)),
                    _EarningsRow(
                        label: 'Last 30 days',
                        amount: _earnFor(jobs, moAgo, null),
                        last: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow(
      {required this.label, required this.amount, this.last = false});
  final String label;
  final double amount;
  final bool   last;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(label, style: AppTextStyles.bodyMedium),
                const Spacer(),
                Text('₦${amount.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (!last)
            Divider(
                color: AppColors.divider, height: 1, thickness: 1),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 2 — HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top       = MediaQuery.of(context).padding.top;
    final histAsync = ref.watch(driverHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: _kAmber,
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
          child: Text('Trip History',
              style: AppTextStyles.h2.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: histAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: _kAmber, strokeWidth: 2)),
            error: (e, _) => Center(
                child: Text('Could not load history.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary))),
            data: (jobs) {
              final completed =
                  jobs.where((j) => j.isCompleted).toList();
              if (completed.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 52, color: AppColors.disabled),
                      const SizedBox(height: 12),
                      Text('No trips yet.',
                          style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: _kAmber,
                onRefresh: () async =>
                    ref.invalidate(driverHistoryProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: completed.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _HistoryCard(job: completed[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.job});
  final JobModel job;

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]}, '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  job.bookingRef.isNotEmpty
                      ? '#${job.bookingRef}'
                      : '#${job.id.substring(0, 8).toUpperCase()}',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '₦${job.displayFare.toStringAsFixed(0)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RouteRow(
                icon: Icons.radio_button_on,
                iconColor: AppColors.success,
                label: 'From',
                address: job.pickupAddress),
            const SizedBox(height: 6),
            _RouteRow(
                icon: Icons.location_on,
                iconColor: AppColors.error,
                label: 'To',
                address: job.destinationAddress),
            if (job.completedAt != null) ...[
              const SizedBox(height: 8),
              Text(_fmtDate(job.completedAt),
                  style: AppTextStyles.caption),
            ],
            if (job.distanceKm != null) ...[
              const SizedBox(height: 4),
              Text('${job.distanceKm!.toStringAsFixed(1)} km',
                  style: AppTextStyles.caption),
            ],
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CANCEL REASON SHEET  (driver-side trip cancellation)
// ─────────────────────────────────────────────────────────────────────────────

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet({
    required this.title,
    required this.subtitle,
    required this.reasons,
  });
  final String       title;
  final String       subtitle;
  final List<String> reasons;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;
  bool    _isOther = false;
  final   _otherCtrl = TextEditingController();
  bool    _submitting = false;

  @override
  void dispose() { _otherCtrl.dispose(); super.dispose(); }

  String? get _effectiveReason {
    if (_isOther) {
      final t = _otherCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(widget.title,
              style: AppTextStyles.h4.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(widget.subtitle,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Predefined reasons
          ...widget.reasons.map((r) => _ReasonTile(
                label: r,
                selected: !_isOther && _selected == r,
                onTap: () => setState(() { _selected = r; _isOther = false; }),
              )),

          // "Other" option
          _ReasonTile(
            label: 'Other (please specify)',
            selected: _isOther,
            onTap: () => setState(() { _isOther = true; _selected = null; }),
          ),

          // Custom text field — visible only when "Other" is selected
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _isOther
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: TextField(
                      controller: _otherCtrl,
                      autofocus: true,
                      maxLines: 2,
                      maxLength: 200,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Describe the reason…',
                        hintStyle: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Confirm cancel button — disabled until a reason is chosen
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _effectiveReason == null || _submitting
                  ? null
                  : () {
                      setState(() => _submitting = true);
                      Navigator.pop(context, _effectiveReason);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.disabled,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Confirm Cancel',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white)),
            ),
          ),

          const SizedBox(height: 8),

          // Keep trip
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(context, null),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary),
              child: Text('Keep Trip',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selectable reason row ─────────────────────────────────────────────────────

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.error.withValues(alpha: 0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.error : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.error : AppColors.divider,
                    width: 2,
                  ),
                  color: selected ? AppColors.error : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? AppColors.error
                          : AppColors.textPrimary,
                    )),
              ),
            ],
          ),
        ),
      );
}

