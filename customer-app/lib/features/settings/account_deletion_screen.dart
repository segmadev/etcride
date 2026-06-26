import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/config/router.dart';
import '../../data/repositories/account_deletion_repository.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_button.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  late Future<AccountDeletionRequest> _statusFuture;
  final _reasonCtrl = TextEditingController();
  bool _confirmChecked = false;

  @override
  void initState() {
    super.initState();
    _statusFuture =
        ref.read(accountDeletionRepositoryProvider).getRequestStatus();
  }

  Future<void> _requestDeletion() async {
    if (!_confirmChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm that you understand the consequences'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Account Deletion'),
        content: const Text(
          'This action will delete your personal data (name, email, phone) but preserve your transaction history for audit purposes. '
          'Your request will be reviewed by our admin team within 24-48 hours.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Yes, Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    _showLoadingDialog();

    try {
      await ref
          .read(accountDeletionRepositoryProvider)
          .requestDeletion(reason: _reasonCtrl.text);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      _reasonCtrl.clear();

      // Navigate to status screen to show deletion request details
      if (mounted) {
        context.push(AppRoutes.accountDeletionStatus);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Deletion Request'),
        content: const Text(
            'Are you sure you want to cancel your account deletion request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _showLoadingDialog();

    try {
      await ref.read(accountDeletionRepositoryProvider).cancelRequest();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deletion request cancelled.'),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() {
        _statusFuture =
            ref.read(accountDeletionRepositoryProvider).getRequestStatus();
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            const AppBackButton(),
            const SizedBox(height: 20),
            Text('Delete Account', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text(
              'Permanently delete your account. Your transaction history will be preserved.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FutureBuilder<AccountDeletionRequest>(
              future: _statusFuture,
              builder: (context, snapshot) {
                // Error state - no existing request
                if (snapshot.error != null) {
                  return _buildRequestForm();
                }

                // Request exists
                if (snapshot.hasData) {
                  final request = snapshot.data!;
                  if (request.status == 'pending' ||
                      request.status == 'approved') {
                    return _buildRequestStatus(request);
                  }
                  // Rejected - show form again
                  return Column(
                    children: [
                      _buildRejectionNote(request),
                      const SizedBox(height: 24),
                      _buildRequestForm(),
                    ],
                  );
                }

                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionNote(AccountDeletionRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text('Request Rejected', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Admin Reason: ${request.adminNotes ?? 'No reason provided'}',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestStatus(AccountDeletionRequest request) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: request.isApproved
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: request.isApproved
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    request.isApproved
                        ? Icons.check_circle_outline
                        : Icons.hourglass_bottom,
                    color: request.isApproved
                        ? AppColors.success
                        : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    request.isApproved ? 'Approved' : 'Pending Review',
                    style: AppTextStyles.h4.copyWith(
                      color: request.isApproved
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Requested: ${request.createdAt ?? ''}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              if (request.reviewedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Reviewed: ${request.reviewedAt}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
              if (request.adminNotes != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Admin Notes: ${request.adminNotes}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (request.isPending)
          AppButton(
            onPressed: () => _cancelRequest(request.id),
            variant: AppButtonVariant.secondary,
            label: 'Cancel Request',
          ),
        if (request.isApproved)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Your account will be deleted shortly. '
              'You will not be able to use this account after deletion is complete.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Important', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              Text(
                '• Your personal data (name, email, phone) will be permanently deleted\n'
                '• Transaction history will be preserved for audit purposes\n'
                '• Admin review will take 24-48 hours\n'
                '• Ensure you have no pending bookings or unpaid transactions',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _reasonCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Why do you want to delete your account? (optional)',
            hintStyle: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textHint),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.all(12),
          ),
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _confirmChecked,
          onChanged: (v) =>
              setState(() => _confirmChecked = v ?? false),
          title: Text(
            'I understand and agree to delete my account',
            style: AppTextStyles.bodySmall,
          ),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 20),
        AppButton(
          onPressed: _confirmChecked ? _requestDeletion : null,
          variant: AppButtonVariant.primary,
          label: 'Request Account Deletion',
        ),
      ],
    );
  }
}
