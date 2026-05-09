import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/providers/providers.dart';

class LegalDocumentsScreen extends ConsumerStatefulWidget {
  const LegalDocumentsScreen({super.key});

  @override
  ConsumerState<LegalDocumentsScreen> createState() =>
      _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends ConsumerState<LegalDocumentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _terms  = '';
  String _policy = '';
  bool _loading  = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final data =
          await ref.read(contentRepositoryProvider).getTcAndPolicy();
      if (mounted) {
        setState(() {
          _terms  = data['terms']?.toString()  ?? '';
          _policy = data['policy']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'Failed to load documents. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(AppStrings.legalDocuments, style: AppTextStyles.h4),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: AppTextStyles.labelMedium,
          tabs: const [
            Tab(text: 'Terms of Use'),
            Tab(text: 'Privacy Policy'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _DocumentView(content: _terms,  emptyHint: 'Terms of Use not available.'),
                    _DocumentView(content: _policy, emptyHint: 'Privacy Policy not available.'),
                  ],
                ),
    );
  }
}

class _DocumentView extends StatelessWidget {
  const _DocumentView({required this.content, required this.emptyHint});
  final String content;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyHint,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        content,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          height: 1.7,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(message,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(
                onPressed: onRetry,
                child: Text('Retry',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      );
}
