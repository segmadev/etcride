import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Result returned when the WebView closes.
enum PaymentWebViewResult { completed, cancelled, unknown }

class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.url,
    required this.bookingId,
  });

  final String url;
  final String bookingId;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _hasIntercepted = false;

  // The callback URL the backend redirects to after payment.
  // We intercept any navigation to this path to auto-close the WebView.
  static const _callbackPath = 'payments/callback';

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (req) {
            if (_hasIntercepted) return NavigationDecision.prevent;

            final uri = Uri.tryParse(req.url);
            if (uri != null && req.url.contains(_callbackPath)) {
              _hasIntercepted = true;
              // Small delay so the gateway has time to fire its webhook
              // before our polling picks it up.
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) {
                  final status = uri.queryParameters['status'] ?? '';
                  final result = status == 'successful'
                      ? PaymentWebViewResult.completed
                      : status == 'cancelled'
                          ? PaymentWebViewResult.cancelled
                          : PaymentWebViewResult.unknown;
                  Navigator.of(context).pop(result);
                }
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canGoBack = await _ctrl.canGoBack();
        if (canGoBack) {
          await _ctrl.goBack();
        } else {
          if (context.mounted) Navigator.of(context).pop(PaymentWebViewResult.cancelled);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cancel payment',
            onPressed: () => Navigator.of(context).pop(PaymentWebViewResult.cancelled),
          ),
          title: Text('Secure Payment', style: AppTextStyles.h4),
          centerTitle: true,
          actions: [
            // Refresh button — useful if gateway page fails to load.
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reload',
              onPressed: () => _ctrl.reload(),
            ),
          ],
          bottom: _loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _ctrl),
      ),
    );
  }
}
