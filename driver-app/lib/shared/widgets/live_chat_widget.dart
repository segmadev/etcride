import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/network/api_client.dart';

// Live chat settings provider
final liveChatSettingsProvider = FutureProvider.autoDispose((ref) async {
  try {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/live-chat/settings',
    );
    return response ?? {'live_chat_enabled': false};
  } catch (e) {
    return {'live_chat_enabled': false};
  }
});

class LiveChatWidget extends ConsumerWidget {
  const LiveChatWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(liveChatSettingsProvider);

    return settings.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final isEnabled = data['live_chat_enabled'] as bool? ?? false;
        final widgetId = data['tawk_widget_id'] as String?;

        if (!isEnabled || widgetId == null || widgetId.isEmpty) {
          return const SizedBox.shrink();
        }

        return _TawkChatButton(widgetId: widgetId);
      },
    );
  }
}

// Tawk chat button - opens in a dialog/bottom sheet
class _TawkChatButton extends StatelessWidget {
  final String widgetId;

  const _TawkChatButton({required this.widgetId});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Live Chat Support',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showChatDialog(context),
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00A699), // Tawk primary color
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _showChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _TawkChatDialog(widgetId: widgetId),
    );
  }
}

// Dialog showing Tawk chat
class _TawkChatDialog extends StatefulWidget {
  final String widgetId;

  const _TawkChatDialog({required this.widgetId});

  @override
  State<_TawkChatDialog> createState() => _TawkChatDialogState();
}

class _TawkChatDialogState extends State<_TawkChatDialog> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(
        Uri.parse(_getTawkHtmlPage()),
      );
  }

  String _getTawkHtmlPage() {
    return 'data:text/html;charset=UTF-8,${Uri.encodeComponent('''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: white;
          }
          #container {
            width: 100%;
            height: 100vh;
            overflow: hidden;
          }
        </style>
      </head>
      <body>
        <div id="container"></div>
        <script src="https://embed.tawk.to/${widget.widgetId}/default"></script>
      </body>
      </html>
    ''')}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.height < 600;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 8 : 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          // WebView
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: WebViewWidget(controller: _controller),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Close button
          Positioned(
            top: 8,
            right: 8,
            child: FloatingActionButton.small(
              onPressed: () => Navigator.pop(context),
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.close, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple text button version for menu/sidedrawer
class LiveChatButton extends ConsumerWidget {
  final Color? textColor;
  final TextStyle? style;

  const LiveChatButton({
    super.key,
    this.textColor,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(liveChatSettingsProvider);

    return settings.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final isEnabled = data['live_chat_enabled'] as bool? ?? false;
        final widgetId = data['tawk_widget_id'] as String?;

        if (!isEnabled || widgetId == null || widgetId.isEmpty) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showChat(context, widgetId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Live Chat',
                    style: style,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChat(BuildContext context, String widgetId) {
    showDialog(
      context: context,
      builder: (_) => _TawkChatDialog(widgetId: widgetId),
    );
  }
}
