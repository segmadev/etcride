import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/config/router.dart';
import '../../data/models/otp_extra.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/loading_overlay.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

enum _LoginMethod { phone, email }

class _PhoneScreenState extends ConsumerState<PhoneScreen> with SingleTickerProviderStateMixin {
  final _contactCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  _LoginMethod _method = _LoginMethod.phone;
  List<String> _emailSuggestions = const [];
  late final AnimationController _introCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _contactCtrl.clear();
  }

  bool get _isValid {
    final v = _contactCtrl.text.trim().replaceAll(' ', '');
    if (v.isEmpty) return false;
    if (_method == _LoginMethod.email) {
      return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
    }
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v);
  }

  Future<void> _continue() async {
    if (!_isValid) return;
    final raw = _contactCtrl.text.trim().replaceAll(' ', '');
    final contact = _method == _LoginMethod.phone ? _normalizeNgPhone(raw) : raw;

    setState(() { _loading = true; _error = null; });
    try {
      final contactType = await ref.read(authRepositoryProvider).sendOtp(contact);
      if (!mounted) return;
      context.push(
        AppRoutes.otp,
        extra: OtpExtra(contact: contact, contactType: contactType),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onContactChanged(String v) {
    setState(() {
      _error = null;
      _emailSuggestions = _method == _LoginMethod.email ? _buildEmailSuggestions(v.trim()) : const [];
    });
  }

  List<String> _buildEmailSuggestions(String raw) {
    final v = raw.replaceAll(' ', '');
    final at = v.indexOf('@');
    if (at < 1) return const [];
    final local = v.substring(0, at);
    if (local.isEmpty) return const [];
    final domainPart = v.substring(at + 1).toLowerCase();
    final domains = const ['gmail.com', 'outlook.com', 'yahoo.com', 'icloud.com', 'mail.com'];
    final filtered = domains.where((d) => d.startsWith(domainPart)).take(5).toList();
    if (filtered.isEmpty) return const [];
    if (domainPart.contains('.')) return const [];
    return filtered.map((d) => '$local@$d').toList();
  }

  void _applyEmailSuggestion(String v) {
    _contactCtrl.text = v;
    _contactCtrl.selection = TextSelection.collapsed(offset: v.length);
    setState(() => _emailSuggestions = const []);
  }

  String _normalizeNgPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('234')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+234$digits';
  }

  Widget _nigeriaFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 22,
        height: 22,
        child: _EmbeddedPngFromSvgAsset(
          assetPath: AppAssets.nigeriaFlag,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _methodTabs() {
    final isPhone = _method == _LoginMethod.phone;
    Widget tab(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.textPrimary : AppColors.inputFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          tab('Phone', isPhone, () {
            if (_method == _LoginMethod.phone) return;
            setState(() {
              _method = _LoginMethod.phone;
              _emailSuggestions = const [];
              _contactCtrl.clear();
              _error = null;
            });
          }),
          const SizedBox(width: 6),
          tab('Email', !isPhone, () {
            if (_method == _LoginMethod.email) return;
            setState(() {
              _method = _LoginMethod.email;
              _emailSuggestions = const [];
              _contactCtrl.clear();
              _error = null;
            });
          }),
        ],
      ),
    );
  }

  @override
  void dispose() { _introCtrl.dispose(); _contactCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final carBoxHeight = screenSize.height * 0.50;
    final carBoxWidth = screenSize.width;
    final carTopOverflow = MediaQuery.paddingOf(context).top + (carBoxHeight * 0.08);
    final contentTopPadding = (carBoxHeight - carTopOverflow + 24).clamp(0.0, screenSize.height).toDouble();

    return LoadingOverlay.wrap(
      loading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -carTopOverflow,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: SizedBox(
                    height: carBoxHeight,
                    child: Center(
                      child: SizedBox(
                        width: carBoxWidth,
                        height: carBoxHeight,
                        child: _IntroCar(
                          controller: _introCtrl,
                          height: carBoxHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, contentTopPadding, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.62, 0.76, curve: Curves.easeOut),
                        from: const Offset(0, 10),
                        child: Text(
                          AppStrings.startJourney,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.70, 0.82, curve: Curves.easeOut),
                        from: const Offset(0, 10),
                        child: Text(
                          AppStrings.startJourneySub,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 36),

                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.74, 0.88, curve: Curves.easeOut),
                        from: const Offset(0, 12),
                        child: _methodTabs(),
                      ),
                      const SizedBox(height: 16),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.78, 0.90, curve: Curves.easeOut),
                        from: const Offset(0, 12),
                        child: AppTextField(
                          controller: _contactCtrl,
                          label: _method == _LoginMethod.phone ? AppStrings.phoneNumber : AppStrings.emailAddress,
                          hint: _method == _LoginMethod.phone ? '8123456789' : 'you@example.com',
                          keyboardType: _method == _LoginMethod.phone
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          inputFormatters: _method == _LoginMethod.phone
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : null,
                          prefixIcon: _method == _LoginMethod.phone
                              ? SizedBox(
                                  width: 92,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12, right: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _nigeriaFlag(),
                                        const SizedBox(width: 8),
                                        Text('+234', style: AppTextStyles.bodyMedium),
                                      ],
                                    ),
                                  ),
                                )
                              : null,
                          prefixIconConstraints: _method == _LoginMethod.phone
                              ? const BoxConstraints(minWidth: 92, minHeight: 48)
                              : null,
                          onChanged: _onContactChanged,
                          onSubmitted: (_) => _continue(),
                        ),
                      ),
                      if (_method == _LoginMethod.email && _emailSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: const [
                              BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6)),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (final s in _emailSuggestions)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _applyEmailSuggestion(s),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.textHint),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _EmailSuggestionText(
                                            email: s,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      ],
                      const SizedBox(height: 32),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.84, 1.00, curve: Curves.easeOut),
                        from: const Offset(0, 14),
                        child: AppButton(
                          label: AppStrings.continueBtn,
                          onPressed: _isValid && !_loading ? _continue : null,
                          enabled: _isValid && !_loading,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.90, 1.00, curve: Curves.easeOut),
                        from: const Offset(0, 10),
                        child: Center(
                          child: Text(
                            AppStrings.otpSentNote,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppStrings.alreadyHaveAccount,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => context.push(AppRoutes.login),
                              child: Text(
                                AppStrings.loginLink,
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailSuggestionText extends StatelessWidget {
  const _EmailSuggestionText({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final at = email.indexOf('@');
    if (at < 0) {
      return Text(email, style: AppTextStyles.bodyMedium);
    }
    final local = email.substring(0, at + 1);
    final domain = email.substring(at + 1);
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        children: [
          TextSpan(text: local),
          TextSpan(
            text: domain,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({
    required this.controller,
    required this.interval,
    required this.child,
    this.from = const Offset(0, 12),
  });

  final AnimationController controller;
  final Interval interval;
  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        return Opacity(
          opacity: t.value,
          child: Transform.translate(
            offset: Offset(from.dx * (1 - t.value), from.dy * (1 - t.value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _IntroCar extends StatelessWidget {
  const _IntroCar({
    required this.controller,
    required this.height,
  });

  final AnimationController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final entry = CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.46, curve: Curves.easeOutCubic));
    final settle = CurvedAnimation(parent: controller, curve: const Interval(0.38, 0.62, curve: Curves.easeOutBack));

    final baseY = Tween<double>(begin: -height * 0.18, end: 0).animate(entry);
    final scale = Tween<double>(begin: 1.35, end: 1.5).animate(settle);
    final settleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 55),
    ]).animate(CurvedAnimation(parent: controller, curve: const Interval(0.44, 0.66)));

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final trailOpacity = (1 - entry.value).clamp(0.0, 1.0) * 0.18;

          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                child: Opacity(
                  opacity: trailOpacity,
                  child: Container(
                    width: 160,
                    height: height,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x22000000),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, baseY.value + settleY.value),
                child: Transform.scale(
                  scale: scale.value,
                  child: SizedBox.expand(
                    child: _EmbeddedPngFromSvgAsset(
                      assetPath: AppAssets.carLogin,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmbeddedPngFromSvgAsset extends StatelessWidget {
  const _EmbeddedPngFromSvgAsset({
    required this.assetPath,
    this.fit = BoxFit.cover,
  });

  final String assetPath;
  final BoxFit fit;

  static final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> _load() {
    return _cache.putIfAbsent(assetPath, () async {
      final svg = await rootBundle.loadString(assetPath);
      final match = RegExp(r'data:image\/png;base64,([^"]+)').firstMatch(svg);
      if (match == null) throw const FormatException('No embedded PNG found.');
      return base64Decode(match.group(1)!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Image.memory(snap.data!, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
