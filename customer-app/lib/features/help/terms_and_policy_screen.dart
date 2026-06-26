import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/providers/providers.dart';
import '../../data/repositories/terms_repository.dart';

class TermsAndPolicyScreen extends ConsumerStatefulWidget {
  final String tab; // 'terms' or 'policy'

  const TermsAndPolicyScreen({super.key, this.tab = 'terms'});

  @override
  ConsumerState<TermsAndPolicyScreen> createState() =>
      _TermsAndPolicyScreenState();
}

class _TermsAndPolicyScreenState extends ConsumerState<TermsAndPolicyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.tab == 'policy' ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
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
        title: Text('Terms & Conditions', style: AppTextStyles.h4),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: AppTextStyles.labelMedium,
          tabs: const [
            Tab(text: 'Terms & Conditions'),
            Tab(text: 'Privacy Policy'),
          ],
        ),
      ),
      body: FutureBuilder<TermsAndConditionsData>(
        future: ref.read(termsRepositoryProvider).getTermsAndConditions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load documents', style: AppTextStyles.h4),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          return TabBarView(
            controller: _tabController,
            children: [
              // Terms & Conditions
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Html(
                  data: data.termsAndConditions,
                  style: {
                    '*': Style(
                      color: AppColors.textPrimary,
                      fontSize: FontSize(14),
                      lineHeight: LineHeight.number(1.5),
                    ),
                    'h2': Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.bold,
                      margin: Margins.symmetric(vertical: 12),
                    ),
                    'h3': Style(
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.bold,
                      margin: Margins.symmetric(vertical: 8),
                    ),
                    'p': Style(
                      margin: Margins.symmetric(vertical: 8),
                    ),
                    'li': Style(
                      margin: Margins.symmetric(vertical: 4),
                    ),
                    'a': Style(
                      color: AppColors.primary,
                      textDecoration: TextDecoration.underline,
                    ),
                  },
                ),
              ),
              // Privacy Policy
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Html(
                  data: data.privacyPolicy,
                  style: {
                    '*': Style(
                      color: AppColors.textPrimary,
                      fontSize: FontSize(14),
                      lineHeight: LineHeight.number(1.5),
                    ),
                    'h2': Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.bold,
                      margin: Margins.symmetric(vertical: 12),
                    ),
                    'h3': Style(
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.bold,
                      margin: Margins.symmetric(vertical: 8),
                    ),
                    'p': Style(
                      margin: Margins.symmetric(vertical: 8),
                    ),
                    'li': Style(
                      margin: Margins.symmetric(vertical: 4),
                    ),
                    'a': Style(
                      color: AppColors.primary,
                      textDecoration: TextDecoration.underline,
                    ),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
