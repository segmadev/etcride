import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
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
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../core/maps/google_maps_js_loader.dart';
import '../../core/maps/maps_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/driver_model.dart';
import '../onboarding/location_permission_screen.dart';
import '../../data/models/job_model.dart';
import '../../core/services/chat_notification_service.dart';
import '../../services/location_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_bottom_drawer.dart';

// ── Brand amber ───────────────────────────────────────────────────────────────
const _kAmber = Color(0xFFE2A322);
const _kDashboardCard = Color(0xFFFBFBFB);
const _kNavInactive = Color(0xFFAAAAAA);

String _money(num amount) => AppFormatters.naira(amount);

String _vehicleDisplayName(DriverAssignedVehicle? vehicle) {
  if (vehicle == null) {
    return 'No vehicle assigned';
  }
  return vehicle.displayName;
}

BoxDecoration _dashboardCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

Future<bool> _ensureLocationPermission(BuildContext context) async {
  if (kIsWeb) return true;
  final perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.always ||
      perm == LocationPermission.whileInUse) {
    return true;
  }
  if (!context.mounted) return false;
  final granted = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const LocationPermissionScreen()),
  );
  return granted == true;
}

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _kAmber,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    super.dispose();
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  /// True while an active trip (or its payment step) occupies the Home tab —
  /// the bottom nav is hidden in this state so the trip screen gets the full
  /// height instead of leaving a gap above a nav bar the driver can't use
  /// mid-trip anyway.
  bool _isInTripFlow() {
    final jobs = ref.watch(driverJobsProvider).valueOrNull;
    if (jobs == null) return false;
    return jobs.any(
      (j) => [
        'accepted',
        'arrived',
        'picked_up',
        'in_progress',
        'payment_pending',
      ].contains(j.status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hideBottomNav = _tab == 0 && _isInTripFlow();
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawer: _DriverDrawer(
        scaffoldKey: _scaffoldKey,
        onSelectTab: (i) => setState(() => _tab = i),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(onMenuTap: _openDrawer),
          _TabWithHeader(onMenuTap: _openDrawer, child: const _EarningsTab()),
          _TabWithHeader(onMenuTap: _openDrawer, child: const _HistoryTab()),
        ],
      ),
      bottomNavigationBar: hideBottomNav
          ? null
          : _BottomNav(current: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

class _TabWithHeader extends ConsumerStatefulWidget {
  const _TabWithHeader({required this.onMenuTap, required this.child});

  final VoidCallback onMenuTap;
  final Widget child;

  @override
  ConsumerState<_TabWithHeader> createState() => _TabWithHeaderState();
}

class _TabWithHeaderState extends ConsumerState<_TabWithHeader> {
  bool _togglingOnline = false;

  Future<void> _toggleOnline() async {
    final current = ref.read(driverOnlineProvider);

    if (!current) {
      final hasPermission = await _ensureLocationPermission(context);
      if (!hasPermission) return;
    }

    setState(() => _togglingOnline = true);
    try {
      await ref.read(driverRepositoryProvider).setAvailability(!current);
      ref.read(driverOnlineProvider.notifier).state = !current;
      final driver = ref.read(currentDriverProvider);
      if (driver != null) {
        final updated = driver.copyWith(isOnline: !current);
        ref.read(currentDriverProvider.notifier).state = updated;
        await ref
            .read(driverAuthRepositoryProvider)
            .updateCachedDriver(updated);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);
    final isOnline = ref.watch(driverOnlineProvider);

    return Column(
      children: [
        _HeaderBar(
          isOnline: isOnline,
          toggling: _togglingOnline,
          onToggle: _toggleOnline,
          onMenuTap: widget.onMenuTap,
          driver: driver,
        ),
        Expanded(child: widget.child),
      ],
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;
              final indicatorWidth = itemWidth - 22;
              final indicatorLeft =
                  (itemWidth * current) + ((itemWidth - indicatorWidth) / 2);

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeInOutCubicEmphasized,
                    left: indicatorLeft,
                    top: 10,
                    width: indicatorWidth,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _NavItem(
                          assetPath: AppAssets.homeNavIcon,
                          label: 'Home',
                          index: 0,
                          current: current,
                          onTap: onTap,
                          iconSize: const Size(22, 22),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          assetPath: AppAssets.earningsNavIcon,
                          label: 'Analytics',
                          index: 1,
                          current: current,
                          onTap: onTap,
                          iconSize: const Size(21, 11),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          assetPath: AppAssets.historyNavIcon,
                          label: 'History',
                          index: 2,
                          current: current,
                          onTap: onTap,
                          iconSize: const Size(22, 22),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.assetPath,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    required this.iconSize,
  });
  final String assetPath;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  final Size iconSize;

  bool get _selected => current == index;

  @override
  Widget build(BuildContext context) {
    final color = _selected ? Colors.black : _kNavInactive;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => onTap(index),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubicEmphasized,
          height: 36,
          padding: EdgeInsets.symmetric(
            horizontal: _selected ? 12 : 4,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubicEmphasized,
                tween: ColorTween(end: color),
                builder: (context, animatedColor, child) {
                  return SizedBox(
                    width: iconSize.width,
                    height: iconSize.height,
                    child: SvgPicture.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        animatedColor ?? color,
                        BlendMode.srcIn,
                      ),
                    ),
                  );
                },
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                reverseDuration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeInOutCubicEmphasized,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(-0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                  );
                },
                child: _selected
                    ? Padding(
                        key: ValueKey(label),
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          label,
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DRAWER
// ─────────────────────────────────────────────────────────────────────────────

class _DriverDrawer extends ConsumerWidget {
  const _DriverDrawer({required this.scaffoldKey, required this.onSelectTab});
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverProvider);
    final unread = ref.watch(driverUnreadNotifCountProvider).valueOrNull ?? 0;
    final ratingLabel = driver?.rating?.toStringAsFixed(1) ?? 'N/A';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD1D9), width: 1),
                ),
                child: _DriverAvatar(driver: driver, radius: 33),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'Hello 👋',
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_outline_rounded,
                        size: 16,
                        color: _kAmber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ratingLabel,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                driver?.name ?? 'Driver',
                style: AppTextStyles.h4.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                driver?.kycStatus == 'verified'
                    ? 'Approved Driver'
                    : 'Driver Account',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: const Color(0xFF9B9B9B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 42),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SideMenuItem(
                      label: 'Profile',
                      onTap: () {
                        _close(context);
                        context.push(AppRoutes.driverProfile);
                      },
                    ),
                    _SideMenuItem(
                      label: 'Assigned Vehicle',
                      onTap: () {
                        _close(context);
                        context.push(AppRoutes.assignedVehicle);
                      },
                    ),
                    _SideMenuItem(
                      label: 'Earnings',
                      onTap: () {
                        _close(context);
                        onSelectTab(1);
                      },
                    ),
                    _SideMenuItem(
                      label: 'Trip History',
                      onTap: () {
                        _close(context);
                        onSelectTab(2);
                      },
                    ),
                    ValueListenableBuilder<Map<String, int>>(
                      valueListenable: ChatNotificationService.instance.unreadCounts,
                      builder: (_, counts, __) {
                        final total = counts.values.fold(0, (s, n) => s + n);
                        return _SideMenuItem(
                          label: 'Messages',
                          badge: total > 0 ? (total > 99 ? '99+' : '$total') : null,
                          onTap: () {
                            _close(context);
                            context.push(AppRoutes.chatHistory);
                          },
                        );
                      },
                    ),
                    _SideMenuItem(
                      label: 'Notifications',
                      badge: unread > 0 ? '$unread' : null,
                      onTap: () {
                        _close(context);
                        context.push(AppRoutes.notifications);
                      },
                    ),
                    _SideMenuItem(
                      label: 'Help & Support',
                      onTap: () {
                        _close(context);
                        context.push(AppRoutes.help);
                      },
                    ),
                    _SideMenuItem(
                      label: 'Settings',
                      onTap: () {
                        _close(context);
                        context.push(AppRoutes.settings);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFD4D4D4)),
              const SizedBox(height: 26),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(driverAuthRepositoryProvider).logout();
                  ref.read(currentDriverProvider.notifier).state = null;
                  if (!context.mounted) return;
                  context.go(AppRoutes.signIn);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Log Out',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _close(BuildContext context) => Navigator.of(context).pop();
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({required this.label, required this.onTap, this.badge});

  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badge != null)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: _kAmber,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge!,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
    this.tripFlowMode = false,
  });
  final bool isOnline, toggling;
  final VoidCallback onToggle, onMenuTap;
  final DriverModel? driver;
  final bool tripFlowMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(driverUnreadNotifCountProvider).valueOrNull ?? 0;

    return Container(
      color: _kAmber,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(
            children: [
              _HeaderActionButton(
                onTap: onMenuTap,
                icon: SvgPicture.asset(
                  AppAssets.menuIcon,
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 196),
                    child: _HeaderStatusCapsule(
                      isOnline: isOnline,
                      toggling: toggling,
                      onToggle: onToggle,
                      driver: driver,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              tripFlowMode
                  ? const SizedBox(width: 40, height: 40)
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _HeaderActionButton(
                          onTap: () {},
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            size: 22,
                            color: Colors.black,
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kAmber,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatusCapsule extends StatefulWidget {
  const _HeaderStatusCapsule({
    required this.isOnline,
    required this.toggling,
    required this.onToggle,
    required this.driver,
  });

  final bool isOnline;
  final bool toggling;
  final VoidCallback onToggle;
  final DriverModel? driver;

  @override
  State<_HeaderStatusCapsule> createState() => _HeaderStatusCapsuleState();
}

class _HeaderStatusCapsuleState extends State<_HeaderStatusCapsule> {
  String? _address;
  bool _loadingAddress = false;
  int _geocodeSeq = 0;

  @override
  void initState() {
    super.initState();
    LocationService.instance.positionNotifier.addListener(_onPositionUpdate);
    if (widget.isOnline) {
      _bootstrapLocation();
    }
  }

  @override
  void didUpdateWidget(covariant _HeaderStatusCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOnline && widget.isOnline) {
      _bootstrapLocation();
    }
    if (oldWidget.isOnline && !widget.isOnline && mounted) {
      setState(() {
        _address = null;
        _loadingAddress = false;
      });
    }
  }

  @override
  void dispose() {
    LocationService.instance.positionNotifier.removeListener(_onPositionUpdate);
    super.dispose();
  }

  void _onPositionUpdate() {
    if (!widget.isOnline || _address != null) {
      return;
    }
    _bootstrapLocation();
  }

  Future<void> _bootstrapLocation() async {
    final last = LocationService.instance.lastPosition;
    if (last != null) {
      await _geocodeAddress(last);
      return;
    }
    if (mounted) {
      setState(() => _loadingAddress = true);
    }
    await LocationService.instance.refreshPosition();
    final refreshed = LocationService.instance.lastPosition;
    if (refreshed != null) {
      await _geocodeAddress(refreshed);
    } else if (mounted) {
      setState(() => _loadingAddress = false);
    }
  }

  Future<void> _geocodeAddress(Position position) async {
    final seq = ++_geocodeSeq;
    if (mounted) {
      setState(() => _loadingAddress = true);
    }
    try {
      final address = await MapsService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted || seq != _geocodeSeq) {
        return;
      }
      setState(() {
        _address = address;
        _loadingAddress = false;
      });
    } catch (_) {
      if (mounted && seq == _geocodeSeq) {
        setState(() => _loadingAddress = false);
      }
    }
  }

  String _locationPrefix(String? address) {
    final raw = (address ?? '').trim();
    if (raw.isEmpty) {
      return 'Current location';
    }
    final first = raw.split(',').first.trim();
    return first.isEmpty ? raw : first;
  }

  void _showLocationDetails() {
    showDraggableBottomSheet<void>(
      context: context,
      initialChildSize: 0.32,
      minChildSize: 0.14,
      maxChildSize: 0.55,
      builder: (_) => const _LocationDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.isOnline
        ? (_loadingAddress && (_address == null || _address!.trim().isEmpty)
              ? 'Locating...'
              : _locationPrefix(_address))
        : 'Offline';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _DriverAvatar(
            driver: widget.driver,
            radius: 14,
            showOnlineBadge: widget.isOnline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: widget.isOnline ? _showLocationDetails : null,
              child: Text(
                statusText,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          widget.toggling
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kAmber,
                      ),
                    ),
                  ),
                )
              : _StatusToggle(value: widget.isOnline, onTap: widget.onToggle),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.onTap});

  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  const _StatusToggle({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 24,
        height: 12,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: value ? _kAmber : const Color(0xFFD8D8D8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DRIVER AVATAR  (reusable)
// ─────────────────────────────────────────────────────────────────────────────

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({
    required this.driver,
    required this.radius,
    this.showOnlineBadge = false,
  });
  final DriverModel? driver;
  final double radius;
  final bool showOnlineBadge;

  @override
  Widget build(BuildContext context) {
    final url = driver?.photo;
    final name = driver?.name ?? '';
    final Widget avatar;
    if (url != null && url.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: _kAmber.withValues(alpha: 0.2),
        backgroundImage: CachedNetworkImageProvider(url),
      );
    } else {
      avatar = CircleAvatar(
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

    if (!showOnlineBadge) {
      return avatar;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: radius * 0.58,
            height: radius * 0.58,
            decoration: BoxDecoration(
              color: const Color(0xFF52C64C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.6),
            ),
          ),
        ),
      ],
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
  bool _togglingOnline = false;
  Timer? _jobPollTimer;
  ProviderSubscription<bool>? _onlineSub;
  final AudioPlayer _newRidePlayer = AudioPlayer();

  /// Tracks which job IDs have already triggered the "new trip" banner.
  final Set<String> _banneredJobIds = {};
  bool _initialJobsLoaded = false;

  /// Tracks whether we are mid-payment action (for the payment screen).
  bool _processingPayment = false;

  /// True while the auto-arrive dialog is showing (prevents duplicate dialogs).
  bool _autoArrivePending = false;

  /// IDs of jobs the driver was actively working — used to detect
  /// customer-initiated cancellation when the job disappears from active list.
  final Set<String> _trackedActiveJobIds = {};
  final Set<String> _cancelNotifiedJobIds = {};

  // ── GPS distance + time accumulation during in_progress ─────────────────
  double    _tripDistanceKm   = 0.0;
  Position? _lastTripPosition;
  String?   _trackingJobId;
  DateTime? _tripStartTime;

  /// Default threshold in metres matching the backend default for auto_arrive_radius_m.
  static const double _autoArriveDefaultM = 20.0;

  @override
  void initState() {
    super.initState();
    _onlineSub = ref.listenManual<bool>(driverOnlineProvider, (previous, next) {
      if (!mounted) return;
      if (next) {
        _startTracking();
      } else {
        _stopTracking();
      }
    });
    if (ref.read(driverOnlineProvider)) _startTracking();
    LocationService.instance.positionNotifier.addListener(_checkAutoArrive);
  }

  @override
  void dispose() {
    LocationService.instance.positionNotifier.removeListener(_checkAutoArrive);
    _onlineSub?.close();
    _jobPollTimer?.cancel();
    LocationService.instance.stop();
    _newRidePlayer.dispose();
    super.dispose();
  }

  // ── Auto-arrive detection ────────────────────────────────────────────────────

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0; // metres
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180);
    final dLng = (lng2 - lng1) * (3.141592653589793 / 180);
    final la1 = lat1 * (3.141592653589793 / 180);
    final la2 = lat2 * (3.141592653589793 / 180);
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLng / 2);
    final h = s1 * s1 + math.cos(la1) * math.cos(la2) * s2 * s2;
    return r * 2 * math.asin(math.sqrt(h));
  }

  void _checkAutoArrive() {
    if (!mounted || _autoArrivePending) return;
    final pos = LocationService.instance.lastPosition;
    if (pos != null) _accumulateTripDistance(pos);
    if (pos == null) return;

    final jobs = ref.read(driverJobsProvider).valueOrNull;
    if (jobs == null) return;

    JobModel? accepted;
    for (final j in jobs) {
      if (j.status == 'accepted' && j.canArrive) {
        accepted = j;
        break;
      }
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

  void _accumulateTripDistance(Position pos) {
    final jobs = ref.read(driverJobsProvider).valueOrNull;
    final job  = jobs?.firstWhere(
      (j) => j.status == 'in_progress',
      orElse: () => JobModel.stub(''),
    );
    if (job == null || job.id.isEmpty) {
      // Not in_progress — reset accumulator when job changes
      if (_trackingJobId != null) {
        _tripDistanceKm   = 0.0;
        _lastTripPosition = null;
        _trackingJobId    = null;
        _tripStartTime    = null;
      }
      return;
    }
    if (_trackingJobId != job.id) {
      // New in_progress job — record start time
      _tripDistanceKm   = 0.0;
      _lastTripPosition = pos;
      _trackingJobId    = job.id;
      _tripStartTime    = DateTime.now();
      return;
    }
    if (_lastTripPosition != null) {
      final deltaM = _haversineMeters(
        _lastTripPosition!.latitude, _lastTripPosition!.longitude,
        pos.latitude, pos.longitude,
      );
      _tripDistanceKm += deltaM / 1000.0;
    }
    _lastTripPosition = pos;
  }

  void _showAutoArriveDialog(JobModel job) {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'You\'ve arrived!',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You appear to be at the pickup location. Confirm arrival?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
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
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, arrived'),
          ),
        ],
      ),
    ).then((confirmed) {
      _autoArrivePending = false;
      if (confirmed == true && mounted) {
        final repo = ref.read(driverRepositoryProvider);
        final pos = LocationService.instance.lastPosition;
        _doJobAction(
          () => repo.arriveAtPickup(
            job.id,
            lat: pos?.latitude,
            lng: pos?.longitude,
            gpsAccuracyM: pos?.accuracy,
          ),
          onSuccess: () =>
              _showInfoSnack('Marked as arrived! Waiting for passenger.'),
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

  Future<void> _toggleOnline() async {
    final current = ref.read(driverOnlineProvider);

    // Going online requires location permission — show onboarding screen if needed.
    if (!current) {
      final hasPermission = await _ensureLocationPermission(context);
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
        await ref
            .read(driverAuthRepositoryProvider)
            .updateCachedDriver(updated);
      }
    } catch (_) {
      // silently revert
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  // ── New-job notification banner ─────────────────────────────────────────────

  Future<void> _playNewRideSound() async {
    try {
      await _newRidePlayer.play(AssetSource('sounds/new_ride.wav'));
    } catch (_) {}
  }

  void _showNewJobBanner(JobModel job) {
    if (!mounted) return;
    _playNewRideSound();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _kAmber,
        content: Row(
          children: [
            const Icon(
              Icons.notification_important_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'New Trip Request!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    job.pickupAddress,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Trip complete dialog ─────────────────────────────────────────────────────

  void _showTripSuccessDialog(JobModel job) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Trip Cancelled',
              style: AppTextStyles.h4.copyWith(fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$who has cancelled this trip.',
              style: AppTextStyles.bodyMedium,
            ),
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
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"$reason"',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Job action helpers ───────────────────────────────────────────────────────

  Future<void> _doJobAction(
    Future<void> Function() action, {
    VoidCallback? onSuccess,
  }) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);
    final isOnline = ref.watch(driverOnlineProvider);
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
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showNewJobBanner(j),
          );
          break;
        }

        // Job was active before and is now cancelled by customer or admin
        if (j.isCancelled &&
            _trackedActiveJobIds.contains(j.id) &&
            !_cancelNotifiedJobIds.contains(j.id) &&
            j.cancelledByRole != 'driver') {
          _cancelNotifiedJobIds.add(j.id);
          _trackedActiveJobIds.remove(j.id);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showCancelledByCustomerDialog(j),
          );
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
            'in_progress',
            'picked_up',
            'arrived',
            'accepted',
            'payment_pending',
            'assigned',
          ];
          final bi = order.indexOf(best.status);
          final ji = order.indexOf(j.status);
          return (ji < bi) ? j : best;
        });
    final tripFlowMode =
        activeJob != null &&
        [
          'accepted',
          'arrived',
          'picked_up',
          'in_progress',
          'payment_pending',
        ].contains(activeJob.status);

    return Column(
      children: [
        _HeaderBar(
          isOnline: isOnline,
          toggling: _togglingOnline,
          onToggle: _toggleOnline,
          onMenuTap: widget.onMenuTap,
          driver: driver,
          tripFlowMode: tripFlowMode,
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
              isOnline: isOnline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required DriverModel? driver,
    required JobModel? job,
    required bool jobsLoading,
    required bool isOnline,
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

    // ── Active trip (accepted / arrived / picked_up / in_progress) ────────────
    if (job != null &&
        ['accepted', 'arrived', 'picked_up', 'in_progress'].contains(job.status)) {
      return _TripFlowScreen(
        key: ValueKey('active_${job.id}'),
        map: _TripMapView(job: job),
        child: _ActiveTripView(
          job: job,
          onArrive: job.canArrive
              ? () => _doJobAction(
                  () => repo.arriveAtPickup(job.id),
                  onSuccess: () => _showInfoSnack(
                    job.bookingType == 'delivery'
                        ? 'Arrived at pickup. Collect payment before picking up the package.'
                        : 'Arrival confirmed! Waiting for the customer.',
                  ),
                )
              : null,
          onConfirmCashPayment: job.deliveryNeedsPayment && job.isCashPayment
              ? () => _doJobAction(
                  () => repo.confirmPickupPayment(job.id),
                  onSuccess: () => _showInfoSnack('Cash confirmed! You can now pick up the package.'),
                )
              : null,
          onPickup: job.canPickup
              ? () => _doJobAction(
                  () => repo.pickupPackage(job.id),
                  onSuccess: () => _showInfoSnack('Package picked up! Start delivery.'),
                )
              : null,
          onStart: job.canStart
              ? () => _doJobAction(
                  () => repo.startTrip(job.id),
                  onSuccess: () => _showInfoSnack(
                    job.bookingType == 'delivery'
                        ? 'Delivery in progress!'
                        : 'Passenger on board. You can now start the trip.',
                  ),
                )
              : null,
          onComplete: job.canComplete
              ? () {
                  final durationMin = _tripStartTime != null
                      ? DateTime.now().difference(_tripStartTime!).inSeconds / 60.0
                      : null;
                  return _doJobAction(() => repo.completeTrip(
                    job.id,
                    distanceKm: _tripDistanceKm > 0.1 ? _tripDistanceKm : null,
                    durationMinutes: (durationMin != null && durationMin > 0.5) ? durationMin : null,
                  ));
                }
              : null,
          onNavigateToPickup: () => _openTripNavigation(job),
          onNavigateToDestination: () =>
              _openTripNavigation(job, toDestination: true),
          onCallPassenger: () => _callPhone(job.passengerPhone),
          onChatPassenger: () => context.push(AppRoutes.chat, extra: job),
        ),
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
                _showInfoSnack('Trip accepted! Head to the pickup point.'),
          ),
          onDecline: () => _doJobAction(() => repo.rejectJob(job.id)),
        ),
      );
    }

    if (!isOnline) {
      return _OfflineDashboardScroll(driver: driver, onGoOnline: _toggleOnline);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openTripNavigation(
    JobModel job, {
    bool toDestination = false,
  }) async {
    final lat = toDestination ? job.destinationLat : job.pickupLat;
    final lng = toDestination ? job.destinationLng : job.pickupLng;
    if (lat == null || lng == null) {
      _showErrorSnack('Navigation coordinates are not available yet.');
      return;
    }
    final driverPos = LocationService.instance.lastPosition;
    final uri = driverPos != null
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&origin=${driverPos.latitude},${driverPos.longitude}'
            '&destination=$lat,$lng'
            '&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1'
            '&query=$lat,$lng',
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: _kAmber,
      onRefresh: () async {
        ref.invalidate(driverJobsProvider);
        ref.invalidate(driverHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _TodayEarningsCard(driver: driver),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OfflineDashboardScroll extends ConsumerWidget {
  const _OfflineDashboardScroll({
    required this.driver,
    required this.onGoOnline,
  });

  final DriverModel? driver;
  final Future<void> Function() onGoOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: _kAmber,
      onRefresh: () async {
        ref.invalidate(driverJobsProvider);
        ref.invalidate(driverHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _OfflineIntroCard(onGoOnline: onGoOnline),
          const SizedBox(height: 16),
          _AssignedVehicleSummaryCard(driver: driver),
          const SizedBox(height: 16),
          _OfflineEarningsCard(driver: driver),
          const SizedBox(height: 16),
          const _OfflineNoTripsCard(),
        ],
      ),
    );
  }
}

class _TripFlowScreen extends StatelessWidget {
  const _TripFlowScreen({super.key, required this.map, required this.child});

  final Widget map;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
          ),
        ),
        // `child` (_ActiveTripView) owns its own CollapsibleMapSheet, so it
        // needs the full Stack height to size its drag range against — no
        // bottom padding here, otherwise a dead gap reappears below it.
        Positioned.fill(child: child),
      ],
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

  String? _address;
  String? _coords;
  DateTime? _updatedAt;
  bool _geocoding = false;
  int _geocodeSeq = 0;
  _LocState _state = _LocState.loading;

  @override
  void initState() {
    super.initState();
    debugPrint('$_tag initState()');
    LocationService.instance.positionNotifier.addListener(_onPositionUpdate);

    final last = LocationService.instance.lastPosition;
    debugPrint(
      '$_tag initState: lastPosition=${last == null ? "null" : "${last.latitude}, ${last.longitude}"}',
    );
    if (last != null) {
      _updateCoords(last);
      _geocodeAddress(last);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          '$_tag postFrameCallback firing — calling _reload(auto: true)',
        );
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
    debugPrint(
      '$_tag _onPositionUpdate: pos=${pos == null ? "null" : "${pos.latitude}, ${pos.longitude}"}',
    );
    if (pos == null) return;
    _updateCoords(pos);
  }

  void _updateCoords(Position position) {
    debugPrint(
      '$_tag _updateCoords: ${position.latitude}, ${position.longitude}  acc=${position.accuracy}m',
    );
    if (!mounted) {
      debugPrint('$_tag _updateCoords: not mounted, skipping');
      return;
    }
    setState(() {
      _state = _LocState.ok;
      _coords =
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';
      _updatedAt = DateTime.now();
    });
    debugPrint('$_tag _updateCoords: state → ok, coords=$_coords');
  }

  // ── Reverse geocoding ───────────────────────────────────────────────────────

  Future<void> _geocodeAddress(Position position) async {
    final seq = ++_geocodeSeq;
    debugPrint(
      '$_tag _geocodeAddress seq=$seq: ${position.latitude}, ${position.longitude}',
    );
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final addr = await MapsService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      debugPrint(
        '$_tag _geocodeAddress seq=$seq result: ${addr ?? "(null — will fall back to coords)"}',
      );
      if (!mounted || seq != _geocodeSeq) {
        debugPrint(
          '$_tag _geocodeAddress seq=$seq: stale (current=$_geocodeSeq) or unmounted, discarding',
        );
        return;
      }
      setState(() {
        _address = addr;
        _geocoding = false;
      });
    } catch (e, st) {
      debugPrint('$_tag _geocodeAddress seq=$seq threw: $e\n$st');
      if (mounted && seq == _geocodeSeq) setState(() => _geocoding = false);
    }
  }

  // ── Reload ──────────────────────────────────────────────────────────────────

  Future<void> _reload({bool auto = false}) async {
    debugPrint(
      '$_tag _reload(auto=$auto) START — state=$_state  kIsWeb=$kIsWeb',
    );

    // ── 1. GPS hardware on? (native only — browser always "on") ─────────────
    if (!kIsWeb) {
      final svcOn = await Geolocator.isLocationServiceEnabled();
      debugPrint('$_tag _reload: locationServiceEnabled=$svcOn');
      if (!svcOn) {
        if (mounted) {
          setState(() {
            _state = _LocState.serviceOff;
            _geocoding = false;
          });
        }
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
          debugPrint(
            '$_tag _reload(auto, web): calling requestPermission() for browser dialog',
          );
          final newPerm = await Geolocator.requestPermission();
          debugPrint(
            '$_tag _reload(auto, web): after requestPermission=$newPerm',
          );
          if (newPerm == LocationPermission.denied ||
              newPerm == LocationPermission.deniedForever) {
            if (mounted) {
              setState(() {
                _state = _LocState.denied;
                _geocoding = false;
              });
            }
            return;
          }
          // Granted — fall through to fetch
        } else {
          // Native: don't push a screen on auto-load, just show the card hint
          if (mounted) {
            setState(() {
              _state = _LocState.denied;
              _geocoding = false;
            });
          }
          debugPrint(
            '$_tag _reload(auto, native): permission $perm → denied state, waiting for user tap',
          );
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
            if (mounted) {
              setState(() {
                _state = _LocState.denied;
                _geocoding = false;
              });
            }
            return;
          }
        } else {
          debugPrint(
            '$_tag _reload(manual, native): pushing LocationPermissionScreen',
          );
          if (!mounted) return;
          final granted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const LocationPermissionScreen()),
          );
          debugPrint(
            '$_tag _reload(manual, native): screen returned granted=$granted',
          );
          if (granted != true) {
            if (mounted) {
              setState(() {
                _state = _LocState.denied;
                _geocoding = false;
              });
            }
            return;
          }
        }
      }
    }

    // ── 3. Fetch ─────────────────────────────────────────────────────────────
    debugPrint('$_tag _reload: permission OK — fetching position');
    if (mounted) {
      setState(() {
        _state = _LocState.loading;
        _geocoding = true;
      });
    }

    await LocationService.instance.refreshPosition();
    debugPrint('$_tag _reload: refreshPosition() returned');

    if (!mounted) {
      debugPrint('$_tag _reload: not mounted after refresh');
      return;
    }

    final pos = LocationService.instance.lastPosition;
    debugPrint(
      '$_tag _reload: lastPosition = ${pos == null ? "NULL" : "${pos.latitude}, ${pos.longitude}"}',
    );

    if (pos != null) {
      _updateCoords(pos);
      await _geocodeAddress(pos);
    } else {
      debugPrint('$_tag _reload: no position obtained → unavailable state');
      setState(() {
        _state = _LocState.unavailable;
        _geocoding = false;
      });
    }
    debugPrint('$_tag _reload(auto=$auto) END — final state=$_state');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _fmtAge(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isError =
        _state == _LocState.denied ||
        _state == _LocState.serviceOff ||
        _state == _LocState.unavailable;
    final bool isFetching = _state == _LocState.loading && _coords == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: _dashboardCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Pin icon ─────────────────────────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isError
                  ? AppColors.warningLight
                  : _kAmber.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isError
                    ? Icons.location_off_rounded
                    : Icons.my_location_rounded,
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
                      _LocState.serviceOff =>
                        'GPS is turned off — enable it in device settings',
                      _LocState.denied =>
                        'Location permission needed — tap ↻ to allow',
                      _LocState.unavailable =>
                        'Couldn\'t get a GPS fix — tap ↻ to retry',
                      _ => '',
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
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _kAmber,
                          ),
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
            width: 36,
            height: 36,
            child: (isFetching)
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kAmber,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: _kAmber,
                      size: 20,
                    ),
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
    final now = DateTime.now();
    final todayJobs = jobs.where((j) {
      if (!j.isCompleted || j.completedAt == null) return false;
      final d = DateTime.tryParse(j.completedAt!);
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    final todayEarnings = todayJobs.fold<double>(
      0,
      (s, j) => s + j.displayFare,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _dashboardCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Today Earnings',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: _kAmber,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _money(todayEarnings),
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE6E6E6)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStatText(
                  icon: Icons.directions_car_rounded,
                  value: '${todayJobs.length} Trips',
                  mainAxisAlignment: MainAxisAlignment.start,
                ),
              ),
              Expanded(
                child: _MiniStatText(
                  icon: Icons.star_rounded,
                  value: driver?.rating != null
                      ? '${driver!.rating!.toStringAsFixed(1)} Rating'
                      : 'N/A Rating',
                  mainAxisAlignment: MainAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatText extends StatelessWidget {
  const _MiniStatText({
    required this.icon,
    required this.value,
    required this.mainAxisAlignment,
  });

  final IconData icon;
  final String value;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Icon(icon, color: _kAmber, size: 18),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: _kDashboardCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Status',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SvgPicture.asset(
              AppAssets.driverStatusArt,
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'No trips assigned yet. Stay online to receive jobs.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (jobsLoading) ...[
            const SizedBox(height: 18),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _kAmber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineIntroCard extends StatelessWidget {
  const _OfflineIntroCard({required this.onGoOnline});

  final Future<void> Function() onGoOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: _dashboardCardDecoration(color: const Color(0xFFF3ECDD)),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: _kAmber,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.offlineWifiIcon,
                width: 34,
                height: 34,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're Offline",
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Turn on your availability to receive trips.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      onGoOnline();
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF1E1304),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Text(
                      'GO ONLINE',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedVehicleSummaryCard extends StatelessWidget {
  const _AssignedVehicleSummaryCard({required this.driver});

  final DriverModel? driver;

  @override
  Widget build(BuildContext context) {
    final vehicle = driver?.assignedVehicle;
    final color = vehicle?.color?.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppRoutes.assignedVehicle),
      child: Container(
        decoration: _dashboardCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Assigned Vehicle',
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _InlineVehicleStatusPill(status: vehicle?.status),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _VehicleThumb(photoUrl: vehicle?.photoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _vehicleDisplayName(vehicle),
                          style: AppTextStyles.h3.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicle?.plateNumber?.trim().isNotEmpty == true
                              ? vehicle!.plateNumber!.trim()
                              : 'Awaiting assignment',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          color != null && color.isNotEmpty
                              ? color.toUpperCase()
                              : '--',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleThumb extends StatelessWidget {
  const _VehicleThumb({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    final fallback = SvgPicture.asset(
      AppAssets.etcPremiumCardIcon,
      width: 100,
      height: 58,
      fit: BoxFit.contain,
    );

    if (!hasUrl) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 100,
        height: 58,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _InlineVehicleStatusPill extends StatelessWidget {
  const _InlineVehicleStatusPill({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final isActive = (status ?? '').toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDDE8D9) : const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: AppTextStyles.bodyMedium.copyWith(
          color: isActive ? const Color(0xFF188118) : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OfflineEarningsCard extends ConsumerWidget {
  const _OfflineEarningsCard({required this.driver});

  final DriverModel? driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(driverHistoryProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final todayJobs = jobs.where((j) {
      if (!j.isCompleted || j.completedAt == null) return false;
      final d = DateTime.tryParse(j.completedAt!);
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    final todayEarnings = todayJobs.fold<double>(
      0,
      (sum, job) => sum + job.displayFare,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: _dashboardCardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Earnings",
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _money(todayEarnings),
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: _kAmber,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNoTripsCard extends StatelessWidget {
  const _OfflineNoTripsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: _dashboardCardDecoration(),
      child: Column(
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: const BoxDecoration(
              color: Color(0xFFD9D9D9),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.offlineTripsIcon,
                width: 54,
                height: 54,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No trips will be assigned while\nyou’re offline",
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Go online to start receiving trips.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationDetailsSheet extends StatelessWidget {
  const _LocationDetailsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver Location',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const _LocationStatusCard(),
        ],
      ),
    );
  }
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
  final JobModel job;
  final Future<void> Function() onAccept, onDecline;

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
    final paymentMethod = (job.paymentMethod ?? 'Cash').trim();
    final bookingType = job.bookingType.trim();
    final bookingTypeLabel = bookingType.isEmpty
        ? 'Ride'
        : '${bookingType[0].toUpperCase()}${bookingType.substring(1)}';

    return Container(
      decoration: _dashboardCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE95B4F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 9,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Incoming Ride Request',
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'See All',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _RequestDetailCell(
                    label: 'Pick up',
                    value: job.pickupAddress,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _RequestDetailCell(
                    label: 'Drop off',
                    value: job.destinationAddress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE4E4E4)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RequestDetailCell(
                    label: 'Estimated Time',
                    value: job.durationMinutes != null
                        ? '${job.durationMinutes} mins'
                        : '--',
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _RequestDetailCell(
                    label: 'Estimated Price',
                    value: _money(job.estimatedFare),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE4E4E4)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RequestDetailCell(
                    label: 'Payment Method',
                    value: paymentMethod.isEmpty ? 'Cash' : paymentMethod,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _RequestDetailCell(
                    label: 'Ride Type',
                    value: bookingTypeLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE4E4E4)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DecisionButton(
                    label: 'DECLINE',
                    loading: _busy,
                    primary: false,
                    onPressed: _busy ? null : () => _run(widget.onDecline),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _DecisionButton(
                    label: 'ACCEPT TRIP',
                    loading: _busy,
                    primary: true,
                    onPressed: _busy ? null : () => _run(widget.onAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestDetailCell extends StatelessWidget {
  const _RequestDetailCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.loading,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final background = primary ? Colors.black : const Color(0xFFF1F1F1);
    final foreground = primary ? Colors.white : const Color(0xFF717171);

    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.6),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTIVE TRIP FLOW  (map + state-specific bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveTripView extends StatefulWidget {
  const _ActiveTripView({
    required this.job,
    this.onArrive,
    this.onPickup,
    this.onStart,
    this.onComplete,
    this.onConfirmCashPayment,
    required this.onNavigateToPickup,
    required this.onNavigateToDestination,
    required this.onCallPassenger,
    required this.onChatPassenger,
  });

  final JobModel job;
  final Future<void> Function()? onArrive;
  final Future<void> Function()? onPickup;
  final Future<void> Function()? onStart;
  final Future<void> Function()? onComplete;
  final Future<void> Function()? onConfirmCashPayment;
  final VoidCallback onNavigateToPickup;
  final VoidCallback onNavigateToDestination;
  final VoidCallback onCallPassenger;
  final VoidCallback onChatPassenger;

  @override
  State<_ActiveTripView> createState() => _ActiveTripViewState();
}

class _ActiveTripViewState extends State<_ActiveTripView> {
  bool _busy = false;
  bool _passengerReadyToStart = false;

  @override
  void initState() {
    super.initState();
    LocationService.instance.setActiveJob(true);
  }

  @override
  void dispose() {
    LocationService.instance.setActiveJob(false);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ActiveTripView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.job.status != oldWidget.job.status &&
        widget.job.status != 'arrived') {
      _passengerReadyToStart = false;
    }
  }

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _tripCode => widget.job.bookingRef.isNotEmpty
      ? '#${widget.job.bookingRef}'
      : '#${widget.job.id.substring(0, 8).toUpperCase()}';

  String get _paymentMethod {
    final raw = (widget.job.paymentMethod ?? 'Cash').trim();
    return raw.isEmpty ? 'Cash' : raw[0].toUpperCase() + raw.substring(1);
  }

  String get _etaLabel => widget.job.durationMinutes != null
      ? '${widget.job.durationMinutes} mins'
      : '--';

  String get _distanceLabel => widget.job.distanceKm != null
      ? '${widget.job.distanceKm!.toStringAsFixed(1)} km'
      : '--';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CollapsibleMapSheet(
            backgroundColor: const Color(0xFFF4F4F4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: switch (widget.job.status) {
                'accepted' => _buildAcceptedSheet(),
                'arrived'  => widget.job.bookingType == 'delivery'
                    ? _buildArrivedSheet()           // delivery: shows PACKAGE PICKED UP button (API call)
                    : (_passengerReadyToStart
                        ? _buildPassengerPickedUpSheet()
                        : _buildArrivedSheet()),     // ride: local toggle then START TRIP
                'picked_up'   => _buildPickedUpSheet(),
                'in_progress' => _buildInProgressSheet(),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ),
        if (widget.job.status == 'arrived' && _passengerReadyToStart)
          Positioned(
            left: 36,
            right: 36,
            bottom: 414,
            child: _TripOverlayBanner(
              icon: Icons.check_rounded,
              background: const Color(0xFFD9E9DA),
              foreground: const Color(0xFF1E7E34),
              message: 'Passenger on board,\nYou can now start the trip.',
            ),
          ),
      ],
    );
  }

  Widget _buildAcceptedSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TripCustomerHeader(
          customerName: widget.job.passengerName ?? 'Passenger',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_outline_rounded, size: 16, color: _kAmber),
              const SizedBox(width: 6),
              Text(
                '4.5',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _TripInfoGridRow(
          leftLabel: 'Trip ID',
          leftValue: _tripCode,
          rightLabel: 'Payment Method',
          rightValue: _paymentMethod,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        _TripInfoGridRow(
          leftLabel: 'Pick up',
          leftValue: widget.job.pickupAddress,
          rightLabel: 'Drop off',
          rightValue: widget.job.destinationAddress,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        _TripInfoGridRow(
          leftLabel: 'Estimated Arrival',
          leftValue: _etaLabel,
          rightLabel: 'Distance',
          rightValue: _distanceLabel,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TripContactAction(
              icon: Icons.call_rounded,
              label: 'Call Customer',
              onTap: widget.onCallPassenger,
            ),
            ValueListenableBuilder<Map<String, int>>(
              valueListenable: ChatNotificationService.instance.unreadCounts,
              builder: (_, counts, __) => _TripContactAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Message',
                onTap: widget.onChatPassenger,
                badge: counts[widget.job.id] ?? 0,
              ),
            ),
          ],
        ),
        _TripMoreDetails(job: widget.job),
        _TripPrimaryButton(
          label: 'START NAVIGATION',
          onPressed: widget.onNavigateToPickup,
        ),
        const SizedBox(height: 10),
        _TripPrimaryButton(
          label: "I'VE ARRIVED",
          loading: _busy,
          onPressed: widget.onArrive != null ? () => _run(widget.onArrive) : null,
          secondary: true,
        ),
      ],
    );
  }

  Widget _buildArrivedSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TripCustomerHeader(
          customerName: widget.job.passengerName ?? 'Passenger',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleAction(
                icon: Icons.call_rounded,
                color: _kAmber,
                onTap: widget.onCallPassenger,
                tooltip: 'Call passenger',
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: Icons.chat_bubble_outline_rounded,
                color: _kAmber,
                onTap: widget.onChatPassenger,
                tooltip: 'Chat with passenger',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _TripInfoGridRow(
          leftLabel: 'Trip ID',
          leftValue: _tripCode,
          rightLabel: 'Payment Method',
          rightValue: _paymentMethod,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        _TripInfoGridRow(
          leftLabel: 'Pick up',
          leftValue: widget.job.pickupAddress,
          rightLabel: 'Drop off',
          rightValue: widget.job.destinationAddress,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 20),
        if (widget.job.bookingType == 'delivery') ...[
          // ── Delivery: payment gate before pickup ──────────────────────────
          if (widget.job.deliveryNeedsPayment) ...[
            _TripNoticeBanner(
              icon: Icons.payments_outlined,
              background: const Color(0xFFF1EBDD),
              foreground: _kAmber,
              message: 'You have arrived at the pickup location.\nCollect payment before picking up the package.',
            ),
            _TripMoreDetails(job: widget.job),
            if (widget.job.isCashPayment) ...[
              _TripPrimaryButton(
                label: 'I HAVE RECEIVED CASH',
                loading: _busy,
                onPressed: () => _run(widget.onConfirmCashPayment),
              ),
            ] else ...[
              // Digital payment — wait for customer to pay in-app
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Waiting for customer to complete payment…',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ] else ...[
            // Payment done — show pickup button
            _TripNoticeBanner(
              icon: Icons.check_circle_outline_rounded,
              background: const Color(0xFFD9E9DA),
              foreground: const Color(0xFF1E7E34),
              message: 'Payment received! Collect the package from the sender.',
            ),
            _TripMoreDetails(job: widget.job),
            _TripPrimaryButton(
              label: 'PICK UP PACKAGE',
              loading: _busy,
              onPressed: () => _run(widget.onPickup),
            ),
          ],
        ] else ...[
          // ── Ride: passenger pickup ────────────────────────────────────────
          _TripNoticeBanner(
            icon: Icons.info_outline_rounded,
            background: const Color(0xFFF1EBDD),
            foreground: _kAmber,
            message: 'You have arrived at the pickup location.\nPlease wait for the customer.',
          ),
          _TripMoreDetails(job: widget.job),
          _TripPrimaryButton(
            label: 'PASSENGER PICKED UP',
            loading: _busy,
            onPressed: () => setState(() => _passengerReadyToStart = true),
          ),
        ],
      ],
    );
  }

  Widget _buildPickedUpSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TripCustomerHeader(
          customerName: widget.job.passengerName ?? 'Customer',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleAction(
                icon: Icons.call_rounded,
                color: _kAmber,
                onTap: widget.onCallPassenger,
                tooltip: 'Call customer',
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: Icons.chat_bubble_outline_rounded,
                color: _kAmber,
                onTap: widget.onChatPassenger,
                tooltip: 'Chat with customer',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _TripInfoGridRow(
          leftLabel: 'Trip ID',
          leftValue: _tripCode,
          rightLabel: 'Payment Method',
          rightValue: _paymentMethod,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        _TripRouteLine(
          label: 'Pick up',
          value: widget.job.pickupAddress,
          trailingIcon: const Icon(Icons.check_rounded, color: Colors.green, size: 22),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        _TripRouteLine(label: 'Drop off', value: widget.job.destinationAddress),
        const SizedBox(height: 18),
        _TripNoticeBanner(
          icon: Icons.inventory_2_rounded,
          background: const Color(0xFFD9E9DA),
          foreground: const Color(0xFF1E7E34),
          message: 'Package collected! Head to the delivery destination.',
        ),
        _TripMoreDetails(job: widget.job),
        _TripPrimaryButton(
          label: 'START DELIVERY',
          loading: _busy,
          onPressed: () => _run(widget.onStart),
        ),
      ],
    );
  }

  Widget _buildPassengerPickedUpSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TripCustomerHeader(
          customerName: widget.job.passengerName ?? 'Passenger',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleAction(
                icon: Icons.call_rounded,
                color: _kAmber,
                onTap: widget.onCallPassenger,
                tooltip: 'Call passenger',
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: Icons.chat_bubble_outline_rounded,
                color: _kAmber,
                onTap: widget.onChatPassenger,
                tooltip: 'Chat with passenger',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _TripInfoGridRow(
          leftLabel: 'Trip ID',
          leftValue: _tripCode,
          rightLabel: 'Payment Method',
          rightValue: _paymentMethod,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        _TripRouteLine(
          label: 'Pick up',
          value: widget.job.pickupAddress,
          trailingIcon: const Icon(
            Icons.check_rounded,
            color: Colors.green,
            size: 22,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        _TripRouteLine(label: 'Drop off', value: widget.job.destinationAddress),
        _TripMoreDetails(job: widget.job),
        _TripPrimaryButton(
          label: widget.job.bookingType == 'delivery'
              ? 'START DELIVERY'
              : 'START TRIP',
          loading: _busy,
          onPressed: () => _run(widget.onStart),
        ),
      ],
    );
  }

  Widget _buildInProgressSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TripCustomerHeader(
          customerName: widget.job.passengerName ?? 'Passenger',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleAction(
                icon: Icons.call_rounded,
                color: _kAmber,
                onTap: widget.onCallPassenger,
                tooltip: 'Call passenger',
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: Icons.chat_bubble_outline_rounded,
                color: _kAmber,
                onTap: widget.onChatPassenger,
                tooltip: 'Chat with passenger',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _TripInfoGridRow(
          leftLabel: 'Trip ID',
          leftValue: _tripCode,
          rightLabel: 'Payment Method',
          rightValue: _paymentMethod,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 26),
        const _TripProgressTracker(),
        _TripMoreDetails(job: widget.job),
        _TripPrimaryButton(
          label: widget.job.bookingType == 'delivery'
              ? 'COMPLETE DELIVERY'
              : 'COMPLETE TRIP',
          loading: _busy,
          onPressed: () => _run(widget.onComplete),
        ),
      ],
    );
  }
}

// ── Expanded trip details (shown when sheet is swiped up) ────────────────────

class _TripMoreDetails extends StatelessWidget {
  const _TripMoreDetails({required this.job});
  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final type = job.bookingType == 'delivery' ? 'Delivery' : 'Ride';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFD8D8D8)),
        const SizedBox(height: 18),
        Row(
          children: [
            _InfoChip(label: 'Type', value: type),
            const SizedBox(width: 12),
            _InfoChip(
              label: 'Fare',
              value: '₦${job.displayFare.toStringAsFixed(0)}',
            ),
            if (job.distanceKm != null) ...[
              const SizedBox(width: 12),
              _InfoChip(
                label: 'Distance',
                value: '${job.distanceKm!.toStringAsFixed(1)} km',
              ),
            ],
          ],
        ),
        if (job.bookingType == 'delivery') ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFD8D8D8)),
          const SizedBox(height: 14),
          if (job.packageDescription != null && job.packageDescription!.isNotEmpty)
            _DeliveryInfoRow(
              icon: Icons.inventory_2_outlined,
              label: 'Package',
              value: job.packageDescription!,
            ),
          if (job.recipientPhone != null && job.recipientPhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DeliveryInfoRow(
              icon: Icons.phone_outlined,
              label: 'Recipient',
              value: job.recipientPhone!,
            ),
          ],
          if (job.senderPhone != null && job.senderPhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DeliveryInfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Sender',
              value: job.senderPhone!,
            ),
          ],
        ],
        if (job.stops.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFD8D8D8)),
          const SizedBox(height: 14),
          Text(
            'Stops (${job.stops.length})',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...job.stops.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: _kAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.address,
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.black87),
                  ),
                ),
              ],
            ),
          )),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}

class _DeliveryInfoRow extends StatelessWidget {
  const _DeliveryInfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: _kAmber),
      const SizedBox(width: 8),
      Text('$label: ',
          style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      Expanded(
        child: Text(value,
            style: AppTextStyles.caption.copyWith(color: Colors.black87)),
      ),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w700, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

// ── Progress tracker ──────────────────────────────────────────────────────────

class _TripProgressTracker extends StatelessWidget {
  const _TripProgressTracker();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const _TripProgressNode(active: true),
            const SizedBox(width: 6),
            const Expanded(child: _TripProgressConnector(active: true)),
            const SizedBox(width: 6),
            const _TripProgressNode(active: true),
            const SizedBox(width: 6),
            const Expanded(child: _TripProgressConnector(active: true)),
            const SizedBox(width: 6),
            const _TripProgressNode(active: true, current: true),
            const SizedBox(width: 6),
            const Expanded(child: _TripProgressConnector(active: false)),
            const SizedBox(width: 6),
            const _TripProgressNode(active: false),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Going to pickup',
              style: AppTextStyles.caption.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Picked Up',
              style: AppTextStyles.caption.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'On the way',
              style: AppTextStyles.caption.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TripProgressNode extends StatelessWidget {
  const _TripProgressNode({required this.active, this.current = false});

  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (current ? const Color(0xFFEBCF8A) : _kAmber)
        : const Color(0xFFE2E2E2);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TripProgressConnector extends StatelessWidget {
  const _TripProgressConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _kAmber : const Color(0xFFE2E2E2);
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: Icon(icon, size: 18, color: Colors.white)),
      ),
    ),
  );
}

class _TripCustomerHeader extends StatelessWidget {
  const _TripCustomerHeader({
    required this.customerName,
    required this.trailing,
  });

  final String customerName;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCDD1D7), width: 1),
          ),
          child: const Center(
            child: Icon(Icons.person, size: 32, color: Color(0xFF6A63FF)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                customerName,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}

class _TripInfoGridRow extends StatelessWidget {
  const _TripInfoGridRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TripInfoCell(label: leftLabel, value: leftValue),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _TripInfoCell(label: rightLabel, value: rightValue),
        ),
      ],
    );
  }
}

class _TripInfoCell extends StatelessWidget {
  const _TripInfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _TripContactAction extends StatelessWidget {
  const _TripContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleAction(icon: icon, color: _kAmber, onTap: onTap, tooltip: label),
            if (badge > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TripPrimaryButton extends StatelessWidget {
  const _TripPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final bg = secondary ? Colors.white : Colors.black;
    final fg = secondary ? Colors.black : Colors.white;
    final border = secondary ? BorderSide(color: Colors.black.withValues(alpha: 0.3)) : BorderSide.none;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.65),
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

class _TripNoticeBanner extends StatelessWidget {
  const _TripNoticeBanner({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.message,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF6A655E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripOverlayBanner extends StatelessWidget {
  const _TripOverlayBanner({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.message,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyLarge.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripRouteLine extends StatelessWidget {
  const _TripRouteLine({
    required this.label,
    required this.value,
    this.trailingIcon,
  });

  final String label;
  final String value;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _TripInfoCell(label: label, value: value),
        ),
        if (trailingIcon != null) ...[const SizedBox(width: 12), trailingIcon!],
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
  double _driverBearing = 0;
  StreamSubscription<Position>? _posSub;
  Timer? _animTimer;

  // Approach route (driver → pickup via real roads)
  List<LatLng> _approachRoute = [];
  LatLng? _lastApproachFetch;
  static const double _kRefetchM = 120;

  // Custom person icon for pickup marker
  BitmapDescriptor? _personIcon;
  static BitmapDescriptor? _cachedPersonIcon;

  // Reload button state
  bool _reloading = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadFuture = ensureGoogleMapsJsLoaded(apiKey: AppConfig.googleMapsKey);
    }
    _initDriverPos();
    _buildRoute(widget.job);
    if (!kIsWeb) _startPosStream();
    _loadPersonIcon();
    // Seed approach route from initial driver position
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchApproachRoute());
  }

  Future<void> _loadPersonIcon() async {
    if (_cachedPersonIcon != null) {
      setState(() => _personIcon = _cachedPersonIcon);
      return;
    }
    try {
      final icon = await _buildCircleMarkerIcon(
        Icons.directions_walk,
        bg: const Color(0xFF34A853), // Google green for customer/pickup
      );
      _cachedPersonIcon = icon;
      if (mounted) setState(() => _personIcon = icon);
    } catch (e, st) {
      debugPrint('[PersonIcon] failed to build person marker icon: $e\n$st');
    }
  }

  Future<void> _reloadLocation() async {
    if (_reloading) return;
    if (mounted) setState(() => _reloading = true);
    try {
      await LocationService.instance.refreshPosition();
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  /// Builds a circular bitmap marker from a Material icon.
  /// Renders at physical-pixel resolution and passes imagePixelRatio so
  /// google_maps_flutter scales it to the correct logical size on screen.
  static Future<BitmapDescriptor> _buildCircleMarkerIcon(
    IconData icon, {
    Color bg = const Color(0xFF34A853),
    double size = 40, // logical pixels
  }) async {
    final dpr =
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    final physSize = (size * dpr).roundToDouble();
    final r = physSize / 2;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);

    canvas.drawCircle(Offset(r, r), r, Paint()..color = bg);
    canvas.drawCircle(
      Offset(r, r),
      r - dpr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * dpr,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: physSize * 0.52,
          fontFamily: icon.fontFamily,
          color: Colors.white,
          package: icon.fontPackage,
        ),
      )
      ..layout();
    tp.paint(
      canvas,
      Offset((physSize - tp.width) / 2, (physSize - tp.height) / 2),
    );
    final img = await rec.endRecording().toImage(
      physSize.toInt(),
      physSize.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }

  @override
  void didUpdateWidget(_TripMapView old) {
    super.didUpdateWidget(old);
    // Rebuild only when route-relevant fields change; status change alone is fine
    final changed =
        widget.job.id != old.job.id ||
        widget.job.routePolyline != old.job.routePolyline ||
        widget.job.pickupLat != old.job.pickupLat ||
        widget.job.destinationLat != old.job.destinationLat;
    if (changed) {
      _buildRoute(widget.job);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _animTimer?.cancel();
    _ctrl?.dispose();
    _ctrl =
        null; // prevent use-after-dispose in pending Future.delayed callbacks
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
    _fetchApproachRoute();
  }

  Future<void> _fetchApproachRoute() async {
    final j = widget.job;
    final dPos = _driverPos;
    final pLat = j.pickupLat, pLng = j.pickupLng;
    final isApproaching = j.status == 'accepted' || j.status == 'arrived';
    debugPrint(
      '[Approach] status=${j.status} isApproaching=$isApproaching dPos=$dPos pLat=$pLat',
    );
    if (!isApproaching || dPos == null || pLat == null) return;

    final last = _lastApproachFetch;
    if (last != null && _haversineM(last, dPos) < _kRefetchM) return;

    _lastApproachFetch = dPos;
    final pickup = LatLng(pLat, pLng!);
    debugPrint('[Approach] fetching route: $dPos → $pickup');
    final pts = await MapsService.getDirectionsRoute(dPos, pickup);
    debugPrint(
      '[Approach] got ${pts.length} points (${pts.length == 2 ? "straight line fallback" : "real route"})',
    );
    if (mounted) setState(() => _approachRoute = pts);
  }

  static double _haversineM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final s1 = math.sin(dLat / 2), s2 = math.sin(dLng / 2);
    return r *
        2 *
        math.asin(math.sqrt(s1 * s1 + math.cos(la1) * math.cos(la2) * s2 * s2));
  }

  void _animateTo(LatLng target) {
    _animTimer?.cancel();
    final from = _driverPos ?? target;
    int step = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      step++;
      final frac = (step / 20).clamp(0.0, 1.0);
      setState(() {
        _driverPos = LatLng(
          from.latitude + (target.latitude - from.latitude) * frac,
          from.longitude + (target.longitude - from.longitude) * frac,
        );
      });
      if (step >= 20) t.cancel();
    });
  }

  static double _bearingDeg(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ── Route ───────────────────────────────────────────────────────────────────

  void _buildRoute(JobModel job) {
    final pLat = job.pickupLat, pLng = job.pickupLng;
    final dLat = job.destinationLat, dLng = job.destinationLng;
    if (pLat == null || dLat == null) return;

    final pickup = LatLng(pLat, pLng!);
    final dest = LatLng(dLat, dLng!);

    final List<LatLng> pts = (job.routePolyline?.isNotEmpty == true)
        ? MapsService.decodePolylineBest(
            job.routePolyline!,
            origin: pickup,
            destination: dest,
          )
        : [pickup, dest];

    final allPts = <LatLng>[...pts, ?_driverPos];
    final bounds = MapsService.boundsFromPoints(allPts);

    setState(() {
      _routePts = pts;
      _bounds = bounds;
    });

    if (_ctrl != null) _fitCamera();
  }

  void _fitCamera() {
    if (!mounted || _ctrl == null || _bounds == null) return;
    final v = ++_camVersion;
    final sw = _bounds!.southwest;
    final ne = _bounds!.northeast;
    // Skip if points are too close together (prevents over-zooming)
    if ((ne.latitude - sw.latitude).abs() < 0.0002 &&
        (ne.longitude - sw.longitude).abs() < 0.0002) {
      return;
    }
    try {
      _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 72)).then((
        _,
      ) {
        if (v != _camVersion) return;
      });
    } catch (_) {
      _ctrl = null;
    }
  }

  // ── Map data ────────────────────────────────────────────────────────────────

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final j = widget.job;

    if (j.pickupLat != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(j.pickupLat!, j.pickupLng!),
          icon:
              _personIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Passenger pickup',
            snippet: '${j.pickupAddress}  •  tap to copy location',
            onTap: _copyPickupLocation,
          ),
        ),
      );
    }

    if (j.destinationLat != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(j.destinationLat!, j.destinationLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: j.destinationAddress,
          ),
        ),
      );
    }

    // Animated driver pin (flat, rotated toward heading)
    if (_driverPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          rotation: _driverBearing,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
        ),
      );
    }

    return markers;
  }

  Set<Polyline> get _polylines {
    final lines = <Polyline>{};
    final j = widget.job;

    // ── Full route (pickup → destination) ────────────────────────────────────
    if (_routePts.length >= 2) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePts,
          color: _kAmber,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    // ── Approach line (driver current pos → pickup) ───────────────────────────
    // Shown when driver accepted but hasn't started the trip yet (status:
    // 'accepted' or 'arrived'). A dashed amber line so it's visually distinct.
    final dPos = _driverPos;
    final pLat = j.pickupLat, pLng = j.pickupLng;
    final isApproaching = j.status == 'accepted' || j.status == 'arrived';
    if (dPos != null && pLat != null && pLng != null && isApproaching) {
      final pickup = LatLng(pLat, pLng);
      final approachPts = _approachRoute.isNotEmpty
          ? _approachRoute
          : [dPos, pickup];
      lines.add(
        Polyline(
          polylineId: const PolylineId('approach'),
          points: approachPts,
          color: _kAmber.withValues(alpha: 0.75),
          width: 4,
          patterns: [PatternItem.dot, PatternItem.gap(8)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    return lines;
  }

  void _copyPickupLocation() {
    final j = widget.job;
    final pLat = j.pickupLat, pLng = j.pickupLng;
    if (pLat == null) return;
    final text = '${pLat.toStringAsFixed(6)}, ${pLng!.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pickup location copied: ${j.pickupAddress}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openInGoogleMaps() {
    final j = widget.job;
    final pLat = j.pickupLat, pLng = j.pickupLng;
    if (pLat == null) return;
    final dPos = _driverPos;
    final uri = dPos != null
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&origin=${dPos.latitude},${dPos.longitude}'
            '&destination=$pLat,$pLng'
            '&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1'
            '&query=$pLat,$pLng',
          );
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  LatLng get _initialTarget {
    if (_bounds != null) {
      final sw = _bounds!.southwest;
      final ne = _bounds!.northeast;
      return LatLng(
        (sw.latitude + ne.latitude) / 2,
        (sw.longitude + ne.longitude) / 2,
      );
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
    final j = widget.job;

    final baseMapWidget = GoogleMap(
      initialCameraPosition: CameraPosition(target: _initialTarget, zoom: 13),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      onMapCreated: (ctrl) {
        _ctrl = ctrl;
        Future.delayed(const Duration(milliseconds: 300), _fitCamera);
      },
    );
    Widget mapWidget = baseMapWidget;

    if (kIsWeb) {
      mapWidget = FutureBuilder<bool>(
        future: _loadFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done ||
              snap.data != true) {
            return Container(
              color: AppColors.surface,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          return baseMapWidget;
        },
      );
    }

    return Stack(
      children: [
        mapWidget,
        // ── Map overlay buttons ────────────────────────────────────────────
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (j.pickupLat != null) ...[
                _MapOverlayChip(
                  icon: Icons.map_outlined,
                  label: 'Maps',
                  onTap: _openInGoogleMaps,
                ),
                const SizedBox(height: 8),
                _MapOverlayChip(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: _copyPickupLocation,
                ),
                const SizedBox(height: 8),
              ],
              _MapOverlayChip(
                icon: _reloading
                    ? Icons.sync_rounded
                    : Icons.my_location_rounded,
                label: _reloading ? '...' : 'Reload',
                onTap: _reloadLocation,
              ),
            ],
          ),
        ),
      ],
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
  final JobModel job;
  final bool processing;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final method = (job.paymentMethod ?? 'Cash').trim();

    return _TripFlowScreen(
      map: _TripMapView(job: job),
      child: CollapsibleMapSheet(
        backgroundColor: const Color(0xFFF4F4F4),
        initialChildSize: 0.58,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Collect Payment',
              style: AppTextStyles.h3.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Collect the trip fare from the customer to\ncomplete this trip.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 34),
            Text(
              _money(job.displayFare),
              style: AppTextStyles.h1.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 34),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EBDD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          method.isEmpty
                              ? 'Cash'
                              : method[0].toUpperCase() + method.substring(1),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kAmber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      method.toLowerCase() == 'cash'
                          ? Icons.payments_outlined
                          : Icons.credit_card_outlined,
                      color: _kAmber,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            _TripPrimaryButton(
              label: 'PAYMENT RECEIVED',
              loading: processing,
              onPressed: onConfirm,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _PaymentDetailRow extends StatelessWidget {
  const _PaymentDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: const Color(0xFFA8A8A8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentDetailRouteRow extends StatelessWidget {
  const _PaymentDetailRouteRow({
    required this.label,
    required this.from,
    required this.to,
  });

  final String label;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: const Color(0xFFA8A8A8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExpandableAddressText(
                text: from,
                textStyle: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.arrow_right_alt_rounded,
                    size: 22,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _ExpandableAddressText(
                      text: to,
                      textStyle: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandableAddressText extends StatefulWidget {
  const _ExpandableAddressText({required this.text, required this.textStyle});

  final String text;
  final TextStyle textStyle;

  @override
  State<_ExpandableAddressText> createState() => _ExpandableAddressTextState();
}

class _ExpandableAddressTextState extends State<_ExpandableAddressText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    final shouldCollapse = text.length > 52;
    if (!shouldCollapse) {
      return Text(text, style: widget.textStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: widget.textStyle,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Read less' : 'Read more',
            style: AppTextStyles.bodySmall.copyWith(
              color: _kAmber,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
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
    final now = DateTime.now();
    final todayCompleted = jobs.where((j) {
      if (!j.isCompleted || j.completedAt == null) return false;
      final d = DateTime.tryParse(j.completedAt!);
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    final todayEarnings = todayCompleted.fold<double>(
      0,
      (s, j) => s + j.displayFare,
    );

    final bottom = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 84 + bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(34, 36, 34, 30),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4F4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trip Closed Successfully',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your trip has been completed and added to\nyour earnings.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _SuccessMetricRow(
                        label: "Today's Earning",
                        value: _money(todayEarnings),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFD9D9D9)),
                      const SizedBox(height: 16),
                      _SuccessMetricRow(
                        label: 'Completed Trips',
                        value: '${todayCompleted.length}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                _TripPrimaryButton(
                  label: 'BACK TO DASHBOARD',
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.invalidate(driverJobsProvider);
                    ref.invalidate(driverHistoryProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessMetricRow extends StatelessWidget {
  const _SuccessMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 1 — EARNINGS
// ═══════════════════════════════════════════════════════════════════════════════

class _EarningsTab extends ConsumerWidget {
  const _EarningsTab();

  double _earnFor(List<JobModel> jobs, DateTime? from, DateTime? to) => jobs
      .where((j) {
        if (!j.isCompleted || j.completedAt == null) return false;
        final d = DateTime.tryParse(j.completedAt!);
        if (d == null) return false;
        if (from != null && d.isBefore(from)) return false;
        if (to != null && d.isAfter(to)) return false;
        return true;
      })
      .fold(0, (s, j) => s + j.displayFare);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyJobs = ref.watch(driverHistoryProvider).valueOrNull ?? [];
    final activeJobs = ref.watch(driverJobsProvider).valueOrNull ?? [];
    final jobs = historyJobs.where((j) => j.isCompleted).toList()
      ..sort(
        (a, b) => _sortDate(
          b.completedAt ?? b.createdAt,
        ).compareTo(_sortDate(a.completedAt ?? a.createdAt)),
      );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final wkAgo = now.subtract(const Duration(days: 7));
    final thisWeek = _earnFor(jobs, wkAgo, null);
    final todayEarnings = _earnFor(jobs, today, null);
    final pendingPayments = activeJobs
        .where((j) => j.status == 'payment_pending')
        .fold<double>(0, (sum, j) => sum + j.displayFare);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 128),
      children: [
        Text(
          'Earning Overview',
          style: AppTextStyles.h3.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 22,
          mainAxisSpacing: 22,
          childAspectRatio: 1.05,
          children: [
            _OverviewMetricCard(
              label: 'Today Earnings',
              value: _money(todayEarnings),
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 19,
                color: Colors.white,
              ),
            ),
            _OverviewMetricCard(
              label: 'This Week',
              value: _money(thisWeek),
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 19,
                color: Colors.white,
              ),
            ),
            _OverviewMetricCard(
              label: 'Completed Trips',
              value: '${jobs.length}',
              icon: SvgPicture.asset(
                AppAssets.offlineTripsIcon,
                width: 20,
                height: 20,
              ),
            ),
            _OverviewMetricCard(
              label: 'Pending Payments',
              value: _money(pendingPayments),
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 19,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Earnings',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'See All',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (jobs.isEmpty)
          _EmptyPanel(
            icon: Icons.account_balance_wallet_outlined,
            label: 'No earnings yet.',
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: List.generate(math.min(3, jobs.length), (index) {
                final job = jobs[index];
                return _RecentEarningTile(
                  job: job,
                  last: index == math.min(3, jobs.length) - 1,
                );
              }),
            ),
          ),
      ],
    );
  }

  DateTime _sortDate(String? iso) =>
      DateTime.tryParse(iso ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 2 — HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

enum _HistoryFilter { all, completed, cancelled, pending }

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final historyJobs = ref.watch(driverHistoryProvider).valueOrNull ?? [];
    final activeJobs = ref.watch(driverJobsProvider).valueOrNull ?? [];

    final combined = <String, JobModel>{};
    for (final job in [...historyJobs, ...activeJobs]) {
      combined[job.id] = job;
    }
    final jobs = combined.values.toList()
      ..sort(
        (a, b) => _sortDate(
          b.completedAt ?? b.createdAt,
        ).compareTo(_sortDate(a.completedAt ?? a.createdAt)),
      );

    final filtered = jobs.where((job) {
      switch (_filter) {
        case _HistoryFilter.completed:
          return job.isCompleted;
        case _HistoryFilter.cancelled:
          return job.isCancelled;
        case _HistoryFilter.pending:
          return !job.isCompleted && !job.isCancelled;
        case _HistoryFilter.all:
          return true;
      }
    }).toList();

    return RefreshIndicator(
      color: _kAmber,
      onRefresh: () async {
        ref.invalidate(driverHistoryProvider);
        ref.invalidate(driverJobsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 128),
        children: [
          Text(
            'Trip History',
            style: AppTextStyles.h3.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _HistoryFilterChip(
                  label: 'ALL',
                  selected: _filter == _HistoryFilter.all,
                  onTap: () => setState(() => _filter = _HistoryFilter.all),
                ),
                const SizedBox(width: 14),
                _HistoryFilterChip(
                  label: 'COMPLETED',
                  selected: _filter == _HistoryFilter.completed,
                  onTap: () =>
                      setState(() => _filter = _HistoryFilter.completed),
                ),
                const SizedBox(width: 14),
                _HistoryFilterChip(
                  label: 'CANCELED',
                  selected: _filter == _HistoryFilter.cancelled,
                  onTap: () =>
                      setState(() => _filter = _HistoryFilter.cancelled),
                ),
                const SizedBox(width: 14),
                _HistoryFilterChip(
                  label: 'PENDING',
                  selected: _filter == _HistoryFilter.pending,
                  onTap: () => setState(() => _filter = _HistoryFilter.pending),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          if (filtered.isEmpty)
            _EmptyPanel(icon: Icons.history_rounded, label: 'No trips found.')
          else
            Column(
              children: List.generate(filtered.length, (index) {
                final job = filtered[index];
                return _HistoryTripTile(
                  job: job,
                  last: index == filtered.length - 1,
                  onTap: () => _openTripDetails(job),
                );
              }),
            ),
        ],
      ),
    );
  }

  DateTime _sortDate(String? iso) =>
      DateTime.tryParse(iso ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _openTripDetails(JobModel job) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistoryTripDetailsSheet(job: job),
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final Widget icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: _kAmber,
            shape: BoxShape.circle,
          ),
          child: Center(child: icon),
        ),
        const SizedBox(height: 20),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _RecentEarningTile extends StatelessWidget {
  const _RecentEarningTile({required this.job, required this.last});

  final JobModel job;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final method = (job.paymentMethod ?? 'Cash').trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFD8D8D8))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HistoryAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.passengerName ?? 'Passenger',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job.pickupAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_right_alt_rounded,
                      size: 22,
                      color: Color(0xFF6A6A6A),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.destinationAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(job.displayFare),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                method.isEmpty ? 'Cash' : method,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFD4D4D4),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? Colors.white : const Color(0xFF6A6A6A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HistoryTripTile extends StatelessWidget {
  const _HistoryTripTile({
    required this.job,
    required this.last,
    required this.onTap,
  });

  final JobModel job;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateText = _friendlyDate(job.completedAt ?? job.createdAt);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFD8D8D8))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HistoryAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.passengerName ?? 'Passenger',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.pickupAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_right_alt_rounded,
                        size: 22,
                        color: Color(0xFF6A6A6A),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(job.displayFare),
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _HistoryStatusPill(status: job.status),
                const SizedBox(height: 10),
                Text(
                  dateText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) {
      return '';
    }
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return isToday
        ? 'Today, $hour:$minute $suffix'
        : '${dt.day}/${dt.month}/${dt.year}, $hour:$minute $suffix';
  }
}

class _HistoryAvatar extends StatelessWidget {
  const _HistoryAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFCBD1D9), width: 1),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 34, color: Color(0xFF6A63FF)),
      ),
    );
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      'completed' => (
        'COMPLETED',
        const Color(0xFFD8EBD3),
        const Color(0xFF2F8A29),
      ),
      'cancelled' => ('CANCELED', const Color(0xFFF7D9D9), Colors.red),
      _ => ('PENDING', const Color(0xFFF1E5B8), const Color(0xFF9C6A00)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryTripDetailsSheet extends StatelessWidget {
  const _HistoryTripDetailsSheet({required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final tripCode = job.bookingRef.isNotEmpty
        ? '#${job.bookingRef}'
        : '#${job.id.substring(0, 8).toUpperCase()}';
    final method = (job.paymentMethod ?? 'Cash').trim();
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: EdgeInsets.fromLTRB(24, 18, 24, bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5D5D5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Trip Details',
              style: AppTextStyles.h3.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            _PaymentDetailRow(
              label: 'Customer',
              value: job.passengerName ?? 'Passenger',
            ),
            const SizedBox(height: 20),
            _PaymentDetailRow(label: 'Trip ID', value: tripCode),
            const SizedBox(height: 20),
            _PaymentDetailRouteRow(
              label: 'Trip Route',
              from: job.pickupAddress,
              to: job.destinationAddress,
            ),
            const SizedBox(height: 20),
            _PaymentDetailRow(
              label: 'Trip Fare',
              value: _money(job.displayFare),
            ),
            const SizedBox(height: 20),
            _PaymentDetailRow(
              label: 'Payment Method',
              value: method.isEmpty
                  ? 'Cash'
                  : method[0].toUpperCase() + method.substring(1),
            ),
            const SizedBox(height: 20),
            _PaymentDetailRow(
              label: 'Status',
              value: job.status.replaceAll('_', ' '),
            ),
            if (job.cancellationReason != null &&
                job.cancellationReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              _PaymentDetailRow(
                label: 'Reason',
                value: job.cancellationReason!.trim(),
              ),
            ],
            const SizedBox(height: 28),
            _TripPrimaryButton(
              label: 'CLOSE',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.disabled),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compact chip-style overlay button shown on top of the map ─────────────────

class _MapOverlayChip extends StatelessWidget {
  const _MapOverlayChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
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
  final String title;
  final String subtitle;
  final List<String> reasons;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;
  bool _isOther = false;
  final _otherCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _effectiveReason {
    if (_isOther) {
      final t = _otherCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context).viewInsets.bottom +
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
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(widget.title, style: AppTextStyles.h4.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Predefined reasons
          ...widget.reasons.map(
            (r) => _ReasonTile(
              label: r,
              selected: !_isOther && _selected == r,
              onTap: () => setState(() {
                _selected = r;
                _isOther = false;
              }),
            ),
          ),

          // "Other" option
          _ReasonTile(
            label: 'Other (please specify)',
            selected: _isOther,
            onTap: () => setState(() {
              _isOther = true;
              _selected = null;
            }),
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
                        hintStyle: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Confirm Cancel',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
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
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                'Keep Trip',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
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
  final String label;
  final bool selected;
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
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.error : AppColors.divider,
                width: 2,
              ),
              color: selected ? AppColors.error : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
