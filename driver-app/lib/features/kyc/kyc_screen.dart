import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/pre_dashboard_account_menu.dart';

const _experienceOptions = [
  'Less than 1 year',
  '1 - 2 years',
  '3 - 5 years',
  '5+ years',
];

const _fieldStroke = Color(0xFFD9D9D9);
const _uploadTrack = Color(0x40D9D9D9);
const _uploadSuccess = Color(0xFF52C64C);
const _uploadError = Color(0xFFFF5100);

enum _UploadKind { licenseFront, licenseBack, profilePhoto }

enum _UploadStatus { empty, uploading, success, error }

class _UploadValue {
  const _UploadValue({
    this.file,
    this.bytes,
    this.status = _UploadStatus.empty,
    this.progress = 0,
    this.error,
  });

  final XFile? file;
  final Uint8List? bytes;
  final _UploadStatus status;
  final double progress;
  final String? error;

  bool get isReady => status == _UploadStatus.success && file != null && bytes != null;

  _UploadValue copyWith({
    XFile? file,
    Uint8List? bytes,
    _UploadStatus? status,
    double? progress,
    String? error,
    bool clearFile = false,
    bool clearBytes = false,
    bool clearError = false,
  }) {
    return _UploadValue(
      file: clearFile ? null : file ?? this.file,
      bytes: clearBytes ? null : bytes ?? this.bytes,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class DriverKycScreen extends ConsumerStatefulWidget {
  const DriverKycScreen({super.key});

  @override
  ConsumerState<DriverKycScreen> createState() => _DriverKycScreenState();
}

class _DriverKycScreenState extends ConsumerState<DriverKycScreen> {
  final ImagePicker _picker = ImagePicker();

  _UploadValue _licenseFront = const _UploadValue();
  _UploadValue _licenseBack = const _UploadValue();
  _UploadValue _profilePhoto = const _UploadValue();
  String? _selectedExperience;
  bool _submitting = false;
  bool _rejected = false;
  String? _rejectionReason;
  String? _error;

  @override
  void initState() {
    super.initState();
    final driver = ref.read(currentDriverProvider);
    _rejected = driver?.isKycRejected ?? false;
    _rejectionReason = driver?.kycNote?.trim();
  }

  _UploadValue _uploadFor(_UploadKind kind) {
    return switch (kind) {
      _UploadKind.licenseFront => _licenseFront,
      _UploadKind.licenseBack => _licenseBack,
      _UploadKind.profilePhoto => _profilePhoto,
    };
  }

  void _setUpload(_UploadKind kind, _UploadValue value) {
    setState(() {
      if (kind == _UploadKind.licenseFront) {
        _licenseFront = value;
      } else if (kind == _UploadKind.licenseBack) {
        _licenseBack = value;
      } else {
        _profilePhoto = value;
      }
    });
  }

  String _titleFor(_UploadKind kind) {
    return switch (kind) {
      _UploadKind.licenseFront => "Driver's License",
      _UploadKind.licenseBack => "Driver's License Back",
      _UploadKind.profilePhoto => 'Profile Photo',
    };
  }

  String _helperFor(_UploadKind kind) {
    return switch (kind) {
      _UploadKind.licenseFront =>
        'Upload the front of your valid driver license. Make sure all details are visible.',
      _UploadKind.licenseBack =>
        'Upload the back of your driver license. Avoid blur, glare, or cropped edges.',
      _UploadKind.profilePhoto =>
        'Use a clear photo of your face. This becomes your driver profile picture.',
    };
  }

  bool get _canSubmit {
    return _licenseFront.isReady &&
        _licenseBack.isReady &&
        _profilePhoto.isReady &&
        (_selectedExperience?.isNotEmpty ?? false) &&
        !_submitting;
  }

  Future<void> _showSourceSheet(_UploadKind kind) async {
    if (_submitting) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Upload ${_titleFor(kind)}', style: AppTextStyles.h3),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to add this photo.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(kind, ImageSource.camera);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(kind, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(_UploadKind kind, ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null || !mounted) {
      return;
    }

    final name = file.name.toLowerCase();
    if (!(name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp'))) {
      _setUpload(
        kind,
        const _UploadValue(
          status: _UploadStatus.error,
          progress: 1,
          error: 'Unsupported format. Use JPG, PNG, or WEBP.',
        ),
      );
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _setUpload(
        kind,
        _UploadValue(
          file: file,
          bytes: bytes,
          status: _UploadStatus.error,
          progress: 1,
          error: 'File too large. Max size is 5MB.',
        ),
      );
      return;
    }

    _setUpload(
      kind,
      _UploadValue(
        file: file,
        bytes: bytes,
        status: _UploadStatus.uploading,
        progress: 0.12,
      ),
    );

    for (final progress in [0.32, 0.56, 0.78, 1.0]) {
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted) {
        return;
      }
      final current = _uploadFor(kind);
      _setUpload(
        kind,
        current.copyWith(
          file: file,
          bytes: bytes,
          status: progress >= 1 ? _UploadStatus.success : _UploadStatus.uploading,
          progress: progress,
          clearError: true,
        ),
      );
    }
  }

  void _deleteUpload(_UploadKind kind) {
    _setUpload(kind, const _UploadValue());
  }

  Future<void> _showReviewSheet() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Application under review',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 4,
                  sigmaY: 4,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 13, 26, 34),
                decoration: const BoxDecoration(
                  color: Color(0xFFFBFBFB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _fieldStroke,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 44),
                      Text(
                        'Application under review',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: 0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Your verification details have been submitted successfully. We will review your application shortly.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 42),
                      AppButton(
                        label: 'OKAY',
                        height: 55,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(driverAuthRepositoryProvider).submitKyc(
        frontFile: _licenseFront.file!,
        backFile: _licenseBack.file!,
        profilePhoto: _profilePhoto.file!,
        drivingExperience: _selectedExperience!,
      );

      final refreshedDriver = await ref.read(driverAuthRepositoryProvider).getProfile();
      final updated = refreshedDriver.copyWith(kycStatus: 'pending');
      ref.read(currentDriverProvider.notifier).state = updated;
      await ref.read(driverAuthRepositoryProvider).updateCachedDriver(updated);

      if (!mounted) {
        return;
      }

      await _showReviewSheet();
      if (!mounted) {
        return;
      }
      context.go(AppRoutes.kycPending);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 351),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            context.pop();
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Back',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 82,
                        child: SvgPicture.asset(
                          AppAssets.logoDark,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const Spacer(),
                      const PreDashboardAccountMenu(),
                    ],
                  ),
                  const SizedBox(height: 35),
                  Text(
                    'Driver Verification',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      letterSpacing: 0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Complete your details to continue driving with ETCride.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  if (_rejected) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _rejectionReason != null && _rejectionReason!.isNotEmpty
                                  ? 'Reason: $_rejectionReason'
                                  : 'Your previous submission was rejected. Please upload clearer photos and resubmit.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  _KycSection(
                    title: "Driver's License",
                    helper:
                        'Upload clear photos of the front and back of your valid driver license.',
                    child: Column(
                      children: [
                        _UploadCard(
                          title: 'License Front',
                          value: _licenseFront,
                          onTap: () => _showSourceSheet(_UploadKind.licenseFront),
                          onDelete: () => _deleteUpload(_UploadKind.licenseFront),
                        ),
                        const SizedBox(height: 14),
                        _UploadCard(
                          title: 'License Back',
                          value: _licenseBack,
                          onTap: () => _showSourceSheet(_UploadKind.licenseBack),
                          onDelete: () => _deleteUpload(_UploadKind.licenseBack),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _KycSection(
                    title: 'Profile Photo',
                    helper: _helperFor(_UploadKind.profilePhoto),
                    child: _UploadCard(
                      title: 'Profile Photo',
                      value: _profilePhoto,
                      onTap: () => _showSourceSheet(_UploadKind.profilePhoto),
                      onDelete: () => _deleteUpload(_UploadKind.profilePhoto),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _KycSection(
                    title: 'Driving Experience',
                    helper: 'Select how long you have been driving.',
                    child: _DropdownField(
                      hint: 'Select driving experience',
                      value: _selectedExperience,
                      options: _experienceOptions,
                      onChanged: (value) => setState(() => _selectedExperience = value),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 41),
                  AppButton(
                    label: 'CONTINUE',
                    height: 55,
                    loading: _submitting,
                    enabled: _canSubmit,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KycSection extends StatelessWidget {
  const _KycSection({
    required this.title,
    required this.helper,
    required this.child,
  });

  final String title;
  final String helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.15,
            letterSpacing: 0,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.title,
    required this.value,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final _UploadValue value;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color get _progressColor {
    return switch (value.status) {
      _UploadStatus.error => _uploadError,
      _ => _uploadSuccess,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = value.status == _UploadStatus.error ? 134.0 : 117.0;
    final hasPreview = value.bytes != null &&
        (value.status == _UploadStatus.success || value.status == _UploadStatus.uploading);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: _DashedBorder(
            color: value.status == _UploadStatus.error
                ? _uploadError.withValues(alpha: 0.5)
                : _fieldStroke,
            child: Container(
              height: cardHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0x1AD9D9D9),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPreview)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 100,
                              height: 72,
                              child: Image.memory(
                                value.bytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    value.file?.name ?? 'Uploaded file',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    value.status == _UploadStatus.uploading
                                        ? 'Uploading file...'
                                        : 'Upload complete',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionIcon(
                                  assetPath: AppAssets.editIcon,
                                  onTap: onTap,
                                ),
                                const SizedBox(height: 14),
                                _ActionIcon(
                                  assetPath: AppAssets.deleteIcon,
                                  onTap: onDelete,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _EmptyUploadState(title: title, isError: value.status == _UploadStatus.error),
                  if (value.status != _UploadStatus.empty)
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 0,
                      child: SizedBox(
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            color: _uploadTrack,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: value.status == _UploadStatus.error ? 1 : value.progress.clamp(0, 1),
                                child: Container(color: _progressColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (value.status == _UploadStatus.error && value.error != null) ...[
          const SizedBox(height: 8),
          Text(
            value.error!,
            style: AppTextStyles.bodySmall.copyWith(
              color: _uploadError,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyUploadState extends StatelessWidget {
  const _EmptyUploadState({
    required this.title,
    required this.isError,
  });

  final String title;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? AppColors.error : AppColors.textHint;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: SvgPicture.asset(
              AppAssets.uploadIcon,
              width: 35,
              height: 35,
              colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to upload or take a photo.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.assetPath,
    required this.onTap,
  });

  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SvgPicture.asset(
        assetPath,
        width: 25,
        height: 25,
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x1AD9D9D9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _fieldStroke),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.black),
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.child,
    required this.color,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 10.0;
    const dashWidth = 7.0;
    const dashSpace = 7.0;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
