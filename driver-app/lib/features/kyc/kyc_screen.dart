import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

const _idTypes = [
  'National ID (NIN)',
  "Driver's Licence",
  'International Passport',
  "Voter's Card",
];

class DriverKycScreen extends ConsumerStatefulWidget {
  const DriverKycScreen({super.key});

  @override
  ConsumerState<DriverKycScreen> createState() => _DriverKycScreenState();
}

class _DriverKycScreenState extends ConsumerState<DriverKycScreen> {
  final _idNumberCtrl = TextEditingController();
  final _picker       = ImagePicker();

  String? _selectedIdType;
  XFile?  _frontImage;
  XFile?  _backImage;
  bool    _uploading = false;
  bool    _rejected  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final driver = ref.read(currentDriverProvider);
    _rejected = driver?.isKycRejected ?? false;
  }

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isFront}) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Upload ${isFront ? 'Front' : 'Back'}',
                style: AppTextStyles.h4),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80);
                if (file != null && mounted) {
                  setState(() => isFront
                      ? _frontImage = file
                      : _backImage = file);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80);
                if (file != null && mounted) {
                  setState(() => isFront
                      ? _frontImage = file
                      : _backImage = file);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final idType   = _selectedIdType;
    final idNumber = _idNumberCtrl.text.trim();

    if (idType == null) {
      setState(() => _error = 'Please select an ID type.');
      return;
    }
    if (idNumber.isEmpty) {
      setState(() => _error = 'Please enter your ID number.');
      return;
    }
    if (_frontImage == null) {
      setState(() => _error = 'Please upload the front of your ID.');
      return;
    }

    setState(() { _uploading = true; _error = null; });
    try {
      await ref.read(driverAuthRepositoryProvider).submitKyc(
        idType:    idType,
        idNumber:  idNumber,
        frontFile: _frontImage!,
        backFile:  _backImage,
      );

      // Update cached driver kyc_status to pending
      final current = ref.read(currentDriverProvider);
      if (current != null) {
        final updated = current.copyWith(kycStatus: 'pending');
        ref.read(currentDriverProvider.notifier).state = updated;
        await ref.read(driverAuthRepositoryProvider).updateCachedDriver(updated);
      }

      if (!mounted) return;
      context.go(AppRoutes.kycPending);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top header
              Row(children: [
                if (Navigator.canPop(context))
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded, size: 24),
                  )
                else
                  const SizedBox(width: 24),
              ]),
              const SizedBox(height: 24),

              // Rejection notice
              if (_rejected)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your previous submission was rejected. Please re-upload clear, valid ID documents.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                'Identity\nVerification',
                style: AppTextStyles.displayLarge.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Upload a valid government-issued ID to verify your identity.',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),

              // ID type dropdown
              _SectionLabel('ID Type'),
              const SizedBox(height: 8),
              _DropdownField(
                hint:     'Select ID type',
                value:    _selectedIdType,
                options:  _idTypes,
                onChanged: (v) => setState(() => _selectedIdType = v),
              ),
              const SizedBox(height: 16),

              // ID number
              _SectionLabel('ID Number'),
              const SizedBox(height: 8),
              AppTextField(
                controller:   _idNumberCtrl,
                hint:     'Enter your ID number',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 24),

              // Upload front
              _SectionLabel('ID Front Photo'),
              const SizedBox(height: 8),
              _ImageUploadBox(
                label:    'Front of ID',
                file:     _frontImage,
                required: true,
                onTap:    () => _pickImage(isFront: true),
              ),
              const SizedBox(height: 14),

              // Upload back
              _SectionLabel('ID Back Photo (optional)'),
              const SizedBox(height: 8),
              _ImageUploadBox(
                label: 'Back of ID',
                file:  _backImage,
                onTap: () => _pickImage(isFront: false),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ],

              const SizedBox(height: 32),

              AppButton(
                label:    'SUBMIT FOR REVIEW',
                loading:  _uploading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );
}

// ── Image upload box ──────────────────────────────────────────────────────────
// Uses Image.memory (XFile.readAsBytes) so it works on all platforms —
// Image.file is web-unsafe (asserts !kIsWeb at runtime).

class _ImageUploadBox extends StatefulWidget {
  const _ImageUploadBox({
    required this.label,
    required this.onTap,
    this.file,
    this.required = false,
  });
  final String     label;
  final XFile?     file;
  final bool       required;
  final VoidCallback onTap;

  @override
  State<_ImageUploadBox> createState() => _ImageUploadBoxState();
}

class _ImageUploadBoxState extends State<_ImageUploadBox> {
  Future<Uint8List>? _bytesFuture;
  XFile? _cachedFile;

  /// Only re-read bytes when the XFile actually changes.
  Future<Uint8List>? _futureFor(XFile? file) {
    if (file == null) return null;
    if (file.path != _cachedFile?.path) {
      _cachedFile   = file;
      _bytesFuture  = file.readAsBytes();
    }
    return _bytesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final file     = widget.file;
    final hasImage = file != null;
    final future   = _futureFor(file);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasImage ? Colors.transparent : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.divider,
            width: hasImage ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? FutureBuilder<Uint8List>(
                future: future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(snap.data!, fit: BoxFit.cover),
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit, size: 16,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    style: AppTextStyles.labelSmall
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.required
                        ? 'Required — tap to upload'
                        : 'Optional — tap to upload',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Dropdown ──────────────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String       hint;
  final String?      value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:       value,
            hint:        Text(hint,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            isExpanded:  true,
            icon:        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged:   onChanged,
            style:       AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
      );
}
