import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_bottom_drawer.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginMethod { phone, email }

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _contactCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
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

  bool get _canSubmit => _contactCtrl.text.trim().isNotEmpty && _passCtrl.text.isNotEmpty && !_loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = _contactCtrl.text.trim();
      final login = _method == _LoginMethod.phone ? _normalizeNgPhone(raw) : raw.replaceAll(' ', '');
      final user = await ref.read(authRepositoryProvider).login(
        login: login,
        password: _passCtrl.text,
      );
      ref.read(currentUserProvider.notifier).state = user;
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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

  Future<void> _showResetPassword() async {
    await showAppBottomDrawer<void>(
      context: context,
      heightFactor: 0.78,
      child: const _ResetPasswordSheet(),
    );
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _contactCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final carBoxHeight = screenSize.height * 0.50;
    final carBoxWidth = screenSize.width;
    final carTopOverflow = MediaQuery.paddingOf(context).top + (carBoxHeight * 0.08);
    final contentTopPadding =
        (carBoxHeight - carTopOverflow + 24).clamp(0.0, screenSize.height).toDouble();

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
                          AppStrings.loginTitle,
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
                          keyboardType: _method == _LoginMethod.phone ? TextInputType.phone : TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
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
                                        Expanded(child: _EmailSuggestionText(email: s)),
                                      ],
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.80, 0.94, curve: Curves.easeOut),
                        from: const Offset(0, 12),
                        child: AppTextField(
                          controller: _passCtrl,
                          label: AppStrings.password,
                          hint: '••••••••',
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) => setState(() => _error = null),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => context.go(AppRoutes.phone),
                            child: Text(
                              AppStrings.createAccount,
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _showResetPassword,
                            child: Text(
                              AppStrings.forgotPassword,
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      ],
                      const SizedBox(height: 16),
                      _FadeSlide(
                        controller: _introCtrl,
                        interval: const Interval(0.84, 1.00, curve: Curves.easeOut),
                        from: const Offset(0, 14),
                        child: AppButton(
                          label: AppStrings.loginBtn,
                          onPressed: _canSubmit ? _submit : null,
                          enabled: _canSubmit,
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

class _ResetPasswordSheet extends ConsumerStatefulWidget {
  const _ResetPasswordSheet();

  @override
  ConsumerState<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends ConsumerState<_ResetPasswordSheet> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _sending = false;
  bool _saving = false;
  bool _sent = false;
  bool _obscure = true;
  String? _error;

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset code sent. Check your email.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _save() async {
    if (!_sent) return;
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text;
    final conf = _confirmCtrl.text;
    if (code.isEmpty) {
      setState(() => _error = 'Enter the reset code.');
      return;
    }
    if (pass.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != conf) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
        email: email,
        code: code,
        password: pass,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You can log in now.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _saving;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.resetPassword, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            AppTextField(
              controller: _emailCtrl,
              label: AppStrings.emailAddress,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: AppStrings.sendResetCode,
              onPressed: (!busy) ? _sendCode : null,
              enabled: !busy,
            ),
            if (_sent) ...[
              const SizedBox(height: 18),
              AppTextField(
                controller: _codeCtrl,
                label: AppStrings.resetCode,
                hint: '123456',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _passCtrl,
                label: AppStrings.newPassword,
                hint: '••••••••',
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _error = null),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _confirmCtrl,
                label: AppStrings.confirmNewPassword,
                hint: '••••••••',
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: AppStrings.saveNewPassword,
                onPressed: (!busy) ? _save : null,
                enabled: !busy,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
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
                  child: const SizedBox.expand(
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
