import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms.
/// The actual web implementation is conditionally imported via
/// `grafana_webview_web.dart` when `dart.library.html` is available.
class GrafanaIframeView extends StatelessWidget {
  final String url;

  const GrafanaIframeView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
