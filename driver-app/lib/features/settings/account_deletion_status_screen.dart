import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/repositories/account_deletion_repository.dart';
import '../../shared/providers/providers.dart';

class AccountDeletionStatusScreen extends ConsumerStatefulWidget {
  const AccountDeletionStatusScreen({super.key});

  @override
  ConsumerState<AccountDeletionStatusScreen> createState() =>
      _AccountDeletionStatusScreenState();
}

class _AccountDeletionStatusScreenState
    extends ConsumerState<AccountDeletionStatusScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountDeletionRequest?>(
      future:
          ref.read(accountDeletionRepositoryProvider).getRequestStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text('Loading deletion status...',
                        style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.white,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: AppColors.error),
                      const SizedBox(height: 20),
                      Text('Could not load deletion status',
                          style: AppTextStyles.h4,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(
                        'Your account deletion request is being processed. Click "Try Again" to check for updates.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(accountDeletionRepositoryProvider);
                          setState(() {});
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final request = snapshot.data!;
        final status = request.status;

        DateTime? createdAt;
        if (request.createdAt is String) {
          createdAt = DateTime.tryParse(request.createdAt.toString());
        } else if (request.createdAt is DateTime) {
          createdAt = request.createdAt as DateTime;
        }

        DateTime? reviewedAt;
        if (request.reviewedAt is String) {
          reviewedAt = DateTime.tryParse(request.reviewedAt.toString());
        } else if (request.reviewedAt is DateTime) {
          reviewedAt = request.reviewedAt as DateTime;
        }

        // Check if 7 days have passed since approval/creation
        final canRestore = _canRestoreAccount(createdAt ?? reviewedAt);

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStatusColor(status),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 64,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getStatusTitle(status),
                        style: AppTextStyles.h3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getStatusDescription(status),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Timeline
                Text('Timeline', style: AppTextStyles.h4),
                const SizedBox(height: 16),
                _TimelineItem(
                  icon: Icons.check_circle,
                  title: 'Request Submitted',
                  date: createdAt,
                  isCompleted: true,
                ),
                if (status != 'pending')
                  _TimelineItem(
                    icon: status == 'approved'
                        ? Icons.verified
                        : Icons.cancel,
                    title: status == 'approved'
                        ? 'Request Approved'
                        : 'Request Rejected',
                    date: reviewedAt,
                    isCompleted: true,
                  ),
                _TimelineItem(
                  icon: Icons.person_remove,
                  title: 'Account Deletion Complete',
                  date: null,
                  isCompleted: status == 'approved',
                  daysLeft: status == 'approved' && createdAt != null
                      ? _calculateDaysLeft(createdAt!)
                      : null,
                ),

                const SizedBox(height: 32),

                // What happens next
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What Happens Next',
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ..._getNextStepsForStatus(status),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Details
                if (request.reason != null && request.reason!.isNotEmpty) ...[
                  Text('Your Reason', style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(request.reason!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        )),
                  ),
                  const SizedBox(height: 24),
                ],

                if (status == 'pending') ...[
                  ElevatedButton(
                    onPressed: () => _cancelRequest(request.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Restore Account',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can restore your account at any time before admin approval',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (status == 'rejected')
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Back',
                        style: TextStyle(color: Colors.white)),
                  )
                else if (status == 'approved' && !canRestore)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 32, color: AppColors.error),
                        const SizedBox(height: 8),
                        Text(
                          'Account Permanently Deleted',
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your account and personal data have been permanently deleted. This action cannot be undone.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'approved':
        return 'Deletion Approved';
      case 'rejected':
        return 'Deletion Rejected';
      default:
        return 'Pending Review';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'approved':
        return 'Your account will be permanently deleted within 7 days';
      case 'rejected':
        return 'Your deletion request was rejected by admin';
      default:
        return 'Our admin team is reviewing your request\nEstimated time: 24-48 hours';
    }
  }

  int _calculateDaysLeft(DateTime createdAt) {
    final daysElapsed = DateTime.now().difference(createdAt).inDays;
    final daysLeft = 7 - daysElapsed;
    return daysLeft > 0 ? daysLeft : 0;
  }

  bool _canRestoreAccount(DateTime? referenceDate) {
    if (referenceDate == null) return false;
    final daysElapsed = DateTime.now().difference(referenceDate).inDays;
    return daysElapsed < 7;
  }

  List<Widget> _getNextStepsForStatus(String status) {
    switch (status) {
      case 'approved':
        return [
          _Step(
              number: 1,
              title: 'Personal Data Deletion',
              description:
                  'Your name, email, and phone number will be removed'),
          _Step(
              number: 2,
              title: 'Trip History Preserved',
              description:
                  'All your trips and earnings remain in our system for audit'),
          _Step(
              number: 3,
              title: 'Account Fully Deleted',
              description: 'Within 7 days from approval, your account is gone'),
        ];
      case 'rejected':
        return [
          _Step(
              number: 1,
              title: 'Reason for Rejection',
              description: 'Check your email for the reason'),
          _Step(
              number: 2,
              title: 'Resolve Issues',
              description:
                  'Address any pending earnings or active trips mentioned'),
          _Step(
              number: 3,
              title: 'Resubmit Request',
              description: 'You can submit a new deletion request'),
        ];
      default:
        return [
          _Step(
              number: 1,
              title: 'Under Review',
              description:
                  'Our admin team is checking your account status'),
          _Step(
              number: 2,
              title: 'Approval Decision',
              description: 'You will receive an email with the decision'),
          _Step(
              number: 3,
              title: 'Final Deletion',
              description: 'Account deletion within 7 days if approved'),
        ];
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Account'),
        content: const Text(
            'Are you sure you want to restore your account? Your deletion request will be cancelled and you can continue using the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Deleting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(accountDeletionRepositoryProvider).cancelRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account restored! You can now use the app.'),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate back to home instead of just popping
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final DateTime? date;
  final bool isCompleted;
  final int? daysLeft;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.date,
    required this.isCompleted,
    this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isCompleted ? Colors.white : AppColors.textHint,
                    size: 24),
              ),
              if (daysLeft == null && !isCompleted)
                Container(
                  width: 2,
                  height: 40,
                  color: AppColors.divider,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                )
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else if (daysLeft != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    daysLeft! > 0 ? 'In $daysLeft days' : 'Today',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const _Step({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
